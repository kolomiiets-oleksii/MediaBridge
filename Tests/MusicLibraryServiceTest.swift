import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("MusicLibraryService")
struct MusicLibraryServiceTest {
    @Test func testFetchAll_NoItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNoMedia>()
        let songs = try await service.fetchAll(.music, groupingType: .album)

        #expect(songs.count == 0)
    }

    @Test func testFetchAll_Albums_NoItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNoMedia>()
        let albums = try await service.fetchAllCollections(.music, groupingType: .album)

        #expect(albums.count == 0)
    }

    @Test func testFetchAll_TwoItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithFewMedia>()
        let songs = try await service.fetchAll(.music, groupingType: .album)

        #expect(songs.count == 2)
    }

    @Test func testFetchAll_Albums_TwoItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithFewMedia>()
        let albums = try await service.fetchCollections(.music, with: .title("Title"), comparisonType: .contains, groupingType: .album)

        #expect(albums.count == 2)
    }

    @Test func testFetch_MediaTypePredicateAlwaysUsesEqualTo() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryCapturingPredicates>()

        _ = try await service.fetch(
            .music,
            with: .artist("Taylor Swift"),
            comparisonType: .contains,
            groupingType: .album
        )

        let typePredicate = MockMediaQueryCapturingPredicates.propertyPredicate(forProperty: MPMediaItemPropertyMediaType)
        let artistPredicate = MockMediaQueryCapturingPredicates.propertyPredicate(forProperty: MPMediaItemPropertyArtist)

        #expect(typePredicate?.comparisonType == .equalTo)
        #expect(artistPredicate?.comparisonType == .contains)
    }

    @Test func testFetch_NoItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNoMedia>()

        let songs = try await service.fetch(
            .music,
            with: .title("Title"),
            comparisonType: .equalTo,
            groupingType: .album
        )

        #expect(songs.count == 0)
    }

    @Test func testFetch_TwoItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithFewMedia>()

        let songs = try await service.fetch(
            .music,
            with: .title("Title"),
            comparisonType: .equalTo,
            groupingType: .album
        )

        #expect(songs.count == 2)
    }

    // Nil query results are reported as empty arrays, not errors

    @Test func testFetch_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let items = try await service.fetch(
            .music,
            with: .title("Title"),
            comparisonType: .equalTo,
            groupingType: .album
        )

        #expect(items.isEmpty)
    }

    @Test func testFetchAll_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let items = try await service.fetchAll(.music, groupingType: .album)

        #expect(items.isEmpty)
    }

    @Test func testFetchAll_Albums_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let collections = try await service.fetchAllCollections(.music, groupingType: .album)

        #expect(collections.isEmpty)
    }

    @Test func testFetch_Album_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let collections = try await service.fetchCollections(
            .music,
            with: .title("Title"),
            comparisonType: .contains,
            groupingType: .album
        )

        #expect(collections.isEmpty)
    }
}
