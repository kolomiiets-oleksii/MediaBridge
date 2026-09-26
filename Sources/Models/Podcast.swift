import Foundation
import MediaPlayer

/// A podcast in the user's library, with its downloaded episodes.
///
/// To list episodes across podcasts, query ``Song`` with `.mediaType(.podcast)`.
public struct Podcast: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying collection, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaCollection: MPMediaItemCollection

    public init(_ mediaCollection: MPMediaItemCollection) {
        self.mediaCollection = mediaCollection
    }

    public var id: MPMediaEntityPersistentID { representative.number(MPMediaItemPropertyPodcastPersistentID)?.uint64Value ?? 0 }
    public var title: String? { representative.value(MPMediaItemPropertyPodcastTitle) }
    public var episodeCount: Int { mediaCollection.count }
    public var episodes: [Song] { mediaCollection.items.map(Song.init) }

    public static func == (lhs: Podcast, rhs: Podcast) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var representative: EntityReader { EntityReader(mediaCollection.representativeItem) }
}

extension Podcast: CollectionElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .podcast, grouping: .podcastTitle) }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Podcast.title, let value as String): .podcastTitle(value)
        case (\Podcast.id, let value as UInt64): .podcastID(value)
        default: nil
        }
    }
}
