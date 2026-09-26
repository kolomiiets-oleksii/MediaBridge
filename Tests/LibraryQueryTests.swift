import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("LibraryQuery")
struct LibraryQueryTests {

    static func songs() -> [StubMediaItem] {
        [
            StubMediaItem.track("Help!", "The Beatles", plays: 7, rating: 4),
            StubMediaItem.track("Hello", "Adele", plays: 12, rating: 5),
            StubMediaItem.track("Yesterday", "The Beatles", plays: 12, rating: 5),
            StubMediaItem.track("Angie", "The Rolling Stones", plays: 1, rating: 2),
        ]
    }

    @Suite("Given a filter MediaPlayer can run")
    struct Pushdown {
        let service = MockMusicLibraryService(items: LibraryQueryTests.songs())
        var library: MusicLibrary { MusicLibrary(auth: .mock, service: service) }

        @Test("When filtering by artist equality, then the predicate goes into the MediaPlayer query")
        func equals() async throws {
            _ = try await library.fetch(Song.query.filter(\.artist, .equals("The Beatles")))
            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filters: [.init(.artist("The Beatles"))], grouping: .title)
                ])
        }

        @Test("When filtering a title by substring, then MediaPlayer runs a contains predicate")
        func contains() async throws {
            _ = try await library.fetch(Song.query.filter(\.title, .contains("hel")))
            #expect(service.requests.first?.filters == [.init(.title("hel"), .contains)])
        }

        @Test("When filtering by a Bool flag, then it is pushed down too")
        func flag() async throws {
            _ = try await library.fetch(Song.query.filter(\.isCloudItem, .equals(false)))
            #expect(service.requests.first?.filters == [.init(.isCloudItem(false))])
        }
    }

    @Suite("Given a filter MediaPlayer can't run")
    struct InMemory {
        let service = MockMusicLibraryService(items: LibraryQueryTests.songs())
        var library: MusicLibrary { MusicLibrary(auth: .mock, service: service) }

        @Test("When filtering play count above a threshold, then it runs in memory")
        func greaterThan() async throws {
            let songs = try await library.fetch(Song.query.filter(\.playCount, .greaterThan(5)))

            #expect(service.requests.first?.filters == [])
            #expect(songs.map(\.title) == ["Help!", "Hello", "Yesterday"])
        }

        @Test("When filtering by rating, which MediaPlayer can't filter, then it runs in memory")
        func unsupportedProperty() async throws {
            let songs = try await library.fetch(Song.query.filter(\.rating, .equals(5)))

            #expect(service.requests.first?.filters == [])
            #expect(songs.map(\.title) == ["Hello", "Yesterday"])
        }

        @Test("When one filter is pushed and another isn't, then both apply")
        func mixed() async throws {
            let songs = try await library.fetch(
                Song.query.filter(\.title, .contains("e")).filter(\.playCount, .atLeast(12)))

            #expect(service.requests.first?.filters == [.init(.title("e"), .contains)])
            #expect(songs.map(\.title) == ["Hello", "Yesterday"])
        }
    }

    @Suite("Given songs to order")
    struct Ordering {
        var library: MusicLibrary {
            MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: LibraryQueryTests.songs()))
        }

        @Test("When sorted by play count in reverse, then title breaks ties")
        func tieBreaker() async throws {
            let songs = try await library.fetch(Song.query.sorted(by: \.playCount, .reverse).then(by: \.title))
            #expect(songs.map(\.title) == ["Hello", "Yesterday", "Help!", "Angie"])
        }

        @Test("When sorting again, then the new key replaces the old one")
        func resorting() async throws {
            let songs = try await library.fetch(Song.query.sorted(by: \.playCount).sorted(by: \.title))
            #expect(songs.map(\.title) == ["Angie", "Hello", "Help!", "Yesterday"])
        }

        @Test("When limited after sorting, then only the top results come back")
        func limit() async throws {
            let songs = try await library.fetch(Song.query.sorted(by: \.rating, .reverse).then(by: \.title).limit(2))
            #expect(songs.map(\.title) == ["Hello", "Yesterday"])
        }

        @Test("When equal keys have no tie-breaker, then the library order is kept")
        func stable() async throws {
            let songs = try await library.fetch(Song.query.sorted(by: \.artist))
            #expect(songs.map(\.title) == ["Hello", "Help!", "Yesterday", "Angie"])
        }
    }

    @Suite("Given a large library")
    struct Performance {
        @Test("When 1,000 songs are sorted by play count, then each song's play count is read exactly once")
        func readsSortKeyOnce() async throws {
            let items = (0..<1_000).map { StubMediaItem.track("Song \($0)", "Artist", plays: ($0 * 7919) % 1_000) }
            let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: items))

            let songs = try await library.fetch(Song.query.sorted(by: \.playCount, .reverse))

            #expect(items.allSatisfy { $0.reads == [MPMediaItemPropertyPlayCount] })
            #expect(songs.first?.playCount == 999)
        }

        @Test("When 10,000 songs are fetched unsorted and unfiltered, then no property is read")
        func zeroReads() async throws {
            let items = (0..<10_000).map { StubMediaItem.track("Song \($0)", "Artist") }
            let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: items))

            _ = try await library.fetch(Song.query)

            #expect(items.allSatisfy { $0.reads.isEmpty })
        }
    }

    @Suite("Given access is denied")
    struct Unauthorized {
        @Test("When fetching a query, then it throws and the service is never queried")
        func guarded() async {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: service)

            await #expect(throws: MusicLibraryError.unauthorized(.denied)) {
                _ = try await library.fetch(Song.query)
            }
            #expect(service.requests.isEmpty)
        }
    }
}

extension StubMediaItem {
    static func track(_ title: String, _ artist: String, plays: Int = 0, rating: Int = 0) -> StubMediaItem {
        StubMediaItem([
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyPlayCount: NSNumber(value: plays),
            MPMediaItemPropertyRating: NSNumber(value: rating),
        ])
    }
}
