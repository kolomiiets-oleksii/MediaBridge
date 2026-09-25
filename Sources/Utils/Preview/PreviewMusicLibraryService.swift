import MediaPlayer

#if DEBUG
    // Ignores the request's media type: preview data is assumed to be of the type asked for.
    struct PreviewMusicLibraryService: MusicLibraryServiceProtocol, @unchecked Sendable {
        let songs: [MPMediaItem]
        let albums: [MPMediaItemCollection]
        let artists: [MPMediaItemCollection]
        let playlists: [MPMediaPlaylist]

        func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] {
            songs.filter { song in request.filters.allSatisfy { $0.matches(song) } }
        }

        func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] {
            let collections: [MPMediaItemCollection] =
                switch request.grouping {
                case .album, .albumArtist: albums
                case .artist: artists
                case .playlist: playlists
                default: []
                }
            return collections.filter { collection in
                request.filters.allSatisfy { filter in
                    filter.matches(collection) || collection.items.contains { filter.matches($0) }
                }
            }
        }
    }
#endif
