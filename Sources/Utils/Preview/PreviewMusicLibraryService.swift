import MediaPlayer

#if DEBUG
    // Ignores the request's media type: preview data is assumed to be of the type asked for.
    struct PreviewMusicLibraryService: MusicLibraryServiceProtocol, @unchecked Sendable {
        let songs: [MPMediaItem]
        let albums: [MPMediaItemCollection]
        let artists: [MPMediaItemCollection]
        let playlists: [MPMediaPlaylist]

        func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] {
            guard let filter = request.filter else { return songs }
            return songs.filter { filter.predicate.matches($0, using: filter.comparison) }
        }

        func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] {
            let collections: [MPMediaItemCollection] =
                switch request.grouping {
                case .album, .albumArtist: albums
                case .artist: artists
                case .playlist: playlists
                default: []
                }
            guard let filter = request.filter else { return collections }
            return collections.filter { collection in
                filter.predicate.matches(collection, using: filter.comparison)
                    || collection.items.contains { filter.predicate.matches($0, using: filter.comparison) }
            }
        }
    }
#endif
