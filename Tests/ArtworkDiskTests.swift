import Foundation
import Testing
import UIKit

@testable import MediaBridge

/// MediaPlayer is replaced by a closure that keeps 1.5 MB of headroom per distinct album, as
/// measured on a device (#80), and the disk by a dictionary.
@Suite("Artwork on disk")
struct ArtworkDiskTests {
    final class Library: @unchecked Sendable {
        private let lock = NSLock()
        private var rendered: Set<UInt64> = []
        private var renderCalls = 0
        private var stored: [ArtworkRequest: UIImage] = [:]
        private var saves = 0
        let startingHeadroom: Int
        let perAlbum = 1_500_000

        init(startingHeadroom: Int = 1_100_000_000) { self.startingHeadroom = startingHeadroom }

        var renders: Int { lock.withLock { renderCalls } }
        var distinctRendered: Set<UInt64> { lock.withLock { rendered } }
        var saveCount: Int { lock.withLock { saves } }
        var storedCount: Int { lock.withLock { stored.count } }
        var headroom: Int { lock.withLock { startingHeadroom - rendered.count * perAlbum } }

        /// A render of `id`, as MediaPlayer would keep it.
        func render(_ id: UInt64) -> UIImage {
            lock.withLock {
                renderCalls += 1
                rendered.insert(id)
            }
            return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        }

        var disk: ArtworkDisk {
            ArtworkDisk(
                load: { [self] request in lock.withLock { stored[request] } },
                save: { [self] image, request in
                    lock.withLock {
                        stored[request] = image
                        saves += 1
                    }
                })
        }

        /// A cache as a fresh launch has it: nothing in memory, the same disk.
        func launch(minimumHeadroom: Int = 512_000_000) -> ArtworkCache {
            ArtworkCache(minimumHeadroom: minimumHeadroom, headroom: { [self] in headroom }, disk: disk)
        }
    }

    static func request(_ id: UInt64) -> ArtworkRequest {
        ArtworkRequest(id: ArtworkKey(kind: .album, id: id), side: 128)
    }

    static func show(_ id: UInt64, in cache: ArtworkCache, of library: Library) async -> UIImage? {
        await cache.render(request(id)) { _ in library.render(id) }
    }

    @Test("Given an empty disk, when an album renders, then it is saved")
    func savesAfterRender() async {
        let library = Library()
        let cache = library.launch()

        let image = await Self.show(1, in: cache, of: library)

        #expect(image != nil)
        #expect(library.renders == 1)
        #expect(library.saveCount == 1)
    }

    @Test("Given an album on disk, when it is shown after a relaunch, then MediaPlayer isn't asked and nothing is saved again")
    func readsFromDisk() async {
        let library = Library()
        _ = await Self.show(1, in: library.launch(), of: library)

        let image = await Self.show(1, in: library.launch(), of: library)

        #expect(image != nil)
        #expect(library.renders == 1)
        #expect(library.saveCount == 1)
    }

    @Test("Given an album on disk and no headroom left, when it is shown, then it still has artwork")
    func diskNeedsNoHeadroom() async {
        let library = Library()
        _ = await Self.show(1, in: library.launch(), of: library)
        let exhausted = ArtworkCache(minimumHeadroom: 512_000_000, headroom: { 0 }, disk: library.disk)

        let image = await Self.show(1, in: exhausted, of: library)

        #expect(image != nil)
        #expect(library.renders == 1)
    }

    @Test("Given an album only on disk at another size, when it is shown, then it renders at the new size")
    func sizeIsPartOfTheKey() async {
        let library = Library()
        let cache = library.launch()
        _ = await cache.render(Self.request(1)) { _ in library.render(1) }

        let other = ArtworkRequest(id: ArtworkKey(kind: .album, id: 1), side: 256)
        _ = await library.launch().render(other) { _ in library.render(1) }

        #expect(library.renders == 2)
    }

    @Test("Given a library with no disk store, when albums render, then nothing is saved")
    func noDisk() async {
        let library = Library()
        let cache = ArtworkCache(minimumHeadroom: 512_000_000, headroom: { library.headroom })

        _ = await Self.show(1, in: cache, of: library)

        #expect(library.saveCount == 0)
    }

    @Test("Given 750 albums and a 512 MB floor, when launches repeat, then each launch covers new albums until all have artwork")
    func relaunchesFillTheLibrary() async {
        let albums = (1...750).map(UInt64.init)
        var covered: Set<UInt64> = []
        var coverage: [Int] = []

        for _ in 0..<3 {
            // Each launch is a new process: MediaPlayer's memory starts over, the disk stays.
            let launch = Library(startingHeadroom: 1_100_000_000)
            let cache = ArtworkCache(minimumHeadroom: 512_000_000, headroom: { launch.headroom }, disk: shared.disk)
            for id in albums {
                if await Self.show(id, in: cache, of: launch) != nil { covered.insert(id) }
            }
            // MediaPlayer stayed inside the floor in this launch.
            #expect(launch.headroom >= 512_000_000 - launch.perAlbum)
            coverage.append(covered.count)
        }

        #expect(coverage[0] < 750)
        #expect(coverage[1] > coverage[0])
        #expect(coverage[2] == 750)
    }

