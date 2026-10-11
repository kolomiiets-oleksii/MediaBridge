import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("PlayCountHistory")
struct PlayCountHistoryTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func day(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    static func history(_ store: InMemoryPlayCountStore = InMemoryPlayCountStore()) -> PlayCountHistory {
        PlayCountHistory(store: store, calendar: calendar)
    }

    @Suite("Given recorded counts")
    struct Recording {
        @Test("When nothing was recorded, then no plays are known")
        func empty() async throws {
            let history = PlayCountHistoryTests.history()
            #expect(try await history.plays(since: .distantPast) == [:])
            #expect(try await history.firstRecorded() == nil)
        }

        @Test("When the first record is made, then it is the baseline and no plays are counted yet")
        func baseline() async throws {
            let history = PlayCountHistoryTests.history()
            try await history.record(counts: [1: 50, 2: 7], at: PlayCountHistoryTests.day(1))

            #expect(try await history.plays(since: .distantPast, until: PlayCountHistoryTests.day(2)) == [:])
            #expect(try await history.firstRecorded() == PlayCountHistoryTests.day(1))
        }

        @Test("When counts grow later, then the difference is the plays in between")
        func deltas() async throws {
            let history = PlayCountHistoryTests.history()
            try await history.record(counts: [1: 50, 2: 7], at: PlayCountHistoryTests.day(1))
            try await history.record(counts: [1: 53, 2: 7, 3: 1], at: PlayCountHistoryTests.day(3))

            #expect(try await history.plays(since: PlayCountHistoryTests.day(1), until: PlayCountHistoryTests.day(4)) == [1: 3, 3: 1])
        }

        @Test("When asked for a period, then plays before and after it are left out")
        func period() async throws {
            let history = PlayCountHistoryTests.history()
            try await history.record(counts: [1: 10], at: PlayCountHistoryTests.day(1))
            try await history.record(counts: [1: 12], at: PlayCountHistoryTests.day(3))
            try await history.record(counts: [1: 20], at: PlayCountHistoryTests.day(6))

            #expect(try await history.plays(since: PlayCountHistoryTests.day(2), until: PlayCountHistoryTests.day(4)) == [1: 2])
            #expect(try await history.plays(since: PlayCountHistoryTests.day(4), until: PlayCountHistoryTests.day(7)) == [1: 8])
            #expect(try await history.plays(since: PlayCountHistoryTests.day(1), until: PlayCountHistoryTests.day(7)) == [1: 10])
        }

        @Test("When the period starts before the first record, then it counts from the first record")
        func beforeFirst() async throws {
            let history = PlayCountHistoryTests.history()
            try await history.record(counts: [1: 500], at: PlayCountHistoryTests.day(10))
            try await history.record(counts: [1: 504], at: PlayCountHistoryTests.day(12))

            #expect(try await history.plays(since: PlayCountHistoryTests.day(1), until: PlayCountHistoryTests.day(13)) == [1: 4])
        }

        @Test("When nothing changed, then no snapshot is added")
        func unchanged() async throws {
            let store = InMemoryPlayCountStore()
            let history = PlayCountHistoryTests.history(store)
            try await history.record(counts: [1: 5], at: PlayCountHistoryTests.day(1))
            try await history.record(counts: [1: 5], at: PlayCountHistoryTests.day(2))

            #expect(try store.load().count == 1)
        }

        @Test("When only some counts changed, then a snapshot holds only those")
        func sparse() async throws {
            let store = InMemoryPlayCountStore()
            let history = PlayCountHistoryTests.history(store)
            try await history.record(counts: [1: 5, 2: 5, 3: 5], at: PlayCountHistoryTests.day(1))
            try await history.record(counts: [1: 5, 2: 6, 3: 5], at: PlayCountHistoryTests.day(2))

            #expect(try store.load().last?.counts == [2: 6])
        }

        @Test("When recorded again on the same day, then it replaces that day's snapshot")
        func sameDay() async throws {
            let store = InMemoryPlayCountStore()
            let history = PlayCountHistoryTests.history(store)
            try await history.record(counts: [1: 5], at: PlayCountHistoryTests.day(1))
            try await history.record(counts: [1: 6], at: PlayCountHistoryTests.day(2, hour: 8))
            try await history.record(counts: [1: 8], at: PlayCountHistoryTests.day(2, hour: 20))

            #expect(try store.load().count == 2)
            #expect(try await history.plays(since: PlayCountHistoryTests.day(1), until: PlayCountHistoryTests.day(3)) == [1: 3])
        }

        @Test("When plays happen on the day of the first record, then they still count")
        func baselineDay() async throws {
            let history = PlayCountHistoryTests.history()
            try await history.record(counts: [1: 5], at: PlayCountHistoryTests.day(1, hour: 8))
            try await history.record(counts: [1: 7], at: PlayCountHistoryTests.day(1, hour: 20))

            #expect(try await history.plays(since: PlayCountHistoryTests.day(1, hour: 8), until: PlayCountHistoryTests.day(2)) == [1: 2])
        }

        @Test("When a count goes down, then it isn't counted as plays")
        func reset() async throws {
            let history = PlayCountHistoryTests.history()
            try await history.record(counts: [1: 50], at: PlayCountHistoryTests.day(1))
            try await history.record(counts: [1: 2], at: PlayCountHistoryTests.day(2))

            #expect(try await history.plays(since: PlayCountHistoryTests.day(1), until: PlayCountHistoryTests.day(3)) == [:])
        }

        @Test("When reset, then everything is forgotten")
        func forgets() async throws {
            let store = InMemoryPlayCountStore()
            let history = PlayCountHistoryTests.history(store)
            try await history.record(counts: [1: 5], at: PlayCountHistoryTests.day(1))

            try await history.reset()

            #expect(try store.load().isEmpty)
            #expect(try await history.firstRecorded() == nil)
        }

        @Test("When a new history opens the same store, then it sees the earlier snapshots")
        func persists() async throws {
            let store = InMemoryPlayCountStore()
            try await PlayCountHistoryTests.history(store).record(counts: [1: 5], at: PlayCountHistoryTests.day(1))
            let reopened = PlayCountHistoryTests.history(store)
            try await reopened.record(counts: [1: 9], at: PlayCountHistoryTests.day(2))

            #expect(try await reopened.plays(since: PlayCountHistoryTests.day(1), until: PlayCountHistoryTests.day(3)) == [1: 4])
        }
    }

    @Suite("Given a library")
    struct FromLibrary {
        @Test("When recorded from a library, then played songs' counts are stored by persistent ID")
        func fromLibrary() async throws {
            let items = [
                LibraryGroupingTests.song("A", "X", plays: 3, id: 11),
                LibraryGroupingTests.song("B", "X", plays: 0, id: 12),
            ]
            let store = InMemoryPlayCountStore()
            let history = PlayCountHistoryTests.history(store)

            try await history.record(from: MusicLibrary.preview(songs: items), at: PlayCountHistoryTests.day(1))

            #expect(try store.load().first?.counts == [11: 3])
        }

        @Test("When access is denied, then recording throws the library's error")
        func denied() async {
            let history = PlayCountHistoryTests.history()
            await #expect(throws: MusicLibraryError.unauthorized(.denied)) {
                try await history.record(from: MusicLibrary.accessDenied)
            }
        }
    }

    @Suite("Given a store")
    struct Stores {
        struct FailingStore: PlayCountStore {
            struct Failure: Error {}
            func load() throws -> [PlayCountSnapshot] { throw Failure() }
            func save(_ snapshots: [PlayCountSnapshot]) throws { throw Failure() }
        }

        @Test("When the store fails, then the error is wrapped")
        func failing() async {
            let history = PlayCountHistory(store: FailingStore())
            await #expect(throws: MusicLibraryError.self) {
                try await history.record(counts: [1: 1], at: Date())
            }
        }

        @Test("When saved to a file, then another store reads the same snapshots")
        func file() throws {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/PlayCounts.json")
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let snapshots = [
                PlayCountSnapshot(date: PlayCountHistoryTests.day(1), counts: [1: 5, 2: 6]),
                PlayCountSnapshot(date: PlayCountHistoryTests.day(2), counts: [2: 7]),
            ]

            try FilePlayCountStore(url: url).save(snapshots)

            #expect(try FilePlayCountStore(url: url).load() == snapshots)
        }

        @Test("When the file doesn't exist yet, then there are no snapshots")
        func missingFile() throws {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)/none.json")
            #expect(try FilePlayCountStore(url: url).load().isEmpty)
        }
    }
}
