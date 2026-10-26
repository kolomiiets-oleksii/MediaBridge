import Foundation
import MediaPlayer
import Testing
import UIKit

@testable import MediaBridge

/// A fake music library that lives on disk, so a test loads it the way an app loads the real one.
///
/// `library.json` holds the songs (Codable records). `artwork/<albumID>.png` holds one random
/// picture per album. Items read their metadata from the decoded records and render artwork by
/// reading and drawing the PNG at the requested size, so a first load costs real disk and decode
/// work, not a closure that returns a flat color.
///
/// Generation is deterministic for a seed. A directory is built once per process and size.

struct FakeSongRecord: Codable, Sendable {
    let id: UInt64
    let title: String
    let artist: String
    let album: String
    let albumID: UInt64
    let genre: String
    let playCount: Int
    let skipCount: Int
    let duration: Double
    let hasArtwork: Bool
}

struct FakeManifest: Codable, Sendable {
    let seed: UInt64
    let songs: [FakeSongRecord]
}

/// SplitMix64: small, fast, same sequence everywhere.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum FakeLibraryGenerator {
    static let genres = ["Rock", "Pop", "Jazz", "Blues", "Classical", "Hip-Hop", "Electronic", "Folk", "Metal", "Soul"]

    /// `songsPerAlbum` songs share an album and its artwork; `albumsPerArtist` albums share an artist.
    /// `artworkFraction` of the albums have artwork, as in a real library with some untagged files.
    static func manifest(
        songs count: Int, seed: UInt64 = 1, songsPerAlbum: Int = 10, albumsPerArtist: Int = 5, artworkFraction: Double = 0.9
    ) -> FakeManifest {
        var rng = SeededGenerator(seed: seed)
        var records: [FakeSongRecord] = []
        records.reserveCapacity(count)
        var albumHasArtwork: [Int: Bool] = [:]
        for index in 0..<count {
            let album = index / songsPerAlbum
            let artist = album / albumsPerArtist
            let hasArt = albumHasArtwork[album] ?? (Double.random(in: 0..<1, using: &rng) < artworkFraction)
            albumHasArtwork[album] = hasArt
            records.append(
                FakeSongRecord(
                    id: UInt64(index + 1),
                    title: "Song \(index) \(String(UInt32.random(in: 0..<1_000_000, using: &rng), radix: 36))",
                    artist: "Artist \(artist)",
                    album: "Album \(album)",
                    albumID: UInt64(album + 1),
                    genre: genres[Int.random(in: 0..<genres.count, using: &rng)],
                    playCount: Int.random(in: 0...200, using: &rng),
                    skipCount: Int.random(in: 0...20, using: &rng),
                    duration: Double.random(in: 60...420, using: &rng),
                    hasArtwork: hasArt))
        }
        return FakeManifest(seed: seed, songs: records)
    }

    /// A random picture: a two-color gradient with a few shapes, 600 x 600 px.
    static func artwork(seed: UInt64) -> UIImage {
        var rng = SeededGenerator(seed: seed)
        func color() -> UIColor {
            UIColor(
                hue: .random(in: 0..<1, using: &rng), saturation: .random(in: 0.4...0.9, using: &rng),
                brightness: .random(in: 0.5...1, using: &rng), alpha: 1)
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let side: CGFloat = 600
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let cg = context.cgContext
            let colors = [color().cgColor, color().cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side, y: side), options: [])
            }
            for _ in 0..<12 {
                color().withAlphaComponent(.random(in: 0.3...0.8, using: &rng)).setFill()
                let rect = CGRect(
                    x: .random(in: 0..<side, using: &rng), y: .random(in: 0..<side, using: &rng),
                    width: .random(in: 40...300, using: &rng), height: .random(in: 40...300, using: &rng))
                cg.fillEllipse(in: rect)
            }
        }
    }
}

/// Counts what artwork rendering costs: how many renders, which albums, how many at once.
final class RenderMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var total = 0
    private var perAlbum: [UInt64: Int] = [:]
    private var running = 0
    private var peak = 0
    private var property = 0

    var renders: Int { lock.withLock { total } }
    var peakConcurrent: Int { lock.withLock { peak } }
    var propertyReads: Int { lock.withLock { property } }
    func renders(ofAlbum id: UInt64) -> Int { lock.withLock { perAlbum[id] ?? 0 } }
    var distinctAlbumsRendered: Int { lock.withLock { perAlbum.count } }

    func begin(album: UInt64) {
        lock.withLock {
            total += 1
            perAlbum[album, default: 0] += 1
            running += 1
            peak = max(peak, running)
        }
    }

    func end() { lock.withLock { running -= 1 } }
    func countRead() { lock.withLock { property += 1 } }
}

/// An `MPMediaItem` backed by a record, with artwork read from the fake library's PNG files.
final class FakeMediaItem: MPMediaItem, @unchecked Sendable {
    let record: FakeSongRecord
    private let art: MPMediaItemArtwork?
    private let meter: RenderMeter?
    private let countsReads: Bool

