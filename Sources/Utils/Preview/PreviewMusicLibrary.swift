import Foundation
import MediaPlayer

#if DEBUG
    @available(*, deprecated, renamed: "MusicLibrary", message: "Previews are MusicLibrary instances; use MusicLibrary.preview(...)")
    public typealias PreviewMusicLibrary = MusicLibrary

    extension MusicLibrary {
        @available(*, deprecated, message: "Use MusicLibrary.preview(authStatus:authStatusAfterRequest:songs:albums:artists:playlists:)")
        public convenience init(
            status: MPMediaLibraryAuthorizationStatus,
            statusAfterRequest: MPMediaLibraryAuthorizationStatus,
            fetchedAllMedia: [MPMediaItem],
            fetchedMedia: [MPMediaItem],
            fetchedSongs: [MPMediaItem],
            filteredSongs: [MPMediaItem],
            filteredAlbums: [MPMediaItemCollection],
            filteredArtists: [MPMediaItemCollection] = [],
            filteredPlaylists: [MPMediaPlaylist] = []
        ) {
            var seen = Set<ObjectIdentifier>()
            let songs = (fetchedAllMedia + fetchedMedia + fetchedSongs + filteredSongs)
                .filter { seen.insert(ObjectIdentifier($0)).inserted }
            self.init(
                auth: PreviewAuthorizationManager(status: status, statusAfterRequest: statusAfterRequest),
                service: PreviewMusicLibraryService(
                    songs: songs, albums: filteredAlbums, artists: filteredArtists, playlists: filteredPlaylists),
                changes: SilentLibraryChanges()
            )
        }
    }
#endif
