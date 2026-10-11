import Foundation
import MediaPlayer

/// An audiobook in the user's library.
///
/// Like ``Song``, an `Audiobook` wraps its `MPMediaItem` and reads each property only when you
/// access it, and adds ``bookmarkTime``, ``progress`` and ``isInProgress`` for resuming.
///
/// ```swift
/// @MediaQuery(.books.sorted(by: \.lastPlayedDate, .reverse)) var books
/// ```
///
/// MediaPlayer returns only audiobooks it holds in the music library. Books that only the Books
/// app keeps may not appear.
public struct Audiobook: Identifiable, Hashable, ResumableItem, @unchecked Sendable {
    /// The underlying media item, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaItem: MPMediaItem

    public init(_ mediaItem: MPMediaItem) {
        self.mediaItem = mediaItem
    }

    public var id: MPMediaEntityPersistentID { reader.number(MPMediaItemPropertyPersistentID)?.uint64Value ?? 0 }

    public var title: String? { reader.value(MPMediaItemPropertyTitle) }
    /// The author, which audiobooks store as the artist.
    public var author: String? { reader.value(MPMediaItemPropertyArtist) }
    public var albumTitle: String? { reader.value(MPMediaItemPropertyAlbumTitle) }
    public var genre: String? { reader.value(MPMediaItemPropertyGenre) }

    public var releaseDate: Date? { reader.value(MPMediaItemPropertyReleaseDate) }
    public var dateAdded: Date? { reader.value(MPMediaItemPropertyDateAdded) }
    public var lastPlayedDate: Date? { reader.value(MPMediaItemPropertyLastPlayedDate) }

    public var duration: TimeInterval { reader.number(MPMediaItemPropertyPlaybackDuration)?.doubleValue ?? 0 }
    public var bookmarkTime: TimeInterval { reader.number(MPMediaItemPropertyBookmarkTime)?.doubleValue ?? 0 }
    public var playCount: Int { reader.number(MPMediaItemPropertyPlayCount)?.intValue ?? 0 }
    public var isCloudItem: Bool { reader.number(MPMediaItemPropertyIsCloudItem)?.boolValue ?? false }

    /// The audiobook as a ``Song``, for `ArtworkImage` and the queue helpers.
    public var song: Song { Song(mediaItem) }

    public static func == (lhs: Audiobook, rhs: Audiobook) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var reader: EntityReader { EntityReader(mediaItem) }
}

extension Audiobook: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .audioBook, grouping: .title) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [Audiobook] {
        try await library.items(request).map(Audiobook.init)
    }

    public static func fetchSections(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [MediaSection<Audiobook>] {
        try await library.itemSections(request).map { MediaSection(title: $0.title, elements: $0.elements.map(Audiobook.init)) }
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Audiobook.title, let value as String): .title(value)
        case (\Audiobook.author, let value as String): .artist(value)
        case (\Audiobook.albumTitle, let value as String): .albumTitle(value)
        case (\Audiobook.genre, let value as String): .genre(value)
        case (\Audiobook.playCount, let value as Int): .playCount(value)
        case (\Audiobook.isCloudItem, let value as Bool): .isCloudItem(value)
        case (\Audiobook.id, let value as UInt64): .persistentID(value)
        default: nil
        }
    }
}
