import Foundation

/// How a song's play count changed at one moment.
///
/// A snapshot holds only the songs whose count differed from the previous snapshot, so a year of
/// daily snapshots stays small. The first snapshot holds every song that has been played.
public struct PlayCountSnapshot: Codable, Sendable, Equatable {
    public let date: Date
    /// The new play count of each song whose count changed, by persistent ID.
    public let counts: [UInt64: Int]

    public init(date: Date, counts: [UInt64: Int]) {
        self.date = date
        self.counts = counts
    }
}

/// Where a ``PlayCountHistory`` keeps its snapshots.
public protocol PlayCountStore: Sendable {
    func load() throws -> [PlayCountSnapshot]
    func save(_ snapshots: [PlayCountSnapshot]) throws
}

/// Keeps snapshots in a JSON file, by default in Application Support.
public struct FilePlayCountStore: PlayCountStore {
    private let url: URL

    /// - Parameter url: The file to use. Defaults to `MediaBridge/PlayCounts.json` in Application Support.
    public init(url: URL? = nil) {
        self.url =
            url
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MediaBridge", isDirectory: true)
            .appendingPathComponent("PlayCounts.json")
    }

    public func load() throws -> [PlayCountSnapshot] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([PlayCountSnapshot].self, from: Data(contentsOf: url))
    }

    public func save(_ snapshots: [PlayCountSnapshot]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshots).write(to: url, options: .atomic)
    }
}

/// Keeps snapshots in memory, for previews and tests.
public final class InMemoryPlayCountStore: PlayCountStore, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshots: [PlayCountSnapshot]

    public init(_ snapshots: [PlayCountSnapshot] = []) {
        self.snapshots = snapshots
    }

    public func load() throws -> [PlayCountSnapshot] { lock.withLock { snapshots } }
    public func save(_ snapshots: [PlayCountSnapshot]) throws { lock.withLock { self.snapshots = snapshots } }
}

/// Plays per period, which MediaPlayer can't tell you.
///
/// MediaPlayer keeps only a song's lifetime `playCount` and its last played date, so "plays this
/// month" has no direct answer. `PlayCountHistory` records the counts over time and subtracts.
/// **It can only count from the first time it records**: plays before that are in no period.
///
/// Record when your app launches and comes to the foreground, at day resolution (several records
/// on one day become one snapshot):
///
/// ```swift
/// let history = PlayCountHistory()
/// try await history.record(from: library)
///
/// let monthStart = Calendar.current.dateInterval(of: .month, for: .now)!.start
/// let plays = await history.plays(since: monthStart)      // persistent ID → plays this month
/// let artists = try await library.grouped(.songs, by: \.artist)
///     .sorted { $0.sum(of: { plays[$0.id] ?? 0 }) > $1.sum(of: { plays[$0.id] ?? 0 }) }
/// ```
public actor PlayCountHistory {
    private let store: any PlayCountStore
    private let calendar: Calendar
    private var snapshots: [PlayCountSnapshot]?

    /// - Parameters:
    ///   - store: Where snapshots are kept. Defaults to a file in Application Support.
    ///   - calendar: Decides which records fall on the same day.
    public init(store: any PlayCountStore = FilePlayCountStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    /// When the first snapshot was taken: plays before this are in no period.
    public func firstRecorded() throws(MusicLibraryError) -> Date? {
        try loaded().first?.date
    }

    /// Reads every song's play count and stores the ones that changed since the last record.
    ///
    /// - Throws: ``MusicLibraryError/unauthorized(_:)`` if access isn't granted, or
    ///   ``MusicLibraryError/underlying(_:)`` if the store fails
    public func record(from library: some MusicLibraryProtocol, at date: Date = Date()) async throws(MusicLibraryError) {
        let songs = try await library.fetch(.songs)
        var current: [UInt64: Int] = [:]
        for song in songs where song.playCount > 0 { current[song.id] = song.playCount }
        try record(counts: current, at: date)
    }

    func record(counts current: [UInt64: Int], at date: Date) throws(MusicLibraryError) {
        var all = try loaded()
        let known = Self.totals(of: all, upTo: .distantFuture)
        let changes = current.filter { known[$0.key] != $0.value }
        guard !changes.isEmpty || all.isEmpty else { return }

        // Same-day records fold into one snapshot, except the first: it is the baseline, and plays
        // later that day belong in a period.
        if all.count > 1, let last = all.last, calendar.isDate(last.date, inSameDayAs: date) {
            all[all.count - 1] = PlayCountSnapshot(date: date, counts: last.counts.merging(changes) { $1 })
        } else {
            all.append(PlayCountSnapshot(date: date, counts: changes))
        }
        try persist(all)
    }

    /// How many times each song played from `start` to `end`, by persistent ID. Songs that didn't
    /// play are left out.
    ///
    /// A `start` before the first record counts from the first record.
    public func plays(since start: Date, until end: Date = Date()) throws(MusicLibraryError) -> [UInt64: Int] {
        let all = try loaded()
        guard let first = all.first else { return [:] }
        let before = Self.totals(of: all, upTo: max(start, first.date))
        let after = Self.totals(of: all, upTo: end)
        var result: [UInt64: Int] = [:]
        for (id, total) in after {
            let played = total - (before[id] ?? 0)
            if played > 0 { result[id] = played }
        }
        return result
    }

    /// Forgets every snapshot.
    public func reset() throws(MusicLibraryError) {
        try persist([])
    }

    private func loaded() throws(MusicLibraryError) -> [PlayCountSnapshot] {
        if let snapshots { return snapshots }
        do {
            let loaded = try store.load().sorted { $0.date < $1.date }
            snapshots = loaded
            return loaded
        } catch {
            throw MusicLibraryError.wrapping(error)
        }
    }

    private func persist(_ all: [PlayCountSnapshot]) throws(MusicLibraryError) {
        do {
            try store.save(all)
            snapshots = all
        } catch {
            throw MusicLibraryError.wrapping(error)
        }
    }

    private static func totals(of snapshots: [PlayCountSnapshot], upTo date: Date) -> [UInt64: Int] {
        var totals: [UInt64: Int] = [:]
        for snapshot in snapshots where snapshot.date <= date {
            totals.merge(snapshot.counts) { $1 }
        }
        return totals
    }
}
