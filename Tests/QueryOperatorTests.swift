import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Query operators")
struct QueryOperatorTests {

    static func library(_ service: MockMusicLibraryService) -> MusicLibrary {
        MusicLibrary(auth: .mock, service: service)
    }

    @Suite("Given an equality MediaPlayer can run")
    struct Pushdown {
        @Test("When filtering with ==, then the predicate goes into the MediaPlayer query")
        func equals() async throws {
            let service = MockMusicLibraryService()
            _ = try await QueryOperatorTests.library(service).fetch(Song.query.filter(\.artist == "Adele"))
            #expect(service.requests.first?.filters == [.init(.artist("Adele"))])
        }

        @Test("When filtering a flag with ==, then it is pushed down too")
        func flag() async throws {
            let service = MockMusicLibraryService()
            _ = try await QueryOperatorTests.library(service).fetch(Song.query.filter(\.isCloudItem == false))
            #expect(service.requests.first?.filters == [.init(.isCloudItem(false))])
        }
    }

    @Suite("Given comparisons that run in memory")
    struct InMemory {
        let service = MockMusicLibraryService(items: LibraryQueryTests.songs())

        @Test("When filtering with >=, then only songs at the bound or above come back")
        func atLeast() async throws {
            let songs = try await QueryOperatorTests.library(service).fetch(Song.query.filter(\.playCount >= 12))
            #expect(songs.map(\.title) == ["Hello", "Yesterday"])
        }

        @Test("When filtering with <, >, <= and !=, then each matches like its condition")
        func others() async throws {
            let library = QueryOperatorTests.library(service)
            #expect(try await library.fetch(Song.query.filter(\.playCount < 7)).map(\.title) == ["Angie"])
            #expect(try await library.fetch(Song.query.filter(\.playCount > 7)).map(\.title) == ["Hello", "Yesterday"])
            #expect(try await library.fetch(Song.query.filter(\.rating <= 2)).map(\.title) == ["Angie"])
            #expect(try await library.fetch(Song.query.filter(\.artist != "The Beatles")).map(\.title) == ["Hello", "Angie"])
        }

        @Test("When comparing an optional with >, then missing values never match")
        func optional() async throws {
            let service = MockMusicLibraryService(items: [
                StubMediaItem([MPMediaItemPropertyTitle: "Dated", MPMediaItemPropertyReleaseDate: Date()]),
                StubMediaItem([MPMediaItemPropertyTitle: "Undated"]),
            ])
            let songs = try await QueryOperatorTests.library(service)
                .fetch(Song.query.filter(\.releaseDate > Date(timeIntervalSince1970: 0)))
            #expect(songs.map(\.title) == ["Dated"])
        }
    }
}
