import Foundation
import MediaPlayer

/// Media that remembers where you stopped, such as a podcast episode or an audiobook.
///
/// ``Song``, ``Episode`` and ``Audiobook`` conform, so progress code works on any of them.
public protocol ResumableItem {
    /// The underlying media item.
    var mediaItem: MPMediaItem { get }
    /// The length in seconds.
    var duration: TimeInterval { get }
    /// Where playback stopped last time, in seconds; 0 when there is no bookmark.
    var bookmarkTime: TimeInterval { get }
    var playCount: Int { get }
}

extension ResumableItem {
    /// How far through the item the bookmark is, from 0 to 1, or `nil` when the length is unknown.
    public var progress: Double? {
        duration > 0 ? min(max(bookmarkTime / duration, 0), 1) : nil
    }

    /// Whether the bookmark is somewhere inside the item: started and not finished.
    ///
    /// Derived from the bookmark and the length. MediaPlayer has no "has been played" property;
    /// ``isPlayed`` is the nearest thing.
    public var isInProgress: Bool {
        bookmarkTime > 0 && (duration <= 0 || bookmarkTime < duration)
    }

    /// Whether the item has been played at least once, by its play count.
    public var isPlayed: Bool { playCount > 0 }
}

extension Song: ResumableItem {}
