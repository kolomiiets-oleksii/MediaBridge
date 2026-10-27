import Foundation
import MediaPlayer
import Testing
import UIKit

@testable import MediaBridge

/// Stress tests on a fake library that lives on disk (see `FakeLibrary`).
///
/// They look for weak places, not budgets: wall-clock limits would flake across the CI matrix,
/// so assertions are counts and ratios (property reads, fetches, renders). Timings are printed as
/// `STRESS|label|ms` for the findings table. `STRESS_SONGS=20000` runs it bigger.
/// Where the SDK falls short of what a caller would expect, the test says so with `withKnownIssue`.
@Suite("Stress", .tags(.stress), .serialized)
struct StressTests {
    static let songs = StressScale.songs

    /// Runs `body`, prints how long it took, and returns its value.
    @discardableResult
    static func measure<T: Sendable>(_ label: String, _ body: () async throws -> T) async rethrows -> T {
        let start = DispatchTime.now().uptimeNanoseconds
        let value = try await body()
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
        print("STRESS|\(label)|n=\(songs)|\(String(format: "%.1f", ms)) ms")
        return value
    }

    /// True if `body` finishes within `seconds`. A body that never returns is abandoned, not awaited.
    static func finishes(within seconds: Double, _ body: @escaping @MainActor @Sendable () async -> Void) async -> Bool {
        final class Once: @unchecked Sendable {
            let lock = NSLock()
            var done = false
            func claim() -> Bool { lock.withLock { defer { done = true }; return !done } }
        }
        let once = Once()
        return await withCheckedContinuation { continuation in
            Task {
                await body()
                if once.claim() { continuation.resume(returning: true) }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1e9))
                if once.claim() { continuation.resume(returning: false) }
            }
        }
    }

    static func library(
        _ fake: FakeLibrary, latency: TimeInterval = 0, reloading: Bool = false, changes: any LibraryChangesProtocol = CountingChanges()
    ) -> (MusicLibrary, FakeLibraryService) {
        let service = FakeLibraryService(fake, latency: latency, reloadsOnEachFetch: reloading)
        return (MusicLibrary(auth: .mock, service: service, changes: changes), service)
    }

    // MARK: Loading

    @Suite("Given a library on disk")
    struct Loading {
        @Test("When the JSON is loaded, then every song becomes an item")
        func jsonLoad() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let items = try await StressTests.measure("json decode + build items") { try fake.load() }
            #expect(items.count == StressTests.songs)
        }

        @Test("When the first fetch runs, then every song comes back")
        func firstFetch() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let (library, _) = StressTests.library(fake)
            let songs = try await StressTests.measure("first fetch(.songs)") { try await library.fetch(.songs) }
            #expect(songs.count == StressTests.songs)
        }
    }

    // MARK: Filter and sort

    @Suite("Given a long list that is filtered and sorted")
    struct FilterAndSort {
        @Test("When sorting by title, then each song's title is read about once, at any size")
        func sortReadsAreLinear() throws {
            var perElement: [Double] = []
            for n in [StressTests.songs / 2, StressTests.songs] {
                let fake = try FakeLibrary.make(songs: n)
                let songs = try fake.load(countingReads: true).map(Song.init)
                let sorted = LibraryQuery<Song>().sorted(by: \.title).refine(songs)
                let reads = Double(fake.meter.propertyReads)
                perElement.append(reads / Double(n))
                print("STRESS|sort(title) property reads per song|n=\(n)|\(String(format: "%.2f", reads / Double(n)))")
                #expect(sorted.count == n)
                #expect(sorted.map(\.title).isAlphabetical)
            }
            #expect(perElement.allSatisfy { $0 <= 2 }, "reads per song \(perElement): sorting re-reads properties per comparison")
            #expect(perElement[1] <= perElement[0] * 1.2, "reads per song grow with n: \(perElement)")
        }

        @Test("When filtering in memory then sorting by two keys, then property reads stay a small multiple of n")
        func filterSortReads() throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let songs = try fake.load(countingReads: true).map(Song.init)
            let query = LibraryQuery<Song>().filter(\.playCount >= 100).sorted(by: \.artist).then(by: \.title)
            let refined = query.refine(songs)
            let perSong = Double(fake.meter.propertyReads) / Double(songs.count)
            print("STRESS|filter+sort(2 keys) property reads per song|n=\(songs.count)|\(String(format: "%.2f", perSong))")
            #expect(perSong <= 3)
            #expect(refined.allSatisfy { $0.playCount >= 100 })
        }

        @Test("When one sorted query runs ten times, then a repeat costs about what the first did")
        func repeatedQuery() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let (library, service) = StressTests.library(fake)
            let query = LibraryQuery<Song>().filter(\.skipCount > 5).sorted(by: \.playCount, .reverse).then(by: \.title)
            var counts: [Int] = []
            for run in 0..<10 {
                let songs = try await StressTests.measure("sorted+filtered query, run \(run)") { try await library.fetch(query) }
                counts.append(songs.count)
            }
            #expect(Set(counts).count == 1)
            // Every fetch asks the service again: the SDK keeps no result of its own to reuse.
            print("STRESS|service requests for 10 identical fetches|n=\(StressTests.songs)|\(service.requestCount)")
        }

        @Test("When grouping by artist and sectioning by genre, then nothing is lost")
        func groupAndSection() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let (library, _) = StressTests.library(fake)
            let groups = try await StressTests.measure("grouped(by: artist)") { try await library.grouped(.songs, by: \.artist) }
            #expect(groups.reduce(0) { $0 + $1.count } == StressTests.songs)
            let sections = try await StressTests.measure("sections(by: genre)") {
                try await library.sections(.songs.sorted(by: \.title), by: \.genre) { $0 }
            }
            #expect(sections.reduce(0) { $0 + $1.elements.count } == StressTests.songs)
        }
    }

    // MARK: Reload

    @Suite("Given a list that reloads")
    @MainActor
    struct Reload {
        @Test("When the same query is set a hundred times, then the library is asked once")
        func equalQueryIsFree() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let (library, service) = StressTests.library(fake)
            let loader = MediaQueryLoader<Song>()
            for _ in 0..<100 {
                // A fresh Set each time, as a view body would build it.
                loader.update(query: .songs.filter(\.genre, .isIn(Set(["Jazz", "Blues"]))), library: library)
            }
            await loader.settle()
            #expect(service.requestCount == 1)
            #expect(!loader.elements.isEmpty)
        }

        @Test("When reload is called fifty times at once on a slow library, then every call returns")
        func reloadStorm() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let (library, service) = StressTests.library(fake, latency: 0.03)
            let loader = MediaQueryLoader<Song>()
            loader.update(query: .songs.sorted(by: \.title), library: library)

            let finished = await StressTests.finishes(within: 20) { @MainActor in
                let tasks = (0..<50).map { _ in Task { @MainActor in await loader.reload() } }
                for task in tasks { await task.value }
            }
            #expect(finished, "a reload never returned: its waiter was lost")
            print("STRESS|fetches started for 50 concurrent reload()|n=\(StressTests.songs)|\(service.requestCount)")
            print("STRESS|peak overlapping fetches|n=\(StressTests.songs)|\(service.peakConcurrentFetches)")
            #expect(loader.elements.count == StressTests.songs)
        }

        @Test("When the query changes two hundred times in a row, then the list ends on the last one")
        func queryChurn() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let (library, service) = StressTests.library(fake, latency: 0.005)
            let loader = MediaQueryLoader<Song>()
            for limit in 1...200 { loader.update(query: .songs.limit(limit), library: library) }
            let finished = await StressTests.finishes(within: 20) { @MainActor in await loader.settle() }
            #expect(finished)
            try await Task.sleep(nanoseconds: 200 * 1_000_000)
            #expect(loader.elements.count == 200, "list shows a stale query's result: \(loader.elements.count)")
            print("STRESS|fetches started for 200 query changes|n=\(StressTests.songs)|\(service.requestCount)")
        }

        @Test("When the library reports a burst of two hundred changes fired at once, then it refetches only a few times")
        func changeStorm() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let changes = CountingChanges()
            let (library, service) = StressTests.library(fake, changes: changes)
            let collector = Task { () -> Int in
                var published = 0
                for await _ in library.results(.songs.sorted(by: \.title), coalescing: 0.05) {
                    published += 1
                    if published >= 50 { break }
                }
                return published
            }
            try await Task.sleep(nanoseconds: 300 * 1_000_000)
            for _ in 0..<200 { changes.fire() }
            try await Task.sleep(nanoseconds: 600 * 1_000_000)
            collector.cancel()
            print("STRESS|refetches for 200 changes fired at once|n=\(StressTests.songs)|\(service.requestCount - 1)")
            #expect(service.requestCount - 1 <= 10)
        }

        @Test("When every refetch returns new item instances, then the list still ends consistent")
        func newInstancesEachRefetch() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let (library, _) = StressTests.library(fake, reloading: true)
            let loader = MediaQueryLoader<Song>()
            loader.update(query: .songs.sorted(by: \.title), library: library)
            await loader.settle()
            let firstIDs = Set(loader.elements.map(\.id))
            let start = DispatchTime.now().uptimeNanoseconds
            await loader.reload()
            print("STRESS|reload() with fresh JSON load|n=\(StressTests.songs)|\(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6) ms")
            #expect(Set(loader.elements.map(\.id)) == firstIDs)
        }
    }

    // MARK: Artwork

    @Suite("Given songs with random artwork shown for the first time")
    struct Artwork {
        static func request(_ record: FakeSongRecord, side: Double = 64) -> ArtworkRequest {
            ArtworkRequest(id: ArtworkKey(kind: .song, id: record.id), side: side)
        }

        /// What `ArtworkImage` does for one row: use the cache, else render through it.
        static func show(_ item: FakeMediaItem, in cache: ArtworkCache, side: Double = 64) async -> UIImage? {
            if let cached = cache.image(for: request(item.record, side: side)) { return cached }
            return await cache.render(request(item.record, side: side)) { size in Song(item).artwork(size: size) }
        }

        @Test("When a fast scroll shows every row at once, then the renders, overlap and time are measured")
        func coldFlood() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let items = try fake.load().compactMap { $0 as? FakeMediaItem }
            let withArt = items.filter(\.record.hasArtwork)
            let cache = ArtworkCache()

            let shown = await StressTests.measure("first artwork load, all rows at once") {
                await withTaskGroup(of: Bool.self) { group in
                    for item in withArt { group.addTask { await Artwork.show(item, in: cache) != nil } }
                    return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
                }
            }
            #expect(shown == withArt.count)
            let albums = fake.meter.distinctAlbumsRendered
            print("STRESS|renders / unique albums (first load)|n=\(StressTests.songs)|\(fake.meter.renders) / \(albums)")
            print("STRESS|peak concurrent renders|n=\(StressTests.songs)|\(fake.meter.peakConcurrent)")
            #expect(fake.meter.renders >= withArt.count, "fewer renders than rows means the cache dropped a request")
        }

        @Test("When the same album's songs are shown, then the picture is rendered once per song")
        func sameAlbumRepeats() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let items = try fake.load().compactMap { $0 as? FakeMediaItem }
            let album = try #require(items.first { $0.record.hasArtwork }?.record.albumID)
            let songsOfAlbum = items.filter { $0.record.albumID == album }
            let cache = ArtworkCache()
            for item in songsOfAlbum { _ = await Artwork.show(item, in: cache) }
            print("STRESS|renders for \(songsOfAlbum.count) songs of one album|n=\(StressTests.songs)|\(fake.meter.renders(ofAlbum: album))")
            // The cache keys on the song, so a list of a whole album renders its one picture N times.
            withKnownIssue("artwork cache is keyed per song, not per album", isIntermittent: true) {
                #expect(fake.meter.renders(ofAlbum: album) == 1)
            }
        }

        @Test("When fifty rows ask for the same artwork at once, then it renders once")
        func sameKeyConcurrent() async throws {
            let fake = try FakeLibrary.make(songs: 100)
            let item = try #require(try fake.load().compactMap { $0 as? FakeMediaItem }.first { $0.record.hasArtwork })
            let cache = ArtworkCache()
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<50 { group.addTask { _ = await Artwork.show(item, in: cache) } }
            }
            print("STRESS|renders for 50 simultaneous requests of one key|n=100|\(fake.meter.renders)")
            #expect(fake.meter.renders == 1, "simultaneous requests for one key each rendered")
        }

        @Test("When the list is reloaded with new item instances, then cached artwork is reused")
        func reloadKeepsCache() async throws {
            let fake = try FakeLibrary.make(songs: 500)
            let cache = ArtworkCache()
            let first = try fake.load().compactMap { $0 as? FakeMediaItem }.filter(\.record.hasArtwork).prefix(100)
            for item in first { _ = await Artwork.show(item, in: cache) }
            let rendered = fake.meter.renders

            let again = try fake.load().compactMap { $0 as? FakeMediaItem }.filter(\.record.hasArtwork).prefix(100)
            for item in again { _ = await Artwork.show(item, in: cache) }
            #expect(fake.meter.renders == rendered, "a reload rendered \(fake.meter.renders - rendered) pictures again")
        }

        @Test("When a long list is scrolled to the end and back, then the cache hit rate is measured")
        func scrollBack() async throws {
            let fake = try FakeLibrary.make(songs: StressTests.songs)
            let items = try fake.load().compactMap { $0 as? FakeMediaItem }.filter(\.record.hasArtwork)
            let cache = ArtworkCache()
            for item in items { _ = await Artwork.show(item, in: cache) }
            let hits = items.filter { cache.image(for: Artwork.request($0.record)) != nil }.count
            print("STRESS|cache hits when scrolling back over \(items.count) rows|n=\(StressTests.songs)|\(hits)")
            #expect(hits > 0)
        }
    }
}

extension Array where Element: Comparable {
    var isSorted: Bool { zip(self, dropFirst()).allSatisfy { $0 <= $1 } }
}

extension Array where Element == String? {
    var isAlphabetical: Bool {
        zip(self, dropFirst()).allSatisfy { ($0 ?? "").localizedStandardCompare($1 ?? "") != .orderedDescending }
    }
}
