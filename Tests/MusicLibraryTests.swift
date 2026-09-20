import Testing
import MediaPlayer

@testable import MediaBridge

@Suite("MusicLibrary")
class MusicLibraryTests {
    @Test func testFetchSongs() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let songs = try await library.songs()
        #expect(songs.isEmpty)
    }

    @Test func testFetchSortedSongs() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let songs = try await library.songs(sortedBy: \MPMediaItem.skipCount, order: .forward)
        #expect(songs.isEmpty)
    }

    @Test func testFetchByExplicitSongs() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let songs = try await library.songs(sortedBy: \MPMediaItem.isExplicitItem, order: .forward)
        #expect(songs.isEmpty)
    }

    @Test func testFetchByDateAddedSongs() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let songs = try await library.songs(sortedBy: \MPMediaItem.releaseDate, order: .forward)
        #expect(songs.isEmpty)
    }

    @Test func testFetchAlbums() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let albums = try await library.albums(matching: .title(""), .equalTo, groupingType: .album)
        #expect(albums.isEmpty)
    }

    @Test func testFetchAlbums_SortedByCount() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let albums = try await library.albums(sortedBy: \MPMediaItemCollection.count, order: .forward)
        #expect(albums.isEmpty)
    }

    @Test func testFetchAlbums_SortedByCountReverse() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let albums = try await library.albums(sortedBy: \MPMediaItemCollection.count, order: .reverse)
        #expect(albums.isEmpty)
    }

    @Test func testFetchAlbums_Unsorted() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let albums = try await library.albums()
        #expect(albums.isEmpty)
    }

    // Failures

    @Test func testSongs_Unauthorized() async throws {
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: false, authError: .mockError, authStatus: .denied)
        )
        #expect(library.authorizationStatus == .denied)
        await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) {
            let _ = try await library.songs()
        }
    }

    @Test func testSongs_AuthFail() async throws {
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: false, authError: .mockError, authStatus: .denied)
        )
        #expect(library.authorizationStatus == .denied)
        await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) {
            let _ = try await library.songs()
        }
    }

    @Test func testSongs_StatusDenied() async throws {
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: false, authError: .mockError, authStatus: .denied)
        )
        #expect(library.authorizationStatus == .denied)
        await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) {
            let _ = try await library.songs()
        }
    }

    @Test func testFetchSongs_FailingService() async throws {
        let service = MockMusicLibraryService(fetchSongsError: .noSongs)
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: true, authStatus: .denied),
            mockService: service
        )
        #expect(library.authorizationStatus == .denied)
        await #expect(throws: MockMusicLibraryService.MockError.noSongs) {
            let _ = try await library.songs()
        }
    }

    @Test func testFetchSong_Failure() async throws {
        let service = MockMusicLibraryService(fetchSongError: .noSong)
        let library = MusicLibrary(mockService: service)
        #expect(library.authorizationStatus == .authorized)

        await #expect(throws: MockMusicLibraryService.MockError.noSong) {
            let _ = try await library.songs(matching: .mock, comparisonType: .equalTo)
        }
    }

    @Test func testFetchAlbums_FailingService() async throws {
        let service = MockMusicLibraryService(fetchAlbumsError: .noAlbums)
        let library = MusicLibrary(mockService: service)
        #expect(library.authorizationStatus == .authorized)

        await #expect(throws: MockMusicLibraryService.MockError.noAlbums) {
            let _ = try await library.albums(sortedBy: (KeyPath<MPMediaItemCollection, Never> & Sendable)?.none, order: .forward)
        }
    }

    @Test func testFetchAlbums_MatchingPredicate_Failure() async throws {
        let service = MockMusicLibraryService(albumsError: .noAlbum)
        let library = MusicLibrary(mockService: service)
        #expect(library.authorizationStatus == .authorized)

        await #expect(throws: MockMusicLibraryService.MockError.noAlbum) {
            let _ = try await library.albums(
                matching: .albumArtist("Test Artist"),
                .equalTo,
                groupingType: .album
            )
        }
    }

    @Test func testAlbums_Unauthorized() async throws {
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: false, authError: .mockError, authStatus: .denied)
        )
        #expect(library.authorizationStatus == .denied)

        await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) {
            let _ = try await library.albums(sortedBy: (KeyPath<MPMediaItemCollection, Never> & Sendable)?.none, order: .forward)
        }
    }

    // MARK: - Artists

    @Test func testFetchArtists() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let artists = try await library.artists()
        #expect(artists.isEmpty)
    }

    @Test func testFetchArtists_SortedByCount() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let artists = try await library.artists(sortedBy: \MPMediaItemCollection.count, order: .reverse)
        #expect(artists.isEmpty)
    }

    @Test func testFetchArtists_Unsorted() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let artists = try await library.artists(sortedBy: (KeyPath<MPMediaItemCollection, Never> & Sendable)?.none, order: .forward)
        #expect(artists.isEmpty)
    }

    @Test func testFetchArtists_Matching() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let artists = try await library.artists(matching: .artist("The Beatles"), .contains, groupingType: .artist)
        #expect(artists.isEmpty)
    }

    @Test func testFetchArtists_FailingService() async throws {
        let service = MockMusicLibraryService(fetchArtistsError: .noArtists)
        let library = MusicLibrary(mockService: service)
        #expect(library.authorizationStatus == .authorized)

        await #expect(throws: MockMusicLibraryService.MockError.noArtists) {
            let _ = try await library.artists()
        }
    }

    @Test func testFetchArtists_MatchingPredicate_Failure() async throws {
        let service = MockMusicLibraryService(artistsError: .noArtist)
        let library = MusicLibrary(mockService: service)
        #expect(library.authorizationStatus == .authorized)

        await #expect(throws: MockMusicLibraryService.MockError.noArtist) {
            let _ = try await library.artists(matching: .artist("Unknown"), .equalTo, groupingType: .artist)
        }
    }

    @Test func testArtists_Unauthorized() async throws {
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: false, authError: .mockError, authStatus: .denied)
        )
        #expect(library.authorizationStatus == .denied)

        await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) {
            let _ = try await library.artists()
        }
    }

    // MARK: - Playlists

    @Test func testFetchPlaylists() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let playlists = try await library.playlists()
        #expect(playlists.isEmpty)
    }

    @Test func testFetchPlaylists_SortedByID() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let playlists = try await library.playlists(sortedBy: \MPMediaPlaylist.persistentID, order: .forward)
        #expect(playlists.isEmpty)
    }

    @Test func testFetchPlaylists_Unsorted() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let playlists = try await library.playlists(sortedBy: (KeyPath<MPMediaPlaylist, Never> & Sendable)?.none, order: .forward)
        #expect(playlists.isEmpty)
    }

    @Test func testFetchPlaylists_MatchingByName() async throws {
        let library = MusicLibrary.withMocks
        #expect(library.authorizationStatus == .authorized)
        let playlists = try await library.playlists(matching: .playlistName("Favorites"), .contains)
        #expect(playlists.isEmpty)
    }

    @Test func testFetchPlaylists_FailingService() async throws {
        let service = MockMusicLibraryService(fetchPlaylistsError: .noPlaylists)
        let library = MusicLibrary(mockService: service)
        #expect(library.authorizationStatus == .authorized)

        await #expect(throws: MockMusicLibraryService.MockError.noPlaylists) {
            let _ = try await library.playlists()
        }
    }

    @Test func testFetchPlaylists_MatchingPredicate_Failure() async throws {
        let service = MockMusicLibraryService(playlistsError: .noPlaylist)
        let library = MusicLibrary(mockService: service)
        #expect(library.authorizationStatus == .authorized)

        await #expect(throws: MockMusicLibraryService.MockError.noPlaylist) {
            let _ = try await library.playlists(matching: .playlistName("Unknown"), .equalTo)
        }
    }

    @Test func testPlaylists_Unauthorized() async throws {
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: false, authError: .mockError, authStatus: .denied)
        )
        #expect(library.authorizationStatus == .denied)

        await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) {
            let _ = try await library.playlists()
        }
    }

    @Test func testFetch_WhenRequestReturnsDeniedWithoutThrowing() async throws {
        let library = MusicLibrary(
            mockAuth: .mock(isAuthorized: false, authStatus: .denied)
        )
        #expect(library.authorizationStatus == .denied)

        await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) {
            let _ = try await library.songs()
        }
    }
}

private extension MusicLibrary {
    convenience init(
        mockAuth: any AuthorizationManagerProtocol = .mock,
        mockService: any MusicLibraryServiceProtocol = .mock
    ) {
        self.init(auth: mockAuth, service: mockService)
    }

    static var withMocks: MusicLibrary { MusicLibrary(mockAuth: .mock) }
}


extension MediaItemPredicateInfo {
    static var mock: Self {
        MediaItemPredicateInfo.persistentID(21)
    }
}
