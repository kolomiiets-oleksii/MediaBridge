import Foundation
import MediaPlayer

#if DEBUG
    extension MusicLibraryProtocol where Self == PreviewMusicLibrary {
        public static var accessDenied: PreviewMusicLibrary { .preview(authStatus: .denied) }
        public static var accessRestricted: PreviewMusicLibrary { .preview(authStatus: .restricted) }
        public static var accessNotDetermined: PreviewMusicLibrary { .preview(authStatus: .notDetermined) }
        public static var accessAuthorized: PreviewMusicLibrary { .preview() }

        public static var accessDeniedAfterRequest: PreviewMusicLibrary {
            .preview(authStatus: .denied, authStatusAfterRequest: .denied)
        }
        public static var accessRestrictedAfterRequest: PreviewMusicLibrary {
            .preview(authStatus: .denied, authStatusAfterRequest: .restricted)
        }
        public static var accessNotDeterminedAfterRequest: PreviewMusicLibrary {
            .preview(authStatus: .denied, authStatusAfterRequest: .notDetermined)
        }
        public static var accessAuthorizedAfterRequest: PreviewMusicLibrary { .preview(authStatus: .denied) }

        public static func preview(
            authStatus: MPMediaLibraryAuthorizationStatus = .authorized,
            authStatusAfterRequest: MPMediaLibraryAuthorizationStatus = .authorized,
            fetchedAllMedia: [MPMediaItem] = [],
            fetchedMedia: [MPMediaItem] = [],
            fetchedSongs: [MPMediaItem] = [],
            filteredSongs: [MPMediaItem] = [],
            filteredAlbums: [MPMediaItemCollection] = [],
            filteredArtists: [MPMediaItemCollection] = [],
            filteredPlaylists: [MPMediaPlaylist] = []
        ) -> PreviewMusicLibrary {
            PreviewMusicLibrary(
                status: authStatus,
                statusAfterRequest: authStatusAfterRequest,
                fetchedAllMedia: fetchedAllMedia,
                fetchedMedia: fetchedMedia,
                fetchedSongs: fetchedSongs,
                filteredSongs: filteredSongs,
                filteredAlbums: filteredAlbums,
                filteredArtists: filteredArtists,
                filteredPlaylists: filteredPlaylists
            )
        }
    }
#endif
