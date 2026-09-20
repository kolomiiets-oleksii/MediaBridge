import MediaBridge
import MediaPlayer

final class MockMusicLibraryService: MusicLibraryServiceProtocol {
    typealias Q = MPMediaQuery

    enum MockError: Error {
        case noSong, noSongs, noAlbum, noAlbums, noArtist, noArtists, noPlaylist, noPlaylists
    }

    init(
        fetchSongError: MockError? = nil,
        fetchSongsError: MockError? = nil,
        songs: [MPMediaItem] = [.mock],
        albums: [MPMediaItemCollection] = [.mock],
        albumsError: MockError? = nil,
        fetchAlbumsError: MockError? = nil,
        artists: [MPMediaItemCollection] = [.mock],
        artistsError: MockError? = nil,
        fetchArtistsError: MockError? = nil,
        playlists: [MPMediaPlaylist] = [],
        playlistsError: MockError? = nil,
        fetchPlaylistsError: MockError? = nil
    ) {
        self.fetchSongError = fetchSongError
        self.fetchSongsError = fetchSongsError
        self.songs = songs
        self.albums = albums
        self.albumsError = albumsError
        self.fetchAlbumsError = fetchAlbumsError
        self.artists = artists
        self.artistsError = artistsError
        self.fetchArtistsError = fetchArtistsError
        self.playlists = playlists
        self.playlistsError = playlistsError
        self.fetchPlaylistsError = fetchPlaylistsError
    }

    let fetchSongsError: MockError?
    func fetchAll(_ type: MPMediaType, groupingType: MPMediaGrouping) async throws(MockError) -> [MPMediaItem] {
        guard let fetchSongsError = fetchSongsError else { return [] }
        throw fetchSongsError
    }

    let songs: [MPMediaItem]
    let fetchSongError: MockError?
    func fetch(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws(MockError) -> [MPMediaItem] {
        guard let fetchSongError = fetchSongError else { return songs }
        throw fetchSongError
    }

    let albums: [MPMediaItemCollection]
    let albumsError: MockError?
    let artists: [MPMediaItemCollection]
    let artistsError: MockError?
    func fetchCollections(
        _ type: MPMediaType,
        with predicate: MediaBridge.MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection] {
        if groupingType == .artist {
            guard let artistsError = artistsError else { return artists }
            throw artistsError
        }
        guard let albumsError = albumsError else { return albums }
        throw albumsError
    }

    let fetchAlbumsError: MockError?
    let fetchArtistsError: MockError?
    func fetchAllCollections(_ type: MPMediaType, groupingType: MPMediaGrouping) async throws -> [MPMediaItemCollection] {
        if groupingType == .artist {
            guard let fetchArtistsError = fetchArtistsError else { return [] }
            throw fetchArtistsError
        }
        guard let fetchAlbumsError = fetchAlbumsError else { return [] }
        throw fetchAlbumsError
    }

    let playlists: [MPMediaPlaylist]
    let fetchPlaylistsError: MockError?
    func fetchAllPlaylists() async throws(MockError) -> [MPMediaPlaylist] {
        guard let fetchPlaylistsError = fetchPlaylistsError else { return playlists }
        throw fetchPlaylistsError
    }

    let playlistsError: MockError?
    func fetchPlaylists(
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison
    ) async throws(MockError) -> [MPMediaPlaylist] {
        guard let playlistsError = playlistsError else { return playlists }
        throw playlistsError
    }
}

extension MusicLibraryServiceProtocol where Self == MockMusicLibraryService {
    static var mock: MockMusicLibraryService {
        MockMusicLibraryService(albums: [], artists: [], playlists: [])
    }
}

extension MPMediaItem: @unchecked @retroactive Sendable {}
extension MPMediaItem {
    static var mock: MPMediaItem { MPMediaItem() }
}

extension MPMediaItemCollection: @unchecked @retroactive Sendable {}
extension MPMediaItemCollection {
    static var mock: MPMediaItemCollection { MPMediaItemCollection(items: []) }
}
