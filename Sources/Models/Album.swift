import Foundation
import MediaPlayer

/// An album in the user's music library.
///
/// Like ``Song``, an `Album` wraps its `MPMediaItemCollection` without copying: properties are
/// read from the collection's representative song when you access them.
public struct Album: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying collection, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaCollection: MPMediaItemCollection

    public init(_ mediaCollection: MPMediaItemCollection) {
        self.mediaCollection = mediaCollection
    }

    public var id: MPMediaEntityPersistentID { representative.number(MPMediaItemPropertyAlbumPersistentID)?.uint64Value ?? 0 }
    public var title: String? { representative.value(MPMediaItemPropertyAlbumTitle) }
    public var artist: String? { representative.value(MPMediaItemPropertyAlbumArtist) }
    public var genre: String? { representative.value(MPMediaItemPropertyGenre) }
    public var releaseDate: Date? { representative.value(MPMediaItemPropertyReleaseDate) }
    public var isCompilation: Bool { representative.number(MPMediaItemPropertyIsCompilation)?.boolValue ?? false }
    public var songCount: Int { mediaCollection.count }
    public var songs: [Song] { mediaCollection.items.map(Song.init) }

    public static func == (lhs: Album, rhs: Album) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var representative: EntityReader { EntityReader(mediaCollection.representativeItem) }
}

extension Album: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .music, grouping: .album) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws -> [Album] {
        try await library.collections(request).map(Album.init)
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Album.title, let value as String): .albumTitle(value)
        case (\Album.artist, let value as String): .albumArtist(value)
        case (\Album.genre, let value as String): .genre(value)
        case (\Album.isCompilation, let value as Bool): .isCompilation(value)
        case (\Album.id, let value as UInt64): .albumID(value)
        default: nil
        }
    }
}
