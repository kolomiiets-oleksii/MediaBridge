import Foundation
import MediaPlayer

#if DEBUG
    extension MusicLibraryProtocol where Self == MusicLibrary {
        public static var accessDenied: MusicLibrary { .preview(authStatus: .denied, authStatusAfterRequest: .denied) }
        public static var accessRestricted: MusicLibrary {
            .preview(authStatus: .restricted, authStatusAfterRequest: .restricted)
        }
        public static var accessNotDetermined: MusicLibrary { .preview(authStatus: .notDetermined) }
        public static var accessAuthorized: MusicLibrary { .preview() }

        public static var accessDeniedAfterRequest: MusicLibrary {
            .preview(authStatus: .denied, authStatusAfterRequest: .denied)
        }
        public static var accessRestrictedAfterRequest: MusicLibrary {
            .preview(authStatus: .denied, authStatusAfterRequest: .restricted)
        }
        public static var accessNotDeterminedAfterRequest: MusicLibrary {
            .preview(authStatus: .denied, authStatusAfterRequest: .notDetermined)
        }
        public static var accessAuthorizedAfterRequest: MusicLibrary { .preview(authStatus: .denied) }

        /// A ``MusicLibrary`` for SwiftUI previews, backed by fixed data instead of the device library.
        ///
        /// Sorting, filtering, and the authorization flow run through the real ``MusicLibrary``;
        /// predicates are evaluated in memory, comparing strings case-insensitively.
        ///
        /// ```swift
        /// #Preview {
        ///     ContentView()
        ///         .environment(\.library, .preview(songs: previewSongs))
        /// }
        /// ```
        ///
        /// - Parameters:
        ///   - authStatus: The status before ``MusicLibrary/requestAuthorization()`` is called
        ///   - authStatusAfterRequest: The status a request ends in; anything but `.authorized` throws
        ///   - songs: Items returned by song and item queries
        ///   - albums: Collections returned for album grouping
        ///   - artists: Collections returned for artist grouping
        ///   - playlists: Playlists returned by playlist queries
        public static func preview(
            authStatus: MPMediaLibraryAuthorizationStatus = .authorized,
            authStatusAfterRequest: MPMediaLibraryAuthorizationStatus = .authorized,
            songs: [MPMediaItem] = [],
            albums: [MPMediaItemCollection] = [],
            artists: [MPMediaItemCollection] = [],
            playlists: [MPMediaPlaylist] = []
        ) -> MusicLibrary {
            MusicLibrary(
                auth: PreviewAuthorizationManager(status: authStatus, statusAfterRequest: authStatusAfterRequest),
                service: PreviewMusicLibraryService(songs: songs, albums: albums, artists: artists, playlists: playlists)
            )
        }

        @available(*, deprecated, message: "Use preview(authStatus:authStatusAfterRequest:songs:albums:artists:playlists:)")
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
        ) -> MusicLibrary {
            .preview(
                authStatus: authStatus,
                authStatusAfterRequest: authStatusAfterRequest,
                songs: uniqued(fetchedAllMedia + fetchedMedia + fetchedSongs + filteredSongs),
                albums: filteredAlbums,
                artists: filteredArtists,
                playlists: filteredPlaylists
            )
        }

        private static func uniqued(_ items: [MPMediaItem]) -> [MPMediaItem] {
            var seen = Set<ObjectIdentifier>()
            return items.filter { seen.insert(ObjectIdentifier($0)).inserted }
        }
    }
#endif
