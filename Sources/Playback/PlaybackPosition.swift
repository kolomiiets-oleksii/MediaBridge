import Foundation

/// Where playback was at one moment, and how fast it was moving.
///
/// Compute the position at any later time instead of polling the player. Pair it with
/// `TimelineView` for a progress bar that moves smoothly and invalidates nothing in between:
///
/// ```swift
/// TimelineView(.periodic(from: .now, by: 0.5)) { context in
///     ProgressView(value: $song.position.time(at: context.date), total: song.duration)
/// }
/// ```
///
/// ``NowPlaying`` refreshes it whenever the song or the playback state changes, and after
/// ``NowPlaying/Status/seek(to:)``.
public struct PlaybackPosition: Sendable, Equatable {
    /// Seconds into the song at ``date``.
    public let time: TimeInterval
    /// When `time` was read.
    public let date: Date
    /// How many seconds of the song play per second: `1` while playing, `0` otherwise.
    public let rate: Double

    public init(time: TimeInterval, date: Date = Date(), rate: Double) {
        self.time = time
        self.date = date
        self.rate = rate
    }

    /// A stopped player at the start of nothing.
    public static let zero = PlaybackPosition(time: 0, date: .distantPast, rate: 0)

    /// Seconds into the song at `date`, never before the start or past `duration`.
    ///
    /// - Parameters:
    ///   - date: The moment to compute for, such as a `TimelineView` context's date.
    ///   - duration: The song's length, if you want the result held to it.
    public func time(at date: Date, clampedTo duration: TimeInterval? = nil) -> TimeInterval {
        let elapsed = max(0, date.timeIntervalSince(self.date))
        let moved = time + rate * elapsed
        return min(max(moved, 0), duration ?? .infinity)
    }
}
