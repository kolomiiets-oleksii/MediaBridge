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
            let songs = try await library.songs(sortedBy: \MPMediaItem.playCount, order: .reverse)
            #expect(songs.map(\.title) == ["Yesterday", "Hello", "Help!"])
        }

        @Test("When matching an artist with equalTo, then only that artist's songs come back")
        func filtersEqualTo() async throws {
            let songs = try await library.songs(matching: .artist("The Beatles"), comparisonType: .equalTo)
            #expect(songs.map(\.title) == ["Yesterday", "Help!"])
        }

        @Test("When matching a title with contains, then the match ignores case")
        func filtersContains() async throws {
            let songs = try await library.songs(matching: .title("HEL"), comparisonType: .contains)
            #expect(songs.map(\.title) == ["Hello", "Help!"])
        }

        @Test("When fetched unsorted, then the given order is kept")
        func keepsOrder() async throws {
            let songs = try await library.songs()
            #expect(songs.map(\.title) == ["Hello", "Yesterday", "Help!"])
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

            #expect(try await library.albums().map(ObjectIdentifier.init) == [ObjectIdentifier(album)])
            #expect(try await library.artists().map(ObjectIdentifier.init) == [ObjectIdentifier(artist)])
            #expect(try await library.playlists().map(ObjectIdentifier.init) == [ObjectIdentifier(playlist)])
        }

        @Test("When matching albums by artist, then an album matches if any of its songs does")
        func filtersCollectionsByItems() async throws {
            let adele = MPMediaItemCollection(items: [StubMediaItem.song("Hello", by: "Adele")])
            let beatles = MPMediaItemCollection(items: [StubMediaItem.song("Help!", by: "The Beatles")])
            let library: MusicLibrary = .preview(albums: [adele, beatles])

            let albums = try await library.albums(matching: .artist("Adele"), .equalTo, groupingType: .album)

            #expect(albums.map(ObjectIdentifier.init) == [ObjectIdentifier(adele)])
        }
    }

    @Suite("Given a preset authorization state")
    struct Authorization {
        @Test("When access is denied, then fetching throws unauthorized(.denied)")
        func denied() async {
            let library: MusicLibrary = .accessDenied
            #expect(library.authorizationStatus == .denied)
            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) { _ = try await library.songs() }
        }

        @Test("When access is restricted, then fetching throws unauthorized(.restricted)")
        func restricted() async {
            let library: MusicLibrary = .accessRestricted
            await #expect(throws: AuthorizationManagerError.unauthorized(.restricted)) { _ = try await library.songs() }
        }

        @Test("When access is authorized, then fetching succeeds")
        func authorized() async throws {
            let library: MusicLibrary = .accessAuthorized
            #expect(try await library.songs().isEmpty)
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

    @Suite("Given code written against the 0.10 preview API")
    struct Deprecated {
        @Test("When using the old preview parameters, then their songs are still served")
        @available(*, deprecated)
        func oldParameters() async throws {
            let song = StubMediaItem.song("Old")
            let library: MusicLibrary = .preview(fetchedSongs: [song])
            #expect(try await library.songs().map(\.title) == ["Old"])
        }

        @Test("When constructing PreviewMusicLibrary directly, then it still builds a working library")
        @available(*, deprecated)
        func oldInitializer() async throws {
            let library = PreviewMusicLibrary(
                status: .authorized,
                statusAfterRequest: .authorized,
                fetchedAllMedia: [],
                fetchedMedia: [],
                fetchedSongs: [StubMediaItem.song("Old")],
                filteredSongs: [],
                filteredAlbums: []
            )
            #expect(try await library.songs().map(\.title) == ["Old"])
        }
    }
}
