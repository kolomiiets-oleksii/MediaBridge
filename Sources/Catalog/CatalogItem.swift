import Foundation

/// The kind of thing an Apple Music catalog result is.
public enum CatalogKind: String, Sendable, CaseIterable {
    case song
    case album
    case artist
    case playlist
    case musicVideo
    case station
    /// The next three come back only in top results; a request can't ask for them.
    case curator
    case radioShow
    case recordLabel

    /// Whether ``CatalogSearchRequest/kinds`` may contain this kind.
    public var isSearchable: Bool {
        switch self {
        case .song, .album, .artist, .playlist, .musicVideo, .station: true
        case .curator, .radioShow, .recordLabel: false
        }
    }

    /// Whether a store queue can play items of this kind.
    var isPlayableInStoreQueue: Bool {
        switch self {
        case .song, .album, .playlist: true
        default: false
        }
    }
}

/// One Apple Music catalog result.
///
/// MusicKit's types don't have public initialisers, so ``CatalogSearching`` implementations hand
/// back this plain value instead. ``id`` is the catalog (store) ID, the value
/// ``MusicLibraryProtocol/add(productID:)`` and ``MusicPlayerProtocol/setQueue(withStoreIDs:)`` take.
public struct CatalogItem: Sendable, Hashable, Identifiable {
    /// The catalog ID.
    public let id: String
    public let kind: CatalogKind
    public let title: String
    /// The artist, or for playlists the curator, for radio shows the host. `nil` where there is none.
    public let artistName: String?
    /// The item's page on Apple Music.
    public let url: URL?
    /// Artwork at 512 × 512 points, when the item has artwork.
    public let artworkURL: URL?

    /// The catalog ID, named for what the player and library calls call it.
    public var storeID: String { id }

    public init(
        id: String,
        kind: CatalogKind,
        title: String,
        artistName: String? = nil,
        url: URL? = nil,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.artistName = artistName
        self.url = url
        self.artworkURL = artworkURL
    }
}
