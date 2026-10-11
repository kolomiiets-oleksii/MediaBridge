import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Grouping and sections")
struct LibraryGroupingTests {
    static func song(
        _ title: String, _ artist: String?, plays: Int, duration: Double = 100, added: Date? = nil, id: UInt64 = 0
    ) -> StubMediaItem {
        var values: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlayCount: NSNumber(value: plays),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: duration),
        ]
        if let artist { values[MPMediaItemPropertyArtist] = artist }
        if let added { values[MPMediaItemPropertyDateAdded] = added }
        if id != 0 { values[MPMediaItemPropertyPersistentID] = NSNumber(value: id) }
        return StubMediaItem(values)
    }

    static let library = MusicLibrary.preview(songs: [
        song("Hello", "Adele", plays: 10, duration: 295),
        song("Help!", "The Beatles", plays: 4, duration: 140),
        song("Skyfall", "Adele", plays: 6, duration: 286),
        song("Untitled", nil, plays: 2),
        song("Yesterday", "The Beatles", plays: 20, duration: 125),
    ])

    @Suite("Given songs grouped by artist")
    struct Grouped {
        @Test("When grouped, then each artist appears once, in the order first met")
        func order() async throws {
            let groups = try await LibraryGroupingTests.library.grouped(.songs.sorted(by: \.title), by: \.artist)
            #expect(groups.map(\.key) == ["Adele", "The Beatles", nil])
            #expect(groups.map(\.count) == [2, 2, 1])
        }

        @Test("When summed, then totals cover each group's songs")
        func sums() async throws {
            let groups = try await LibraryGroupingTests.library.grouped(.songs.sorted(by: \.title), by: \.artist)
            #expect(groups.map { $0.sum(of: \.playCount) } == [16, 24, 2])
        }

        @Test("When summing a computed value, then listening time is duration times plays")
        func listeningTime() async throws {
            let groups = try await LibraryGroupingTests.library.grouped(.songs.sorted(by: \.title), by: \.artist)
            let seconds: Double = groups[1].sum(of: { $0.duration * Double($0.playCount) })
            let expected: Double = 140 * 4 + 125 * 20
            #expect(seconds == expected)
        }

        @Test("When asked for extremes and the mean, then they're computed over the group")
        func extremes() async throws {
            let adele = try await #require(LibraryGroupingTests.library.grouped(.songs, by: \.artist).first { $0.key == "Adele" })
            #expect(adele.maximum(of: \.playCount) == 10)
            #expect(adele.minimum(of: \.playCount) == 6)
            #expect(adele.average(of: { Double($0.playCount) }) == 8)
        }

        @Test("When sorted by a total, then the biggest group is first")
        func sortedByTotal() async throws {
            let groups = try await LibraryGroupingTests.library.grouped(.songs, by: \.artist)
                .sorted { $0.sum(of: \.playCount) > $1.sum(of: \.playCount) }
            #expect(groups.first?.key == "The Beatles")
        }

        @Test("When the query filters and limits, then only those songs are grouped")
        func filtered() async throws {
            let groups = try await LibraryGroupingTests.library.grouped(
                .songs.filter(\.playCount >= 6).sorted(by: \.playCount, .reverse).limit(2), by: \.artist)
            #expect(groups.map(\.key) == ["The Beatles", "Adele"])
            #expect(groups.map(\.count) == [1, 1])
        }

        @Test("When nothing matches, then there are no groups")
        func empty() async throws {
            #expect(try await LibraryGroupingTests.library.grouped(.songs.filter(\.playCount > 99), by: \.artist).isEmpty)
        }

        @Test("When a group is empty, then there is no maximum, minimum or mean")
        func emptyGroup() {
            let group = LibraryGroup<String, Int>(key: "x", elements: [])
            #expect(group.maximum(of: { $0 }) == nil)
            #expect(group.minimum(of: { $0 }) == nil)
            #expect(group.average(of: { Double($0) }) == nil)
            #expect(group.sum(of: { $0 }) == 0)
        }

        @Test("When history supplies plays, then groups total those instead")
        func withHistory() async throws {
            let library = MusicLibrary.preview(songs: [
                LibraryGroupingTests.song("A", "X", plays: 100, id: 1),
                LibraryGroupingTests.song("B", "Y", plays: 100, id: 2),
            ])
            let plays: [UInt64: Int] = [1: 3, 2: 9]
            let groups = try await library.grouped(.songs, by: \.artist)
                .sorted { $0.sum(of: { plays[$0.id] ?? 0 }) > $1.sum(of: { plays[$0.id] ?? 0 }) }
            #expect(groups.map(\.key) == ["Y", "X"])
        }
    }

    @Suite("Given songs split into sections by a value")
    struct Sections {
        static func date(_ month: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return calendar.date(from: DateComponents(year: 2026, month: month, day: 10))!
        }

        static let library = MusicLibrary.preview(songs: [
            LibraryGroupingTests.song("A", "X", plays: 1, added: date(3)),
            LibraryGroupingTests.song("B", "X", plays: 1, added: date(1)),
            LibraryGroupingTests.song("C", "X", plays: 1, added: nil),
            LibraryGroupingTests.song("D", "X", plays: 1, added: date(3)),
        ])

        static func month(_ date: Date?) -> String? {
            guard let date else { return nil }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }

        @Test("When split by month, then songs share a section and missing values go last")
        func byMonth() async throws {
            let sections = try await Self.library.sections(.songs.sorted(by: \.title), by: \.dateAdded, title: Self.month)
            #expect(sections.map(\.title) == ["Mar", "Jan", "#"])
            #expect(sections.map { $0.elements.map(\.title) } == [["A", "D"], ["B"], ["C"]])
        }

        @Test("When sorted by the key, then sections follow that order")
        func sortedByKey() async throws {
            let sections = try await Self.library.sections(.songs.sorted(by: \.dateAdded, .reverse), by: \.dateAdded, title: Self.month)
            #expect(sections.map(\.title) == ["Mar", "Jan", "#"])
        }

        @Test("When a section would be empty, then it is left out")
        func filtered() async throws {
            let sections = try await Self.library.sections(.songs.filter(\.title != "B"), by: \.dateAdded, title: Self.month)
            #expect(!sections.map(\.title).contains("Jan"))
        }
    }
}
