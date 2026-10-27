import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Alphabetical sorting")
struct AlphabeticalSortTests {

    static func library(_ titles: [String?]) -> MusicLibrary {
        let items = titles.map { title in
            StubMediaItem(title.map { [MPMediaItemPropertyTitle: $0] } ?? [:])
        }
        return MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: items))
    }

    @Suite("Given titles in mixed case")
    struct MixedCase {
        let library = AlphabeticalSortTests.library(["Zebra", "apple", "Mango", "banana"])

        @Test("When sorted by title, then lowercase titles sit among the capitalized ones")
        func ignoresCase() async throws {
            let songs = try await library.fetch(.songs.sorted(by: \.title))
            #expect(songs.map(\.title) == ["apple", "banana", "Mango", "Zebra"])
        }

        @Test("When sorted by title in reverse, then the alphabetical order flips")
        func reverse() async throws {
            let songs = try await library.fetch(.songs.sorted(by: \.title, .reverse))
            #expect(songs.map(\.title) == ["Zebra", "Mango", "banana", "apple"])
        }
    }

    @Suite("Given titles with numbers")
    struct Numbers {
        let library = AlphabeticalSortTests.library(["Track 10", "Track 2", "Track 1"])

        @Test("When sorted by title, then numbers compare by value")
        func numbersByValue() async throws {
            let songs = try await library.fetch(.songs.sorted(by: \.title))
            #expect(songs.map(\.title) == ["Track 1", "Track 2", "Track 10"])
        }
    }

    @Suite("Given a song without a title")
    struct MissingTitle {
        let library = AlphabeticalSortTests.library(["beta", nil, "Alpha"])

        @Test("When sorted by title, then the missing title comes first")
        func missingFirst() async throws {
            let songs = try await library.fetch(.songs.sorted(by: \.title))
            #expect(songs.map(\.title) == [nil, "Alpha", "beta"])
        }
    }

    @Suite("Given a tie on the first key")
    struct TieBreak {
        @Test("When title breaks the tie, then it is alphabetical too")
        func thenByTitle() async throws {
            let items = [
                StubMediaItem.song("Bravo", plays: 3),
                StubMediaItem.song("apple", plays: 3),
                StubMediaItem.song("mike", plays: 9),
            ]
            let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: items))

            let songs = try await library.fetch(.songs.sorted(by: \.playCount, .reverse).then(by: \.title))

            #expect(songs.map(\.title) == ["mike", "apple", "Bravo"])
        }
    }

    @Suite("Given a non-optional string key")
    struct NonOptional {
        let library = AlphabeticalSortTests.library(["Zebra", "apple", nil])

        @Test("When sorted by it, then the order is alphabetical")
        func sortedByString() async throws {
            let songs = try await library.fetch(.songs.sorted(by: \.titleOrEmpty))
            #expect(songs.map(\.titleOrEmpty) == ["", "apple", "Zebra"])
        }

        @Test("When it breaks a tie, then the order is alphabetical")
        func thenByString() async throws {
            let songs = try await library.fetch(.songs.sorted(by: \.playCount).then(by: \.titleOrEmpty))
            #expect(songs.map(\.titleOrEmpty) == ["", "apple", "Zebra"])
        }
    }

    @Suite("Given a large library")
    struct Performance {
        @Test("When 1,000 songs are sorted by title, then each song's title is read exactly once")
        func readsTitleOnce() async throws {
            let items = (0..<1_000).map { StubMediaItem.song("Song \(($0 * 7919) % 1_000)") }
            let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: items))

            let songs = try await library.fetch(.songs.sorted(by: \.title))

            #expect(items.allSatisfy { $0.reads == [MPMediaItemPropertyTitle] })
            #expect(songs.first?.title == "Song 0")
            #expect(songs.last?.title == "Song 999")
        }
    }
}

private extension Song {
    var titleOrEmpty: String { title ?? "" }
}
