#if canImport(MusicKit)
    import Foundation
    // The only file that imports MusicKit: its Song, Album, Artist, Playlist and Genre share names
    // with MediaBridge's models, so every MusicKit type below is written MusicKit.X.
    import MusicKit

    /// Searches the Apple Music catalog with MusicKit.
    ///
    /// Your app needs the MusicKit App Service enabled for its App ID in the developer portal, and
    /// `NSAppleMusicUsageDescription` in Info.plist. The first search asks for access if the person
    /// hasn't decided yet; later searches don't prompt. Music videos need iOS 15.4 and are left out
    /// before that.
    public struct MusicKitCatalog: CatalogSearching {
        private static let artworkSize = 512

        public init() {}

        public func search(_ request: CatalogSearchRequest) async throws(CatalogError) -> [CatalogItem] {
            var status = MusicAuthorization.currentStatus
            if status == .notDetermined { status = await MusicAuthorization.request() }
            guard status == .authorized else { throw .notAuthorized }

            let types = request.kinds.compactMap(Self.searchableType)
            guard !types.isEmpty else { return [] }  // only music videos asked for, before iOS 15.4

            var search = MusicCatalogSearchRequest(term: request.term, types: types)
            search.limit = request.limit
            search.offset = request.offset
            if request.includesTopResults, #available(iOS 16.0, *) { search.includeTopResults = true }

            let response: MusicCatalogSearchResponse
            do { response = try await search.response() } catch { throw .underlying(error) }

            var items: [CatalogItem] = []
            if request.includesTopResults, #available(iOS 16.0, *) {
                items += response.topResults.compactMap(Self.item(from:))
            }
            items += response.songs.map { Self.make($0.id, .song, $0.title, $0.artistName, $0.url, $0.artwork) }
            items += response.albums.map { Self.make($0.id, .album, $0.title, $0.artistName, $0.url, $0.artwork) }
            items += response.artists.map { Self.make($0.id, .artist, $0.name, nil, $0.url, $0.artwork) }
            items += response.playlists.map { Self.make($0.id, .playlist, $0.name, $0.curatorName, $0.url, $0.artwork) }
            if #available(iOS 15.4, *) {
                items += response.musicVideos.map { Self.make($0.id, .musicVideo, $0.title, $0.artistName, $0.url, $0.artwork) }
            }
            items += response.stations.map { Self.make($0.id, .station, $0.name, nil, $0.url, $0.artwork) }

            var seen = Set<String>()
            return items.filter { seen.insert("\($0.kind.rawValue):\($0.id)").inserted }
        }

        private static func searchableType(_ kind: CatalogKind) -> (any MusicCatalogSearchable.Type)? {
            switch kind {
            case .song: MusicKit.Song.self
            case .album: MusicKit.Album.self
            case .artist: MusicKit.Artist.self
            case .playlist: MusicKit.Playlist.self
            case .musicVideo:
                if #available(iOS 15.4, *) { MusicKit.MusicVideo.self } else { nil }
            case .station: MusicKit.Station.self
            case .curator, .radioShow, .recordLabel: nil
            }
        }

        private static func make(
            _ id: MusicItemID,
            _ kind: CatalogKind,
            _ title: String,
            _ artistName: String?,
            _ url: URL?,
            _ artwork: MusicKit.Artwork?
        ) -> CatalogItem {
            CatalogItem(
                id: id.rawValue,
                kind: kind,
                title: title,
                artistName: artistName,
                url: url,
                artworkURL: artwork?.url(width: artworkSize, height: artworkSize)
            )
        }

        @available(iOS 16.0, *)
        private static func item(from result: MusicCatalogSearchResponse.TopResult) -> CatalogItem? {
            switch result {
            case .song(let x): make(x.id, .song, x.title, x.artistName, x.url, x.artwork)
            case .album(let x): make(x.id, .album, x.title, x.artistName, x.url, x.artwork)
            case .artist(let x): make(x.id, .artist, x.name, nil, x.url, x.artwork)
            case .playlist(let x): make(x.id, .playlist, x.name, x.curatorName, x.url, x.artwork)
            case .musicVideo(let x): make(x.id, .musicVideo, x.title, x.artistName, x.url, x.artwork)
            case .station(let x): make(x.id, .station, x.name, nil, x.url, x.artwork)
            case .curator(let x): make(x.id, .curator, x.name, nil, x.url, x.artwork)
            case .radioShow(let x): make(x.id, .radioShow, x.name, x.hostName, x.url, x.artwork)
            case .recordLabel(let x): make(x.id, .recordLabel, x.name, nil, x.url, x.artwork)
            @unknown default: nil
            }
        }
    }
#endif
