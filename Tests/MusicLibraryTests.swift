import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("MusicLibrary")
struct MusicLibraryTests {

    @Suite("Given access is authorized, when fetching")
    struct Requests {
        let service = MockMusicLibraryService()
        var library: MusicLibrary { MusicLibrary(auth: .mock, service: service) }

        @Test("songs, then it asks for music items grouped by title")
        func songs() async throws {
            _ = try await library.fetch(Song.query)
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .title)])
        }

        @Test("albums, then it asks for music collections grouped by album")
        func albums() async throws {
            _ = try await library.fetch(Album.query)
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .album)])
        }

        @Test("artists, then it asks for music collections grouped by artist")
        func artists() async throws {
            _ = try await library.fetch(Artist.query)
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .artist)])
        }

        @Test("genres, then it asks for music collections grouped by genre")
        func genres() async throws {
            _ = try await library.fetch(Genre.query)
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .genre)])
        }

        @Test("playlists, then it asks for playlist collections of any media type")
        func playlists() async throws {
            _ = try await library.fetch(Playlist.query)
            #expect(service.requests == [MediaQueryRequest(grouping: .playlist)])
        }

        @Test("a custom request, then it reaches the service unchanged")
        func customRequest() async throws {
            let request = MediaQueryRequest(mediaType: .anyAudio, filter: .init(.genre("Jazz")), grouping: .albumArtist)
            _ = try await library.collections(request)
            _ = try await library.items(request)
            #expect(service.requests == [request, request])
        }
    }

    @Suite("Given the service returns results")
    struct Results {
        @Test("When songs are sorted by a Bool key path forward, then false comes first")
        func sortsByFlag() async throws {
            let service = MockMusicLibraryService(items: [
                StubMediaItem.song("Explicit", explicit: true), StubMediaItem.song("Clean"),
            ])

            let songs = try await MusicLibrary(auth: .mock, service: service).fetch(Song.query.sorted(by: \.isExplicit))

            #expect(songs.map(\.title) == ["Clean", "Explicit"])
        }

        @Test("When songs are sorted by an optional key path, then missing values come first")
        func sortsOptionals() async throws {
            let service = MockMusicLibraryService(items: [
                StubMediaItem.song("Beta"), StubMediaItem([MPMediaItemPropertyArtist: "Untitled"]), StubMediaItem.song("Alpha"),
            ])

            let songs = try await MusicLibrary(auth: .mock, service: service).fetch(Song.query.sorted(by: \.title))

            #expect(songs.map(\.title) == [nil, "Alpha", "Beta"])
        }

        @Test("When playlists are fetched, then collections that aren't playlists are dropped")
        func dropsNonPlaylists() async throws {
            let playlist = MPMediaPlaylist(items: [])
            let service = MockMusicLibraryService(collections: [.playlist: [.mock, playlist, .mock]])

            let playlists = try await MusicLibrary(auth: .mock, service: service).fetch(Playlist.query)

            #expect(playlists.map { ObjectIdentifier($0.mediaPlaylist) } == [ObjectIdentifier(playlist)])
        }
    }

    @Suite("Given the service fails")
    struct ServiceFailure {
        let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(error: .failed))

        @Test("When fetching songs, then the service error reaches the caller")
        func songs() async {
            await #expect(throws: MockMusicLibraryService.MockError.failed) { _ = try await library.fetch(Song.query) }
        }

        @Test("When fetching album sections, then the service error reaches the caller")
        func albums() async {
            await #expect(throws: MockMusicLibraryService.MockError.failed) { _ = try await library.sections(Album.query) }
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
            await #expect(throws: MockAuthorizationManager.MockAuthError.mockError) { _ = try await library.fetch(Song.query) }
            #expect(service.requests.isEmpty)
        }

        @Test("When the request ends denied without throwing, then unauthorized(.denied) is thrown")
        func requestDenied() async {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: service)

            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) { _ = try await library.fetch(Playlist.query) }
            #expect(service.requests.isEmpty)
        }

        @Test("When the request grants access, then the fetch goes ahead")
        func requestGrants() async throws {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: true, authStatus: .notDetermined), service: service)

            _ = try await library.fetch(Album.query)

            #expect(service.requests.count == 1)
        }
    }
}
