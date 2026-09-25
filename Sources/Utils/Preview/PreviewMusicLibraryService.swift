import MediaPlayer

#if DEBUG
    // Ignores the request's media type: preview data is assumed to be of the type asked for.
    final class PreviewMusicLibraryService: MusicLibraryServiceProtocol, @unchecked Sendable {
        let songs: [MPMediaItem]
        let albums: [MPMediaItemCollection]
        let artists: [MPMediaItemCollection]
        private let lock = NSLock()
        private var storedPlaylists: [MPMediaPlaylist]
        private var created: [UUID: PreviewPlaylist] = [:]

        init(songs: [MPMediaItem], albums: [MPMediaItemCollection], artists: [MPMediaItemCollection], playlists: [MPMediaPlaylist]) {
            self.songs = songs
            self.albums = albums
            self.artists = artists
            self.storedPlaylists = playlists
        }

        var playlists: [MPMediaPlaylist] { lock.withLock { storedPlaylists } }

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

        func playlist(id: UUID, creating metadata: PlaylistMetadata?) async throws -> MPMediaPlaylist? {
            lock.withLock {
                if let existing = created[id] { return existing }
                guard let metadata else { return nil }
                let playlist = PreviewPlaylist(id: id, metadata: metadata)
                created[id] = playlist
                storedPlaylists.append(playlist)
                return playlist
            }
        }

        func add(_ items: [MPMediaItem], to playlist: MPMediaPlaylist) async throws {
            (playlist as? PreviewPlaylist)?.append(items)
        }

        func addItem(productID: String) async throws -> [MPMediaEntity] {
            songs(withStoreID: productID)
        }

        func add(productID: String, to playlist: MPMediaPlaylist) async throws {
            (playlist as? PreviewPlaylist)?.append(songs(withStoreID: productID))
        }

        private func songs(withStoreID productID: String) -> [MPMediaItem] {
            songs.filter { $0.value(forProperty: MPMediaItemPropertyPlaybackStoreID) as? String == productID }
        }
    }

    final class PreviewPlaylist: MPMediaPlaylist, @unchecked Sendable {
        private let values: [String: Any]
        private let lock = NSLock()
        private var storedItems: [MPMediaItem] = []

        init(id: UUID, metadata: PlaylistMetadata) {
            let persistentID = withUnsafeBytes(of: id.uuid) { $0.load(as: UInt64.self) }
            var values: [String: Any] = [
                MPMediaPlaylistPropertyPersistentID: NSNumber(value: persistentID),
                MPMediaPlaylistPropertyName: metadata.name,
                MPMediaPlaylistPropertyPlaylistAttributes: NSNumber(value: MPMediaPlaylistAttribute.onTheGo.rawValue),
            ]
            values[MPMediaPlaylistPropertyDescriptionText] = metadata.descriptionText
            values[MPMediaPlaylistPropertyAuthorDisplayName] = metadata.authorDisplayName
            self.values = values
            super.init(items: [])
        }

        required init?(coder: NSCoder) { nil }

        override var items: [MPMediaItem] { lock.withLock { storedItems } }
        override var count: Int { items.count }
        override var representativeItem: MPMediaItem? { items.first }

        override func value(forProperty property: String) -> Any? { values[property] }

        func append(_ items: [MPMediaItem]) {
            lock.withLock { storedItems += items }
        }
    }
#endif
