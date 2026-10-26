import Combine
import MediaBridge
import MediaPlayer
import SwiftUI

/// Measures every stage between asking MediaPlayer for data and showing a sorted list, so a change
/// is kept or dropped on a number. Launch the Example with `-benchmark` on a real device with a
/// large library; the simulator's library is empty and tells you nothing.
///
/// MediaPlayer caches a property for the rest of the launch once any item has read it, so only the
/// first read of a property is cold. Sections run in an order that hands each one properties
/// nothing earlier has touched. To measure one section completely cold, relaunch with
/// `-only <section>[,<section>…]`, for example `-only app`.
///
/// Each line prints `first`, the run that paid any one-time cost, and `then`, the median of the
/// runs after it.
@MainActor
final class BenchmarkRunner: ObservableObject {
    @Published private(set) var lines: [String] = []
    @Published private(set) var isRunning = false

    enum Section: String, CaseIterable {
        case reads, fetch, filter, sort, sections, app, artwork, reach
    }

    private static let artworkSample = 2_000
    private static let artworkSide: CGFloat = 128
    private static let warmRepeats = 3

    private var summary: [(Section, Duration)] = []

    func run(library: any MusicLibraryProtocol) async {
        guard !isRunning else { return }
        isRunning = true
        lines = []
        summary = []
        defer { isRunning = false }

        let sections = Self.selectedSections
        log("Device: \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)")
        log("Sections: \(sections.map(\.rawValue).joined(separator: ", "))")
        do {
            _ = try await library.requestAuthorization()
            log("\n== Setup ==")
            measureSync("MediaPlayer setup (tiny query, no match)") {
                MPMediaQuery(filterPredicates: [
                    MPMediaPropertyPredicate(value: NSNumber(value: UInt64(0)), forProperty: MPMediaItemPropertyPersistentID)
                ]).items?.count ?? 0
            }
            for section in sections {
                let clock = ContinuousClock()
                let start = clock.now
                try await run(section, library)
                summary.append((section, clock.now - start))
            }
            log("\n== Summary ==")
            for (section, duration) in summary {
                log("  \(section.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \(Self.format(duration))")
            }
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

        do {
            guard try await library.requestAuthorization() == .authorized else {
                log("Music library access not allowed; nothing to observe.")
                return
            }
        } catch {
            log("Stopped: \(error.localizedDescription)")
            return
        }

        let modifiedBefore = MPMediaLibrary.default().lastModifiedDate
        log("Observing library changes for \(seconds)s. Play a song to the end, skip one, rate one.")
        log("  library last modified \(modifiedBefore.formatted(date: .omitted, time: .standard))")
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
        let modifiedAfter = MPMediaLibrary.default().lastModifiedDate
        log("\(count) change event(s) in \(seconds)s.")
        log("  library last modified \(modifiedAfter.formatted(date: .omitted, time: .standard)) (\(modifiedAfter == modifiedBefore ? "unchanged" : "changed"))")
    }

    private func run(_ section: Section, _ library: any MusicLibraryProtocol) async throws {
        switch section {
        case .reads: propertyReads()
        case .fetch: try await fetchCosts(library)
        case .filter: try await filterCosts(library)
        case .sort: try await sortCosts(library)
        case .sections: try await sectionCosts(library)
        case .app: try await appScenario(library)
        case .artwork: try await artworkCosts(library)
        case .reach: try await reachability(library)
        }
    }

    // MARK: Property reads

    /// One `value(forProperty:)` per property against one `enumerateValues(forProperties:)` per
    /// item, each on properties nothing else has read, for one key and for two. A warm-up read of
    /// an unused property pays the database setup first, so neither method gets it for free.
    /// `-swapReads` hands each method the other's properties and runs it first instead of second,
    /// so neither a property nor a position can pose as a difference between methods. Every
    /// property here is set on every song: the SDK declares `enumerateValues`' value as non-optional
    /// `Any`, and a missing value (a song without a composer) crashes while bridging.
    private func propertyReads() {
        log("\n== Property reads, cold then warm ==")
        let items = MPMediaQuery.songs().items ?? []
        log("  \(items.count) songs")
        measureSync("warm-up, untracked property  DiscNumber") { Self.readEach(items, [MPMediaItemPropertyDiscNumber]) }

        let swapped = ProcessInfo.processInfo.arguments.contains("-swapReads")
        var perProperty = [[MPMediaItemPropertyRating], [MPMediaItemPropertyAlbumTrackNumber, MPMediaItemPropertyAlbumTrackCount]]
        var batched = [[MPMediaItemPropertyPlaybackDuration], [MPMediaItemPropertyAlbumArtist, MPMediaItemPropertyReleaseDate]]
        if swapped {
            swap(&perProperty, &batched)
            log("  (swapped: each method reads the other's properties and enumerateValues runs first)")
        }

        for (singleKeys, batchKeys) in zip(perProperty, batched) {
            let readOneByOne = {
                self.measureSync("value(forProperty:)  \(Self.names(singleKeys))") { Self.readEach(items, singleKeys) }
            }
            let readBatched = {
                self.measureSync("enumerateValues      \(Self.names(batchKeys))") { Self.readBatched(items, batchKeys) }
            }
            if swapped {
                readBatched()
                readOneByOne()
            } else {
                readOneByOne()
                readBatched()
            }
        }

        let checked = perProperty[0]
        let freshItems = MPMediaQuery.songs().items ?? []
        measureSync("same property, new query's items  \(Self.names(checked))") { Self.readEach(freshItems, checked) }
        log("  If that first read is as slow as the cold one above, every fetch starts cold;")
        log("  if it's fast, MediaPlayer caches a property for the whole launch.")
    }

    // MARK: Fetch

    /// MediaPlayer's own query with every result materialized, next to MediaBridge's `fetch`, per
    /// element type. The raw query runs first so each `fetch` line is MediaBridge's work on top.
    private func fetchCosts(_ library: any MusicLibraryProtocol) async throws {
        log("\n== Fetch: raw MediaPlayer vs MediaBridge ==")
        measureSync("raw songs") { Self.materialize(Self.musicQuery(.title).items) }
        try await measure("fetch(.songs)") { try await library.fetch(.songs).count }
        measureSync("raw albums") { Self.materialize(Self.musicQuery(.album).collections) }
        try await measure("fetch(.albums)") { try await library.fetch(.albums).count }
        measureSync("raw artists") { Self.materialize(Self.musicQuery(.artist).collections) }
        try await measure("fetch(.artists)") { try await library.fetch(.artists).count }
        measureSync("raw genres") { Self.materialize(Self.musicQuery(.genre).collections) }
        try await measure("fetch(.genres)") { try await library.fetch(.genres).count }
        measureSync("raw composers") { Self.materialize(Self.musicQuery(.composer).collections) }
        try await measure("fetch(.composers)") { try await library.fetch(.composers).count }
        measureSync("raw playlists") { Self.materialize(MPMediaQuery.playlists().collections) }
        try await measure("fetch(.playlists)") { try await library.fetch(.playlists).count }
        log("  Raw rows replay MediaBridge's request, so matching counts mean both timed the same query.")
    }

    // MARK: Filter

    /// Filters MediaPlayer runs in its own query next to filters MediaBridge runs in memory, each
    /// on a property nothing earlier has read.
    private func filterCosts(_ library: any MusicLibraryProtocol) async throws {
        log("\n== Filter ==")
        let monthAgo = Date.now.addingTimeInterval(-30 * 24 * 3600)
        log("  in MediaPlayer's query:")
        try await measure("  isCloudItem == false") { try await library.fetch(.songs.filter(\.isCloudItem, .equals(false))).count }
        try await measure("  playCount == 0") { try await library.fetch(.songs.filter(\.playCount, .equals(0))).count }
        try await measure("  albumTitle contains \"a\"") { try await library.fetch(.songs.filter(\.albumTitle, .contains("a"))).count }
        if let artist = MPMediaQuery.artists().collections?.first?.representativeItem?.artist {
            try await measure("  artist == \"\(artist)\"") { try await library.fetch(.songs.filter(\.artist, .equals(artist))).count }
        }
        log("  in memory:")
        try await measure("  skipCount > 0 (Int)") { try await library.fetch(.songs.filter(\.skipCount, .greaterThan(0))).count }
        try await measure("  isExplicit == true (Bool)") { try await library.fetch(.songs.filter(\.isExplicit, .equals(true))).count }
        try await measure("  lastPlayedDate in 30 days (Date?)") { try await library.fetch(.songs.filter(\.lastPlayedDate, .atLeast(monthAgo))).count }
        try await measure("  skipCount > 0 && isExplicit (2 keys, warm)") {
            try await library.fetch(.songs.filter(\.skipCount, .greaterThan(0)).filter(\.isExplicit, .equals(true))).count
        }
    }

    // MARK: Sort

    /// Sorting by each kind of key, then the same sorts reversed: the reversal re-reads warm keys,
    /// so it shows what changing a list's order costs once its data is loaded.
    private func sortCosts(_ library: any MusicLibraryProtocol) async throws {
        log("\n== Sort ==")
        try await measure("fetch(.songs), no sort (baseline)") { try await library.fetch(.songs).count }
        log("  by one key:")
        try await measure("  title (String?)") { try await library.fetch(.songs.sorted(by: \.title)).count }
        try await measure("  playCount (Int)") { try await library.fetch(.songs.sorted(by: \.playCount)).count }
        try await measure("  dateAdded (Date?)") { try await library.fetch(.songs.sorted(by: \.dateAdded)).count }
        try await measure("  isCompilation (Bool)") { try await library.fetch(.songs.sorted(by: \.isCompilation)).count }
        log("  reordering the same keys:")
        try await measure("  title, reversed") { try await library.fetch(.songs.sorted(by: \.title, .reverse)).count }
        try await measure("  playCount, reversed") { try await library.fetch(.songs.sorted(by: \.playCount, .reverse)).count }
        log("  combined:")
        try await measure("  playCount then title") { try await library.fetch(.songs.sorted(by: \.playCount, .reverse).then(by: \.title)).count }
        try await measure("  playCount then title, limit 25") {
            try await library.fetch(.songs.sorted(by: \.playCount, .reverse).then(by: \.title).limit(25)).count
        }
        try await measure("  albums by title") { try await library.fetch(.albums.sorted(by: \.title)).count }
        try await measure("  artists by name") { try await library.fetch(.artists.sorted(by: \.name)).count }
    }

    // MARK: Sections

    /// A–Z index sections, as the Music app's long lists use.
    private func sectionCosts(_ library: any MusicLibraryProtocol) async throws {
        log("\n== Sections ==")
        try await measure("sections(.songs)") { try await library.sections(.songs).count }
        try await measure("sections(.albums)") { try await library.sections(.albums).count }
        try await measure("sections(.artists)") { try await library.sections(.artists).count }
    }

    // MARK: App scenario

    /// What the Example's song list does: sort by skip count, ties by title, and flip the order from
    /// the toolbar. Run with `-only app` for the numbers a user sees on launch; after the sections
    /// above, both keys are already warm.
    private func appScenario(_ library: any MusicLibraryProtocol) async throws {
        log("\n== App: skipped songs list ==")
        for order in [SortOrder.reverse, .forward, .reverse] {
            try await measure("skipCount \(order == .reverse ? "high first" : "low first"), then title") {
                try await library.fetch(.songs.sorted(by: \.skipCount, order).then(by: \.title)).count
            }
        }
    }

    // MARK: Artwork

    private func artworkCosts(_ library: any MusicLibraryProtocol) async throws {
        let albums = Array(try await library.fetch(.albums).prefix(Self.artworkSample))
        log("\n== Artwork, \(albums.count) albums at \(Int(Self.artworkSide))pt ==")
        let size = CGSize(width: Self.artworkSide, height: Self.artworkSide)

        measureSync("main thread") { albums.filter { $0.artwork(size: size) != nil }.count }
        await measure("off main, concurrent") {
            await withTaskGroup(of: Bool.self) { group in
                for album in albums {
                    group.addTask { album.artwork(size: size) != nil }
                }
                return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
            }
        }
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

    private static var selectedSections: [Section] {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-only"), arguments.indices.contains(flag + 1) else {
            return Section.allCases
        }
        let requested = Set(arguments[flag + 1].split(separator: ",").compactMap { Section(rawValue: String($0)) })
        return Section.allCases.filter(requested.contains)
    }

    private func measure(_ label: String, _ work: () async throws -> Int) async rethrows {
        let clock = ContinuousClock()
        var start = clock.now
        let count = try await work()
        let first = clock.now - start
        var later: [Duration] = []
        for _ in 0..<Self.warmRepeats {
            start = clock.now
            _ = try await work()
            later.append(clock.now - start)
        }
        report(label, first: first, later: later, count: count)
    }

    private func measureSync(_ label: String, _ work: () -> Int) {
        let clock = ContinuousClock()
        var start = clock.now
        let count = work()
        let first = clock.now - start
        var later: [Duration] = []
        for _ in 0..<Self.warmRepeats {
            start = clock.now
            _ = work()
            later.append(clock.now - start)
        }
        report(label, first: first, later: later, count: count)
    }

    private func report(_ label: String, first: Duration, later: [Duration], count: Int) {
        let median = later.sorted()[later.count / 2]
        let padded = label.padding(toLength: max(label.count, 44), withPad: " ", startingAt: 0)
        log("  \(padded) first \(Self.format(first).leftPadded(9))  then \(Self.format(median).leftPadded(9))  (\(count))")
    }

    private static func musicQuery(_ grouping: MPMediaGrouping) -> MPMediaQuery {
        let query = MPMediaQuery(filterPredicates: [
            MPMediaPropertyPredicate(value: NSNumber(value: MPMediaType.music.rawValue), forProperty: MPMediaItemPropertyMediaType)
        ])
        query.groupingType = grouping
        return query
    }

    private static func readEach(_ items: [MPMediaItem], _ properties: [String]) -> Int {
        var found = 0
        for item in items {
            for property in properties where item.value(forProperty: property) != nil { found += 1 }
        }
        return found
    }

    private static func readBatched(_ items: [MPMediaItem], _ properties: [String]) -> Int {
        let keys = Set(properties)
        var found = 0
        for item in items {
            item.enumerateValues(forProperties: keys) { _, value, _ in
                if !(value is NSNull) { found += 1 }
            }
        }
        return found
    }

    private static func materialize<Element>(_ results: [Element]?) -> Int {
        var count = 0
        for _ in results ?? [] { count += 1 }
        return count
    }

    private static func names(_ properties: [String]) -> String {
        properties.map { $0.replacing("MPMediaItemProperty", with: "") }.joined(separator: "+")
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

private extension String {
    func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
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