    init(_ record: FakeSongRecord, artworkURL: URL?, meter: RenderMeter?, countsReads: Bool) {
        self.record = record
        self.meter = meter
        self.countsReads = countsReads
        if record.hasArtwork, let artworkURL {
            let albumID = record.albumID
            art = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { size in
                meter?.begin(album: albumID)
                defer { meter?.end() }
                guard let source = UIImage(contentsOfFile: artworkURL.path) else { return UIImage() }
                // Default format: device scale, as MediaPlayer renders (3x on an iPhone).
                return UIGraphicsImageRenderer(size: size).image { _ in
                    source.draw(in: CGRect(origin: .zero, size: size))
                }
            }
        } else {
            art = nil
        }
        super.init()
    }

    required init?(coder: NSCoder) { nil }

    override func value(forProperty property: String) -> Any? {
        if countsReads { meter?.countRead() }
        switch property {
        case MPMediaItemPropertyPersistentID: return NSNumber(value: record.id)
        case MPMediaItemPropertyTitle: return record.title
        case MPMediaItemPropertyArtist: return record.artist
        case MPMediaItemPropertyAlbumTitle: return record.album
        case MPMediaItemPropertyAlbumPersistentID: return NSNumber(value: record.albumID)
        case MPMediaItemPropertyGenre: return record.genre
        case MPMediaItemPropertyPlayCount: return NSNumber(value: record.playCount)
        case MPMediaItemPropertySkipCount: return NSNumber(value: record.skipCount)
        case MPMediaItemPropertyPlaybackDuration: return NSNumber(value: record.duration)
        case MPMediaItemPropertyMediaType: return NSNumber(value: MPMediaType.music.rawValue)
        case MPMediaItemPropertyArtwork: return art
        default: return nil
        }
    }
}

/// The on-disk fake library. `load()` decodes `library.json` and builds items, as an app would
/// on first launch; call it again for a refetch that returns new `MPMediaItem` instances.
final class FakeLibrary: @unchecked Sendable {
    let directory: URL
    let songCount: Int
    let meter = RenderMeter()

    var manifestURL: URL { directory.appendingPathComponent("library.json") }
    func artworkURL(album: UInt64) -> URL { directory.appendingPathComponent("artwork/\(album).png") }

    private init(directory: URL, songCount: Int) {
        self.directory = directory
        self.songCount = songCount
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var built: [Int: FakeLibrary] = [:]

    /// Builds the library once per process for this size; later calls reuse the files.
    /// Each call gets its own `RenderMeter`.
    static func make(songs count: Int) throws -> FakeLibrary {
        let directory: URL = try lock.withLock {
            if let existing = built[count] { return existing.directory }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FakeLibrary-\(count)-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory.appendingPathComponent("artwork"), withIntermediateDirectories: true)
            let manifest = FakeLibraryGenerator.manifest(songs: count)
            try JSONEncoder().encode(manifest).write(to: directory.appendingPathComponent("library.json"))
            for album in Set(manifest.songs.filter(\.hasArtwork).map(\.albumID)) {
                let png = FakeLibraryGenerator.artwork(seed: album).pngData()
                try png?.write(to: directory.appendingPathComponent("artwork/\(album).png"))
            }
            built[count] = FakeLibrary(directory: directory, songCount: count)
            return directory
        }
        return FakeLibrary(directory: directory, songCount: count)
    }

    func records() throws -> [FakeSongRecord] {
        try JSONDecoder().decode(FakeManifest.self, from: Data(contentsOf: manifestURL)).songs
    }

    /// Decodes the JSON and builds fresh items.
    func load(countingReads: Bool = false) throws -> [MPMediaItem] {
        try records().map {
            FakeMediaItem($0, artworkURL: artworkURL(album: $0.albumID), meter: meter, countsReads: countingReads)
        }
    }
}

/// A service that serves the fake library, can be slow, and counts requests and overlap.
final class FakeLibraryService: MusicLibraryServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let library: FakeLibrary
    private let latency: TimeInterval
    private let reloadsOnEachFetch: Bool
    private var requests = 0
    private var running = 0
    private var peak = 0

    init(_ library: FakeLibrary, latency: TimeInterval = 0, reloadsOnEachFetch: Bool = false) {
        self.library = library
        self.latency = latency
        self.reloadsOnEachFetch = reloadsOnEachFetch
    }

    var requestCount: Int { lock.withLock { requests } }
    var peakConcurrentFetches: Int { lock.withLock { peak } }

    private var cached: [MPMediaItem]?

    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] {
        lock.withLock {
            requests += 1
            running += 1
            peak = max(peak, running)
        }
        defer { lock.withLock { running -= 1 } }
        if latency > 0 { try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000)) }
        if reloadsOnEachFetch { return try library.load() }
        return try lock.withLock {
            if let cached { return cached }
            let loaded = try library.load()
            cached = loaded
            return loaded
        }
    }

    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] { [] }
}

extension Tag {
    @Tag static var stress: Self
}

/// How many songs the stress suite builds. `STRESS_SONGS=20000` for a local, heavier run.
enum StressScale {
    static var songs: Int {
        ProcessInfo.processInfo.environment["STRESS_SONGS"].flatMap(Int.init) ?? 2_000
    }
}
