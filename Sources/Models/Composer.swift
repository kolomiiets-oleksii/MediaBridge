import Foundation
import MediaPlayer

/// A composer in the user's music library, with the songs credited to them.
public struct Composer: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying collection, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaCollection: MPMediaItemCollection

    public init(_ mediaCollection: MPMediaItemCollection) {
        self.mediaCollection = mediaCollection
    }

    public var id: MPMediaEntityPersistentID { representative.number(MPMediaItemPropertyComposerPersistentID)?.uint64Value ?? 0 }
    public var name: String? { representative.value(MPMediaItemPropertyComposer) }
    public var songCount: Int { mediaCollection.count }
    public var songs: [Song] { mediaCollection.items.map(Song.init) }

    public static func == (lhs: Composer, rhs: Composer) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var representative: EntityReader { EntityReader(mediaCollection.representativeItem) }
}

extension Composer: CollectionElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .music, grouping: .composer) }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Composer.name, let value as String): .composer(value)
        case (\Composer.id, let value as UInt64): .composerID(value)
        default: nil
        }
    }
}
