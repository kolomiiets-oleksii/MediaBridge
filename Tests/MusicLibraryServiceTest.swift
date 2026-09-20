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

    // Failing

    @Test func testFetch_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let predicateInfo = MediaItemPredicateInfo.title("Title")
        let expectedError = MusicLibraryService<MockMediaQueryWithNilMedia>.E.noItemFound(predicateInfo)

        await #expect(throws: expectedError) {
            let _ = try await service.fetch(
                .music,
                with: predicateInfo,
                comparisonType: .equalTo,
                groupingType: .album
            )
        }
    }

    @Test func testFetchAll_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let expectedError = MusicLibraryService<MockMediaQueryWithNilMedia>.E.noItemsFound

        await #expect(throws: expectedError) {
            let _ = try await service.fetchAll(.music, groupingType: .album)
        }
    }

    @Test func testFetchAll_Albums_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let expectedError = MusicLibraryService<MockMediaQueryWithNilMedia>.E.noCollectionsFound

        await #expect(throws: expectedError) {
            let _ = try await service.fetchAllCollections(.music, groupingType: .album)
        }
    }

    @Test func testFetch_Album_NilItems() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let predicateInfo = MediaItemPredicateInfo.title("Title")
        let expectedError = MusicLibraryService<MockMediaQueryWithNilMedia>.E.noCollectionFound(predicateInfo)

        await #expect(throws: expectedError) {
            let _ = try await service.fetchCollections(.music, with: .title("Title"), comparisonType: .contains, groupingType: .album)
        }
    }
}
