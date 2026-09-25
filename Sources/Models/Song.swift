import Foundation
import MediaPlayer

/// A song in the user's music library.
///
/// `Song` wraps its `MPMediaItem` without copying anything: wrapping a whole library reads no
/// properties, and each property is fetched from the media library only when you access it.
///
/// ```swift
/// let songs = try await library.fetch(Song.query.sorted(by: \.playCount, .reverse).limit(25))
/// for song in songs {
///     print(song.title ?? "Untitled", song.playCount)
/// }
/// ```
public struct Song: Identifiable, Hashable, @unchecked Sendable {
    /// The underlying media item, for APIs such as `MPMusicPlayerController` that need it.
    public let mediaItem: MPMediaItem

    public init(_ mediaItem: MPMediaItem) {
        self.mediaItem = mediaItem
    }

    public var id: MPMediaEntityPersistentID { reader.number(MPMediaItemPropertyPersistentID)?.uint64Value ?? 0 }

    public var title: String? { reader.value(MPMediaItemPropertyTitle) }
    public var artist: String? { reader.value(MPMediaItemPropertyArtist) }
    public var albumTitle: String? { reader.value(MPMediaItemPropertyAlbumTitle) }
    public var albumArtist: String? { reader.value(MPMediaItemPropertyAlbumArtist) }
    public var genre: String? { reader.value(MPMediaItemPropertyGenre) }
    public var composer: String? { reader.value(MPMediaItemPropertyComposer) }

    public var playCount: Int { reader.number(MPMediaItemPropertyPlayCount)?.intValue ?? 0 }
    public var skipCount: Int { reader.number(MPMediaItemPropertySkipCount)?.intValue ?? 0 }
    /// The user's rating, from 0 (unrated) to 5.
    public var rating: Int { reader.number(MPMediaItemPropertyRating)?.intValue ?? 0 }
    /// The playback duration in seconds.
    public var duration: TimeInterval { reader.number(MPMediaItemPropertyPlaybackDuration)?.doubleValue ?? 0 }

    public var releaseDate: Date? { reader.value(MPMediaItemPropertyReleaseDate) }
    public var dateAdded: Date? { reader.value(MPMediaItemPropertyDateAdded) }
    public var lastPlayedDate: Date? { reader.value(MPMediaItemPropertyLastPlayedDate) }

    public var isExplicit: Bool { reader.number(MPMediaItemPropertyIsExplicit)?.boolValue ?? false }
    public var isCloudItem: Bool { reader.number(MPMediaItemPropertyIsCloudItem)?.boolValue ?? false }
    public var hasProtectedAsset: Bool { reader.number(MPMediaItemPropertyHasProtectedAsset)?.boolValue ?? false }
    public var isCompilation: Bool { reader.number(MPMediaItemPropertyIsCompilation)?.boolValue ?? false }

    public var albumID: MPMediaEntityPersistentID { reader.number(MPMediaItemPropertyAlbumPersistentID)?.uint64Value ?? 0 }
    public var artistID: MPMediaEntityPersistentID { reader.number(MPMediaItemPropertyArtistPersistentID)?.uint64Value ?? 0 }

    public static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private var reader: EntityReader { EntityReader(mediaItem) }
}

extension Song: LibraryElement {
    public static var baseRequest: MediaQueryRequest { MediaQueryRequest(mediaType: .music, grouping: .title) }

    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws -> [Song] {
        try await library.items(request).map(Song.init)
    }

    public static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo? {
        switch (keyPath, value) {
        case (\Song.title, let value as String): .title(value)
        case (\Song.artist, let value as String): .artist(value)
        case (\Song.albumTitle, let value as String): .albumTitle(value)
        case (\Song.albumArtist, let value as String): .albumArtist(value)
        case (\Song.genre, let value as String): .genre(value)
        case (\Song.composer, let value as String): .composer(value)
        case (\Song.playCount, let value as Int): .playCount(value)
        case (\Song.isCloudItem, let value as Bool): .isCloudItem(value)
        case (\Song.hasProtectedAsset, let value as Bool): .hasProtectedAsset(value)
        case (\Song.isCompilation, let value as Bool): .isCompilation(value)
        case (\Song.id, let value as UInt64): .persistentID(value)
        case (\Song.albumID, let value as UInt64): .albumID(value)
        case (\Song.artistID, let value as UInt64): .artistID(value)
        default: nil
        }
    }
}
