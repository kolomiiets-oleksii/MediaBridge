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
        let captures = QueryCaptures()
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryCapturingPredicates>()

        try await MockMediaQueryCapturingPredicates.$captures.withValue(captures) {
            _ = try await service.fetch(
                .music,
                with: .artist("Taylor Swift"),
                comparisonType: .contains,
                groupingType: .album
            )
        }

        #expect(captures.propertyPredicate(forProperty: MPMediaItemPropertyMediaType)?.comparisonType == .equalTo)
        #expect(captures.propertyPredicate(forProperty: MPMediaItemPropertyArtist)?.comparisonType == .contains)
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
        let captures = QueryCaptures()
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryCapturingPredicates>()

        try await MockMediaQueryCapturingPredicates.$captures.withValue(captures) {
            _ = try await service.fetchAllPlaylists()
        }

        #expect(captures.groupingType == .playlist)
        #expect(captures.filterPredicates == nil)
    }

    @Test func testFetchPlaylists_Matching_PassesPredicateAndGrouping() async throws {
        let captures = QueryCaptures()
        let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryCapturingPredicates>()

        try await MockMediaQueryCapturingPredicates.$captures.withValue(captures) {
            _ = try await service.fetchPlaylists(with: .playlistName("Chill"), comparisonType: .contains)
        }

        #expect(captures.propertyPredicate(forProperty: MPMediaPlaylistPropertyName)?.comparisonType == .contains)
        #expect(captures.groupingType == .playlist)
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
