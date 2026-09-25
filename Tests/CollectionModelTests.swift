import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Collection models")
struct CollectionModelTests {

    static func album(_ title: String, by artist: String, songs: Int = 1, id: UInt64 = 1) -> MPMediaItemCollection {
        MPMediaItemCollection(
            items: (0..<songs).map { _ in
                StubMediaItem([
                    MPMediaItemPropertyAlbumTitle: title,
                    MPMediaItemPropertyAlbumArtist: artist,
                    MPMediaItemPropertyArtist: artist,
                    MPMediaItemPropertyGenre: "Rock",
                    MPMediaItemPropertyAlbumPersistentID: NSNumber(value: id),
                    MPMediaItemPropertyArtistPersistentID: NSNumber(value: id + 100),
                    MPMediaItemPropertyGenrePersistentID: NSNumber(value: id + 200),
                ])
            })
    }

    @Suite("Given collections from the library")
    struct Properties {
        @Test("When wrapped as an Album, then it reads through its representative song")
        func album() {
            let album = Album(CollectionModelTests.album("Help!", by: "The Beatles", songs: 3, id: 9))

            #expect(album.id == 9)
            #expect(album.title == "Help!")
            #expect(album.artist == "The Beatles")
            #expect(album.genre == "Rock")
            #expect(album.songCount == 3)
            #expect(album.songs.count == 3)
        }

        @Test("When wrapped as an Artist or Genre, then name and ID come from the representative song")
        func artistAndGenre() {
            let collection = CollectionModelTests.album("Help!", by: "The Beatles", id: 1)

            #expect(Artist(collection).name == "The Beatles")
            #expect(Artist(collection).id == 101)
            #expect(Genre(collection).name == "Rock")
            #expect(Genre(collection).id == 201)
        }

        @Test("When wrapped as a Playlist, then its name and kind read from the playlist")
        func playlist() {
            let playlist = Playlist(StubPlaylist(name: "Road Trip", attributes: [.smart, .onTheGo]))

            #expect(playlist.name == "Road Trip")
            #expect(playlist.isSmart)
            #expect(playlist.isOnTheGo)
            #expect(!playlist.isGenius)
        }

        @Test("When 1,000 albums are wrapped, then no song property is read")
        func zeroCopy() {
            let items = (0..<1_000).map { _ in StubMediaItem([MPMediaItemPropertyAlbumTitle: "A"]) }
            let albums = items.map { MPMediaItemCollection(items: [$0]) }.map(Album.init)

            #expect(albums.count == 1_000)
            #expect(items.allSatisfy { $0.reads.isEmpty })
        }
    }

    @Suite("Given collection queries")
    struct Queries {
        @Test("When filtering albums by artist, then MediaPlayer filters by album artist")
        func albumPushdown() async throws {
            let service = MockMusicLibraryService()
            _ = try await MusicLibrary(auth: .mock, service: service).fetch(Album.query.filter(\.artist, .equals("Adele")))

            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filters: [.init(.albumArtist("Adele"))], grouping: .album)
                ])
        }

        @Test("When sorting albums by song count, then the biggest comes first")
        func albumSort() async throws {
            let service = MockMusicLibraryService(collections: [
                .album: [CollectionModelTests.album("Small", by: "X", songs: 1), CollectionModelTests.album("Big", by: "Y", songs: 4)],
            ])
            let albums = try await MusicLibrary(auth: .mock, service: service)
                .fetch(Album.query.sorted(by: \.songCount, .reverse))

            #expect(albums.map(\.title) == ["Big", "Small"])
        }

        @Test("When querying artists and genres, then each uses its grouping")
        func groupings() async throws {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock, service: service)
            _ = try await library.fetch(Artist.query.filter(\.name, .contains("beat")))
            _ = try await library.fetch(Genre.query)

            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filters: [.init(.artist("beat"), .contains)], grouping: .artist),
                    MediaQueryRequest(mediaType: .music, grouping: .genre),
                ])
        }

        @Test("When querying playlists, then any media type is allowed and non-playlists are dropped")
        func playlists() async throws {
            let service = MockMusicLibraryService(collections: [.playlist: [.mock, StubPlaylist(name: "Chill", attributes: [])]])
            let playlists = try await MusicLibrary(auth: .mock, service: service)
                .fetch(Playlist.query.filter(\.name, .equals("Chill")))

            #expect(service.requests == [MediaQueryRequest(filters: [.init(.playlistName("Chill"))], grouping: .playlist)])
            #expect(playlists.map(\.name) == ["Chill"])
        }
    }
}

final class StubPlaylist: MPMediaPlaylist, @unchecked Sendable {
    private let values: [String: Any]
    private let lock = NSLock()
    private var addedItems: [MPMediaItem] = []

    var added: [MPMediaItem] { lock.withLock { addedItems } }

    init(name: String, attributes: MPMediaPlaylistAttribute) {
        values = [
            MPMediaPlaylistPropertyName: name,
            MPMediaPlaylistPropertyPlaylistAttributes: NSNumber(value: attributes.rawValue),
        ]
        super.init(items: [])
    }

    required init?(coder: NSCoder) { nil }

    override func value(forProperty property: String) -> Any? { values[property] }

    override func add(_ mediaItems: [MPMediaItem], completionHandler: ((Error?) -> Void)? = nil) {
        lock.withLock { addedItems += mediaItems }
        completionHandler?(nil)
    }
}
