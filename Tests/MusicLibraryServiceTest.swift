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

    // MARK: - Playlists

    @Test func testFetchAllPlaylists_NilCollections() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let playlists = try await service.fetchAllPlaylists()

        #expect(playlists.isEmpty)
    }

    @Test func testFetchAllPlaylists_SkipsNonPlaylistCollections() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNonPlaylistCollections>()

        let playlists = try await service.fetchAllPlaylists()

        #expect(playlists.isEmpty)
    }

    @Test func testFetchAllPlaylists_UsesPlaylistGrouping() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryCapturingPredicates>()

        _ = try await service.fetchAllPlaylists()

        #expect(MockMediaQueryCapturingPredicates.lastGroupingType == .playlist)
        #expect(MockMediaQueryCapturingPredicates.lastFilterPredicates == nil)
    }

    @Test func testFetchPlaylists_Matching_PassesPredicateAndGrouping() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryCapturingPredicates>()

        _ = try await service.fetchPlaylists(with: .playlistName("Chill"), comparisonType: .contains)

        let namePredicate = MockMediaQueryCapturingPredicates.propertyPredicate(forProperty: MPMediaPlaylistPropertyName)

        #expect(namePredicate?.comparisonType == .contains)
        #expect(MockMediaQueryCapturingPredicates.lastGroupingType == .playlist)
    }

    @Test func testFetchPlaylists_Matching_NilCollections() async throws {
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithNilMedia>()

        let playlists = try await service.fetchPlaylists(with: .playlistName("Chill"), comparisonType: .equalTo)

        #expect(playlists.isEmpty)
    }

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
