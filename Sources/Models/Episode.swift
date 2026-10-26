import Foundation
import MediaPlayer

/// A podcast episode in the user's library.
///
/// Like ``Song``, an `Episode` wraps its `MPMediaItem` and reads each property only when you
/// access it. It adds what episodes need: ``bookmarkTime``, ``progress`` and ``isInProgress`` to
/// show where someone stopped.
///
/// ```swift
/// @MediaQuery(.episodes.filter(\.podcastTitle == "Radiolab").sorted(by: \.releaseDate, .reverse)) var episodes
///
/// List(episodes) { episode in
///     VStack(alignment: .leading) {
///         Text(episode.title ?? "")
///         if let progress = episode.progress, episode.isInProgress {
///             ProgressView(value: progress)
///         }
///     }
/// }
/// ```
///
/// MediaPlayer returns only episodes it holds in the music library. Episodes that only the
/// Podcasts app keeps may not appear.
public struct Episode: Identifiable, Hashable, ResumableItem, @unchecked Sendable {
    /// The underlying media item, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaItem: MPMediaItem

    public init(_ mediaItem: MPMediaItem) {
        self.mediaItem = mediaItem
    }

    public var id: MPMediaEntityPersistentID { reader.number(MPMediaItemPropertyPersistentID)?.uint64Value ?? 0 }

    public var title: String? { reader.value(MPMediaItemPropertyTitle) }
    public var podcastTitle: String? { reader.value(MPMediaItemPropertyPodcastTitle) }
    public var podcastID: MPMediaEntityPersistentID { reader.number(MPMediaItemPropertyPodcastPersistentID)?.uint64Value ?? 0 }
    public var comments: String? { reader.value(MPMediaItemPropertyComments) }

    public var releaseDate: Date? { reader.value(MPMediaItemPropertyReleaseDate) }
    public var dateAdded: Date? { reader.value(MPMediaItemPropertyDateAdded) }
    public var lastPlayedDate: Date? { reader.value(MPMediaItemPropertyLastPlayedDate) }

    public var duration: TimeInterval { reader.number(MPMediaItemPropertyPlaybackDuration)?.doubleValue ?? 0 }
    public var bookmarkTime: TimeInterval { reader.number(MPMediaItemPropertyBookmarkTime)?.doubleValue ?? 0 }
    public var playCount: Int { reader.number(MPMediaItemPropertyPlayCount)?.intValue ?? 0 }
    public var isCloudItem: Bool { reader.number(MPMediaItemPropertyIsCloudItem)?.boolValue ?? false }

    /// The episode as a ``Song``, for `ArtworkImage` and the queue helpers.
    public var song: Song { Song(mediaItem) }

    public static func == (lhs: Episode, rhs: Episode) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var reader: EntityReader { EntityReader(mediaItem) }
}

extension Episode: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .podcast, grouping: .title) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [Episode] {
        try await library.items(request).map(Episode.init)
    }

    public static func fetchSections(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [MediaSection<Episode>] {
        try await library.itemSections(request).map { MediaSection(title: $0.title, elements: $0.elements.map(Episode.init)) }
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Episode.title, let value as String): .title(value)
        case (\Episode.podcastTitle, let value as String): .podcastTitle(value)
        case (\Episode.podcastID, let value as UInt64): .podcastID(value)
        case (\Episode.playCount, let value as Int): .playCount(value)
        case (\Episode.isCloudItem, let value as Bool): .isCloudItem(value)
        case (\Episode.id, let value as UInt64): .persistentID(value)
        default: nil
        }
    }
}
