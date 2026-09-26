import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Previews")
struct PreviewTests {

    @Suite("Given a preview library with songs")
    struct Songs {
        let library: MusicLibrary = .preview(songs: [
            StubMediaItem.song("Hello", by: "Adele", plays: 5),
            StubMediaItem.song("Yesterday", by: "The Beatles", plays: 9),
            StubMediaItem.song("Help!", by: "The Beatles", plays: 2),
        ])

        @Test("When sorted by play count in reverse, then the real sorting runs")
        func sorts() async throws {
            let songs = try await library.fetch(Song.query.sorted(by: \.playCount, .reverse))
            #expect(songs.map(\.title) == ["Yesterday", "Hello", "Help!"])
        }

        @Test("When filtering by artist, then only that artist's songs come back")
        func filtersEqualTo() async throws {
            let songs = try await library.fetch(Song.query.filter(\.artist, .equals("The Beatles")))
            #expect(songs.map(\.title) == ["Yesterday", "Help!"])
        }

        @Test("When filtering a title with contains, then the match ignores case")
        func filtersContains() async throws {
            let songs = try await library.fetch(Song.query.filter(\.title, .contains("HEL")))
            #expect(songs.map(\.title) == ["Hello", "Help!"])
        }

        @Test("When fetched unsorted, then the given order is kept")
        func keepsOrder() async throws {
            let songs = try await library.fetch(Song.query)
            #expect(songs.map(\.title) == ["Hello", "Yesterday", "Help!"])
        }

        @Test("When fetching artists without giving any, then the songs are grouped by artist")
        func derivesArtists() async throws {
            let artists = try await library.fetch(Artist.query)
            #expect(artists.map(\.name) == ["Adele", "The Beatles"])
            #expect(artists.map(\.songCount) == [1, 2])
        }

        @Test("When fetching genres, then the songs are grouped by genre")
        func derivesGenres() async throws {
            let library: MusicLibrary = .preview(songs: [
                StubMediaItem([MPMediaItemPropertyTitle: "A", MPMediaItemPropertyGenre: "Rock"]),
                StubMediaItem([MPMediaItemPropertyTitle: "B", MPMediaItemPropertyGenre: "Jazz"]),
                StubMediaItem([MPMediaItemPropertyTitle: "C", MPMediaItemPropertyGenre: "Rock"]),
            ])

            let genres = try await library.fetch(Genre.query)

            #expect(genres.map(\.name) == ["Rock", "Jazz"])
            #expect(genres.first?.songs.map(\.title) == ["A", "C"])
        }
    }

    @Suite("Given a preview library with collections")
    struct Collections {
        @Test("When fetching albums, artists and playlists, then each returns its own collections")
        func eachKind() async throws {
            let album = MPMediaItemCollection(items: [StubMediaItem.song("A")])
            let artist = MPMediaItemCollection(items: [StubMediaItem.song("B")])
            let playlist = MPMediaPlaylist(items: [])
            let library: MusicLibrary = .preview(albums: [album], artists: [artist], playlists: [playlist])

            #expect(try await library.fetch(Album.query).map { ObjectIdentifier($0.mediaCollection) } == [ObjectIdentifier(album)])
            #expect(try await library.fetch(Artist.query).map { ObjectIdentifier($0.mediaCollection) } == [ObjectIdentifier(artist)])
            #expect(try await library.fetch(Playlist.query).map { ObjectIdentifier($0.mediaPlaylist) } == [ObjectIdentifier(playlist)])
        }

        @Test("When filtering albums by artist, then an album matches if any of its songs does")
        func filtersCollectionsByItems() async throws {
            let adele = MPMediaItemCollection(items: [StubMediaItem.song("Hello", by: "Adele")])
            let beatles = MPMediaItemCollection(items: [StubMediaItem.song("Help!", by: "The Beatles")])
            let library: MusicLibrary = .preview(albums: [adele, beatles])

            let albums = try await library.collections(MediaQueryRequest(mediaType: .music, filter: .init(.artist("Adele")), grouping: .album))

            #expect(albums.map(ObjectIdentifier.init) == [ObjectIdentifier(adele)])
        }
    }

    @Suite("Given a preset authorization state")
    struct Authorization {
        @Test("When access is denied, then fetching throws unauthorized(.denied)")
        func denied() async {
            let library: MusicLibrary = .accessDenied
            #expect(library.authorizationStatus == .denied)
            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) { _ = try await library.fetch(Song.query) }
        }

        @Test("When access is restricted, then fetching throws unauthorized(.restricted)")
        func restricted() async {
            let library: MusicLibrary = .accessRestricted
            await #expect(throws: AuthorizationManagerError.unauthorized(.restricted)) { _ = try await library.fetch(Song.query) }
        }

        @Test("When access is authorized, then fetching succeeds")
        func authorized() async throws {
            let library: MusicLibrary = .accessAuthorized
            #expect(try await library.fetch(Song.query).isEmpty)
        }

        @Test("When the request grants access, then the status becomes authorized")
        func grantedAfterRequest() async throws {
            let library: MusicLibrary = .preview(authStatus: .notDetermined, authStatusAfterRequest: .authorized)
            #expect(library.authorizationStatus == .notDetermined)

            try await library.requestAuthorization()

            #expect(library.authorizationStatus == .authorized)
        }

        @Test("When the request is refused, then requestAuthorization throws like the live manager")
        func refusedAfterRequest() async {
            let library: MusicLibrary = .accessDeniedAfterRequest
            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) {
                try await library.requestAuthorization()
            }
        }
    }
}
