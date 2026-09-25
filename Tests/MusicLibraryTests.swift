import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("MusicLibrary")
struct MusicLibraryTests {

    // MARK: - Requests sent to the service

    @Suite("Given access is authorized, when fetching")
    struct Requests {
        let service = MockMusicLibraryService()
        var library: MusicLibrary { MusicLibrary(auth: .mock, service: service) }

        @Test("songs(), then it asks for music items grouped by title")
        func songs() async throws {
            _ = try await library.songs()
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .title)])
        }

        @Test("albums(), then it asks for music collections grouped by album")
        func albums() async throws {
            _ = try await library.albums()
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .album)])
        }

        @Test("artists(), then it asks for music collections grouped by artist")
        func artists() async throws {
            _ = try await library.artists()
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .artist)])
        }

        @Test("playlists(), then it asks for playlist collections of any media type")
        func playlists() async throws {
            _ = try await library.playlists()
            #expect(service.requests == [MediaQueryRequest(grouping: .playlist)])
        }

        @Test("songs matching a predicate, then the predicate and comparison are passed through")
        func songsMatching() async throws {
            _ = try await library.songs(matching: .artist("Beatles"), comparisonType: .contains)
            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filter: .init(.artist("Beatles"), .contains), grouping: .title)
                ])
        }

        @Test("albums matching a predicate, then the caller's grouping is kept")
        func albumsMatching() async throws {
            _ = try await library.albums(matching: .genre("Rock"), .equalTo, groupingType: .albumArtist)
            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filter: .init(.genre("Rock"), .equalTo), grouping: .albumArtist)
                ])
        }

        @Test("artists matching a predicate, then the caller's grouping is kept")
        func artistsMatching() async throws {
            _ = try await library.artists(matching: .artist("Beatles"), .contains, groupingType: .artist)
            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filter: .init(.artist("Beatles"), .contains), grouping: .artist)
                ])
        }

        @Test("playlists matching a predicate, then no media type is imposed")
        func playlistsMatching() async throws {
            _ = try await library.playlists(matching: .playlistName("Chill"), .contains)
            #expect(
                service.requests == [
                    MediaQueryRequest(filter: .init(.playlistName("Chill"), .contains), grouping: .playlist)
                ])
        }

        @Test("items of any type, then the media type is passed through")
        func mediaItems() async throws {
            _ = try await library.mediaItems(ofType: .podcast, matching: .title("Daily"), .contains, groupingType: .title)
            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .podcast, filter: .init(.title("Daily"), .contains), grouping: .title)
                ])
        }

        @Test("collections of any type, then the media type is passed through")
        func mediaItemCollections() async throws {
            _ = try await library.mediaItemCollections(
                ofType: .audioBook, matching: .artist("Author"), .equalTo, groupingType: .album)
            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .audioBook, filter: .init(.artist("Author"), .equalTo), grouping: .album)
                ])
        }

        @Test("everything of a type, then no filter is sent")
        func fetchAll() async throws {
            _ = try await library.fetchAll(.audioBook, groupingType: .album)
            #expect(service.requests == [MediaQueryRequest(mediaType: .audioBook, grouping: .album)])
        }
    }

    // MARK: - Results

    @Suite("Given the service returns results")
    struct Results {
        @Test("When songs are sorted by play count in reverse, then the most played comes first")
        func sortsSongs() async throws {
            let service = MockMusicLibraryService(items: [
                StubMediaItem.song("B", plays: 3), StubMediaItem.song("A", plays: 9), StubMediaItem.song("C", plays: 1),
            ])
            let library = MusicLibrary(auth: .mock, service: service)

            let songs = try await library.songs(sortedBy: \MPMediaItem.playCount, order: .reverse)

            #expect(songs.map(\.title) == ["A", "B", "C"])
        }

        @Test("When songs are sorted by a Bool key path forward, then false comes first")
        func sortsByFlag() async throws {
            let service = MockMusicLibraryService(items: [
                StubMediaItem.song("Explicit", explicit: true), StubMediaItem.song("Clean"),
            ])
            let library = MusicLibrary(auth: .mock, service: service)

            let songs = try await library.songs(sortedBy: \MPMediaItem.isExplicitItem, order: .forward)

            #expect(songs.map(\.title) == ["Clean", "Explicit"])
        }

        @Test("When songs are fetched without a sort key, then the service order is kept")
        func keepsOrder() async throws {
            let service = MockMusicLibraryService(items: [StubMediaItem.song("B"), StubMediaItem.song("A")])
            let library = MusicLibrary(auth: .mock, service: service)

            let songs = try await library.songs()

            #expect(songs.map(\.title) == ["B", "A"])
        }

        @Test("When playlists are fetched, then collections that aren't playlists are dropped")
        func dropsNonPlaylists() async throws {
            let playlist = MPMediaPlaylist(items: [])
            let service = MockMusicLibraryService(collections: [.playlist: [.mock, playlist, .mock]])
            let library = MusicLibrary(auth: .mock, service: service)

            let playlists = try await library.playlists()

            #expect(playlists.count == 1)
            #expect(playlists.first === playlist)
        }

        @Test("When matching playlists, then collections that aren't playlists are dropped")
        func dropsNonPlaylistsWhenMatching() async throws {
            let service = MockMusicLibraryService(collections: [.playlist: [.mock, MPMediaPlaylist(items: [])]])
            let library = MusicLibrary(auth: .mock, service: service)

            let playlists = try await library.playlists(matching: .playlistName("Chill"), .contains)

            #expect(playlists.count == 1)
        }
    }

    // MARK: - Failures

    @Suite("Given the service fails")
    struct ServiceFailure {
        let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(error: .failed))

        @Test("When fetching songs, then the service error reaches the caller")
        func songs() async {
            await #expect(throws: MockMusicLibraryService.MockError.failed) { _ = try await library.songs() }
        }

        @Test("When fetching albums, then the service error reaches the caller")
        func albums() async {
            await #expect(throws: MockMusicLibraryService.MockError.failed) { _ = try await library.albums() }
        }

        @Test("When matching artists, then the service error reaches the caller")
        func artists() async {
            await #expect(throws: MockMusicLibraryService.MockError.failed) {
                _ = try await library.artists(matching: .artist("X"), .equalTo, groupingType: .artist)
            }
        }

        @Test("When fetching playlists, then the service error reaches the caller")
        func playlists() async {
            await #expect(throws: MockMusicLibraryService.MockError.failed) { _ = try await library.playlists() }
        }
    }

    @Suite("Given access is not authorized")
    struct Unauthorized {
        @Test("When the authorization request throws, then its error reaches the caller and the service is never queried")
        func requestThrows() async {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(
                auth: .mock(isAuthorized: false, authError: .mockError, authStatus: .denied), service: service)

            #expect(library.authorizationStatus == .denied)
            await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) { _ = try await library.songs() }
            #expect(service.requests.isEmpty)
        }

        @Test("When the request ends denied without throwing, then unauthorized(.denied) is thrown")
        func requestDenied() async {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: service)

            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) { _ = try await library.playlists() }
            #expect(service.requests.isEmpty)
        }

        @Test("When the request grants access, then the fetch goes ahead")
        func requestGrants() async throws {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: true, authStatus: .notDetermined), service: service)

            _ = try await library.albums()

            #expect(service.requests.count == 1)
        }
    }
}
