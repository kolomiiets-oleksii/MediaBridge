import Combine
import MediaBridge
import MediaPlayer
import SwiftUI

/// Phase 0 measurements for the 1.4 plan. Launch the Example with `-benchmark` on a real device with
/// a large library; the simulator's library is empty and tells you nothing.
///
/// Each section answers one question, so a change is kept or dropped on a number:
/// - How slow are in-memory filters and sorts next to a pushed-down one?
/// - Would reading properties in one batch (`enumerateValues`) beat one call per property?
/// - What does artwork cost on the main thread, and does it get faster concurrently?
/// - Do the Podcasts, Books and Music-synced libraries show up through MediaPlayer at all?
/// - How often does the library announce a change while a song plays?
@MainActor
final class BenchmarkRunner: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var isRunning = false

    private static let artworkSample = 2_000
    private static let artworkSide: CGFloat = 128

    func run(library: any MusicLibraryProtocol) async {
        guard !isRunning else { return }
        isRunning = true
        lines = []
        defer { isRunning = false }

        log("Device: \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)")
        do {
            try await fetchCosts(library)
            try await propertyReads(library)
            try await artworkCosts(library)
            try await reachability(library)
            log("Done.")
        } catch {
            log("Stopped: \(error.localizedDescription)")
        }
    }

    /// Counts `MPMediaLibraryDidChange` events while you use the device, to see whether playing a
    /// song (play count, last played date) makes the list refetch.
    func observeChanges(library: any MusicLibraryProtocol, seconds: Int = 90) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        log("Observing library changes for \(seconds)s. Play a song to the end, skip one, rate one.")
        let clock = ContinuousClock()
        let start = clock.now
        var count = 0
        let listener = Task { @MainActor in
            for await date in library.changes {
                count += 1
                log("  change #\(count) at +\(Self.seconds(clock.now - start))s (lastModified \(date.formatted(date: .omitted, time: .standard)))")
            }
        }
        try? await Task.sleep(for: .seconds(seconds))
        listener.cancel()
        log("\(count) change event(s) in \(seconds)s.")
    }

    // MARK: Fetch and filter

    private func fetchCosts(_ library: any MusicLibraryProtocol) async throws {
        log("\n== Fetch, filter, sort ==")
        let songs = try await time("fetch(.songs)") { try await library.fetch(.songs) }
        log("  \(songs.count) songs")

        _ = try await time("in-memory filter  playCount >= 10") {
            try await library.fetch(.songs.filter(\.playCount >= 10))
        }
        _ = try await time("in-memory filter  skipCount > 0") {
            try await library.fetch(.songs.filter(\.skipCount > 0))
        }
        if let artist = songs.lazy.compactMap(\.artist).first {
            _ = try await time("pushed-down filter  artist == \"\(artist)\"") {
                try await library.fetch(.songs.filter(\.artist == artist))
            }
        }
        _ = try await time("sorted by playCount, limit 25") {
            try await library.fetch(.songs.sorted(by: \.playCount, .reverse).limit(25))
        }
        _ = try await time("sorted by title") {
            try await library.fetch(.songs.sorted(by: \.title))
        }
    }

    // MARK: Property reads

    /// One `value(forProperty:)` per property (what `EntityReader` does) against one
    /// `enumerateValues(forProperties:)` per item. Each runs twice because the second pass is warm.
    private func propertyReads(_ library: any MusicLibraryProtocol) async throws {
        log("\n== Reading 4 properties per song ==")
        let items = try await library.fetch(.songs).map(\.mediaItem)
        let keys = [
            MPMediaItemPropertyPlayCount, MPMediaItemPropertySkipCount,
            MPMediaItemPropertyRating, MPMediaItemPropertyPlaybackDuration,
        ]
        let keySet = Set(keys)

        for pass in ["cold", "warm"] {
            var perProperty = 0.0
            let a = clockTime {
                for item in items {
                    for key in keys { perProperty += (item.value(forProperty: key) as? NSNumber)?.doubleValue ?? 0 }
                }
            }
            log("  \(pass): value(forProperty:) x4      \(a)")

            var batched = 0.0
            let b = clockTime {
                for item in items {
                    item.enumerateValues(forProperties: keySet) { _, value, _ in
                        batched += (value as? NSNumber)?.doubleValue ?? 0
                    }
                }
            }
            log("  \(pass): enumerateValues(forProperties:) \(b)")
            if perProperty != batched { log("  !! totals differ: \(perProperty) vs \(batched)") }
        }
    }

    // MARK: Artwork

    private func artworkCosts(_ library: any MusicLibraryProtocol) async throws {
        log("\n== Artwork, \(Self.artworkSample) albums at \(Int(Self.artworkSide))pt ==")
        let albums = Array(try await library.fetch(.albums).prefix(Self.artworkSample))
        log("  \(albums.count) albums")
        let size = CGSize(width: Self.artworkSide, height: Self.artworkSide)

        for pass in ["main thread, cold", "main thread, warm"] {
            var found = 0
            let elapsed = clockTime {
                for album in albums where album.artwork(size: size) != nil { found += 1 }
            }
            log("  \(pass): \(elapsed)  (\(found) with artwork)")
        }

        let clock = ContinuousClock()
        let start = clock.now
        let found = await withTaskGroup(of: Bool.self) { group in
            for album in albums {
                group.addTask { album.artwork(size: size) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        log("  off main, concurrent (warm): \(Self.format(clock.now - start))  (\(found) with artwork)")
        log("  Timing can't prove `imageWithSize:` is thread-safe; check Apple's docs and Thread Sanitizer before relying on it.")
    }

    // MARK: Reachability

    private func reachability(_ library: any MusicLibraryProtocol) async throws {
        log("\n== What MediaPlayer can see ==")
        log("  Albums \(try await library.fetch(.albums).count), artists \(try await library.fetch(.artists).count), playlists \(try await library.fetch(.playlists).count)")
        log("  Podcasts \(try await library.fetch(.podcasts).count), episodes \(try await library.fetch(.podcastEpisodes).count), audiobooks \(try await library.fetch(.audiobooks).count)")
        log("  If these are 0 while the Podcasts or Books app holds content, MediaPlayer can't reach it: don't build 1.7.")
        log("  (The iOS 18.5 SDK headers have no \"has been played\" property; derive it from playCount or bookmarkTime.)")
    }

    // MARK: Helpers

    private func time<T>(_ label: String, _ work: () async throws -> T) async rethrows -> T {
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await work()
        log("  \(label): \(Self.format(clock.now - start))")
        return result
    }

    private func clockTime(_ work: () -> Void) -> String {
        let clock = ContinuousClock()
        let start = clock.now
        work()
        return Self.format(clock.now - start)
    }

    private func log(_ line: String) {
        print("[benchmark]", line)
        lines.append(line)
    }

    private static func format(_ duration: Duration) -> String {
        let ms = Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
        return String(format: "%.1f ms", ms)
    }

    private static func seconds(_ duration: Duration) -> String {
        String(format: "%.1f", Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
    }
}

struct BenchmarkView: View {
    @Environment(\.musicLibrary) private var library
    @StateObject private var runner = BenchmarkRunner()

    var body: some View {
        NavigationStack {
            List(Array(runner.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Benchmark")
            .toolbar {
                ToolbarItemGroup {
                    Button("Run") { Task { await runner.run(library: library) } }
                    Button("Watch changes") { Task { await runner.observeChanges(library: library) } }
                    ShareLink(item: runner.lines.joined(separator: "\n"))
                }
            }
            .disabled(runner.isRunning)
            .overlay { if runner.isRunning { ProgressView() } }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-autorun") {
                    await runner.run(library: library)
                }
            }
        }
    }
}
