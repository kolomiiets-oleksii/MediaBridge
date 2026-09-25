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

    public var id: MPMediaEntityPersistentID { number(MPMediaItemPropertyPersistentID)?.uint64Value ?? 0 }

    public var title: String? { value(MPMediaItemPropertyTitle) }
    public var artist: String? { value(MPMediaItemPropertyArtist) }
    public var albumTitle: String? { value(MPMediaItemPropertyAlbumTitle) }
    public var albumArtist: String? { value(MPMediaItemPropertyAlbumArtist) }
    public var genre: String? { value(MPMediaItemPropertyGenre) }
    public var composer: String? { value(MPMediaItemPropertyComposer) }

    public var playCount: Int { number(MPMediaItemPropertyPlayCount)?.intValue ?? 0 }
    public var skipCount: Int { number(MPMediaItemPropertySkipCount)?.intValue ?? 0 }
    /// The user's rating, from 0 (unrated) to 5.
    public var rating: Int { number(MPMediaItemPropertyRating)?.intValue ?? 0 }
    /// The playback duration in seconds.
    public var duration: TimeInterval { number(MPMediaItemPropertyPlaybackDuration)?.doubleValue ?? 0 }

    public var releaseDate: Date? { value(MPMediaItemPropertyReleaseDate) }
    public var dateAdded: Date? { value(MPMediaItemPropertyDateAdded) }
    public var lastPlayedDate: Date? { value(MPMediaItemPropertyLastPlayedDate) }

    public var isExplicit: Bool { number(MPMediaItemPropertyIsExplicit)?.boolValue ?? false }
    public var isCloudItem: Bool { number(MPMediaItemPropertyIsCloudItem)?.boolValue ?? false }
    public var hasProtectedAsset: Bool { number(MPMediaItemPropertyHasProtectedAsset)?.boolValue ?? false }
    public var isCompilation: Bool { number(MPMediaItemPropertyIsCompilation)?.boolValue ?? false }

    public var albumID: MPMediaEntityPersistentID { number(MPMediaItemPropertyAlbumPersistentID)?.uint64Value ?? 0 }
    public var artistID: MPMediaEntityPersistentID { number(MPMediaItemPropertyArtistPersistentID)?.uint64Value ?? 0 }

    public static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private func value<T>(_ property: String) -> T? {
        mediaItem.value(forProperty: property) as? T
    }

    private func number(_ property: String) -> NSNumber? {
        mediaItem.value(forProperty: property) as? NSNumber
    }
}