    @Suite("Given the file store")
    struct Files {
        static func temporaryDirectory() -> URL {
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        }

        /// Returns once every write queued so far has finished.
        static func drain(_ writes: DispatchQueue) async {
            await withCheckedContinuation { finished in writes.async { finished.resume() } }
        }

        static func image(side: CGFloat) -> UIImage {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            }
        }

        @Test("When an image is saved, then a later load from a new store returns it")
        func roundTrip() async throws {
            let directory = Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let writes = DispatchQueue(label: "roundTrip.writes")
            ArtworkDisk.live(directory: directory, writeQueue: writes).save(Self.image(side: 64), ArtworkDiskTests.request(7))
            await Self.drain(writes)
            let reopened = ArtworkDisk.live(directory: directory)

            #expect(reopened.load(ArtworkDiskTests.request(7)) != nil)
        }

        @Test("When an image is larger than the view needs, then it is stored at 3x the requested side")
        func scalesDown() async throws {
            let directory = Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let writes = DispatchQueue(label: "scalesDown.writes")
            let disk = ArtworkDisk.live(directory: directory, writeQueue: writes)

            disk.save(Self.image(side: 1_170), ArtworkDiskTests.request(7))
            await Self.drain(writes)
            let stored = try #require(disk.load(ArtworkDiskTests.request(7)))

            #expect(stored.size.width * stored.scale == 384)
        }

        @Test("When nothing was saved or the item has no persistent ID, then load returns nothing")
        func misses() {
            let disk = ArtworkDisk.live(directory: Self.temporaryDirectory())
            let unidentified = ArtworkRequest(id: ArtworkKey(kind: .album, id: 0), side: 128)

            disk.save(Self.image(side: 64), unidentified)

            #expect(disk.load(ArtworkDiskTests.request(7)) == nil)
            #expect(disk.load(unidentified) == nil)
        }

        @Test("When more images are waiting to be written than the pending limit allows, then the extra ones are dropped")
        func dropsOverThePendingLimit() async throws {
            let directory = Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            // One 64 px image is 16 KB decoded: room for exactly one waiting at a time.
            let writes = DispatchQueue(label: "dropsOverThePendingLimit.writes")
            let disk = ArtworkDisk.live(directory: directory, pendingByteLimit: 20_000, writeQueue: writes)
            let image = Self.image(side: 64)

            writes.suspend()
            for id in 1...20 { disk.save(image, ArtworkDiskTests.request(UInt64(id))) }
            writes.resume()
            await Self.drain(writes)

            let saved = (1...20).filter { disk.load(ArtworkDiskTests.request(UInt64($0))) != nil }
            #expect(saved == [1])
        }

        @Test("When a stored image is older than the maximum age, then it is removed and load returns nothing")
        func expires() async throws {
            let directory = Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let day: TimeInterval = 24 * 60 * 60
            let written = Date()
            let request = ArtworkDiskTests.request(7)
            let writes = DispatchQueue(label: "expires.writes")
            ArtworkDisk.live(directory: directory, writeQueue: writes).save(Self.image(side: 64), request)
            await Self.drain(writes)

            let young = ArtworkDisk.live(directory: directory, maxAge: 30 * day, now: { written.addingTimeInterval(29 * day) })
            #expect(young.load(request) != nil)

            let old = ArtworkDisk.live(directory: directory, maxAge: 30 * day, now: { written.addingTimeInterval(31 * day) })
            #expect(old.load(request) == nil)
            #expect(ArtworkDisk.live(directory: directory).load(request) == nil)
        }

        @Test("When the folder passes its byte limit, then the oldest file goes first")
        func trims() async throws {
            let directory = Self.temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            // Probe the size of one file, then allow exactly that much.
            let writes = DispatchQueue(label: "trims.writes")
            let probe = ArtworkDisk.live(directory: directory, writeQueue: writes)
            probe.save(Self.image(side: 64), ArtworkDiskTests.request(1))
            await Self.drain(writes)
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            let first = try #require(files.first)
            let oneFile = try #require(try first.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: first.path)
            let disk = ArtworkDisk.live(directory: directory, byteLimit: oneFile, writeQueue: writes)

            disk.save(Self.image(side: 64), ArtworkDiskTests.request(2))
            await Self.drain(writes)

            #expect(disk.load(ArtworkDiskTests.request(1)) == nil)
            #expect(disk.load(ArtworkDiskTests.request(2)) != nil)
        }
    }

    /// One disk shared by every launch of the simulation above.
    let shared = Library()
}
