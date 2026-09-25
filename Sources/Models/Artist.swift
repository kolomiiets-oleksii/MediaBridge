import Foundation
import MediaPlayer

/// An artist in the user's music library, with the songs credited to them.
public struct Artist: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying collection, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaCollection: MPMediaItemCollection

    public init(_ mediaCollection: MPMediaItemCollection) {
        self.mediaCollection = mediaCollection
    }

    public var id: MPMediaEntityPersistentID { representative.number(MPMediaItemPropertyArtistPersistentID)?.uint64Value ?? 0 }
    public var name: String? { representative.value(MPMediaItemPropertyArtist) }
    public var songCount: Int { mediaCollection.count }
    public var songs: [Song] { mediaCollection.items.map(Song.init) }

    public static func == (lhs: Artist, rhs: Artist) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var representative: EntityReader { EntityReader(mediaCollection.representativeItem) }
}

extension Artist: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .music, grouping: .artist) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws -> [Artist] {
        try await library.collections(request).map(Artist.init)
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Artist.name, let value as String): .artist(value)
        case (\Artist.id, let value as UInt64): .artistID(value)
        default: nil
        }
    }
}
