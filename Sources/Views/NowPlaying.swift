import MediaPlayer
import SwiftUI

/// The song playing on ``SwiftUICore/EnvironmentValues/musicPlayer``, kept current as playback
/// moves on.
///
/// ```swift
/// struct MiniPlayer: View {
///     @NowPlaying var song
///     @Environment(\.musicPlayer) private var player
///
///     var body: some View {
///         if let song {
///             HStack {
///                 ArtworkImage(song, size: 44)
///                 Text(song.title ?? "")
///                 Button($song.isPlaying ? "Pause" : "Play") {
///                     $song.isPlaying ? player.pause() : player.play()
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// A progress bar needs no polling. ``PlaybackPosition`` says where playback was and how fast it
/// moves, and `TimelineView` asks for the position as often as you like:
///
/// ```swift
/// TimelineView(.periodic(from: .now, by: 0.5)) { context in
///     Slider(
///         value: Binding(
///             get: { $song.position.time(at: context.date, clampedTo: song.duration) },
///             set: { $song.seek(to: $0) }),
///         in: 0...song.duration)
/// }
/// ```
@MainActor
@propertyWrapper
public struct NowPlaying: @preconcurrency DynamicProperty {
    @Environment(\.musicPlayer) private var player
    @StateObject private var loader = NowPlayingLoader()

    public init() {}

    /// The song playing now, or `nil` when nothing is.
    public var wrappedValue: Song? {
        loader.song
    }

    /// Playback state, position, repeat and shuffle modes, and the queue, as `$song.isPlaying`,
    /// `$song.position`, and friends.
    public var projectedValue: Status {
        Status(loader: loader)
    }

    public func update() {
        loader.update(player: player)
    }

    /// The playback state of a ``NowPlaying`` song, and controls that keep it current.
    @MainActor
    public struct Status: Sendable {
        private let loader: NowPlayingLoader

        init(loader: NowPlayingLoader) {
            self.loader = loader
        }

        /// Whether the player is playing, paused, stopped, interrupted, or seeking.
        public var playbackState: MPMusicPlaybackState { loader.playbackState }

        /// Whether the song is playing now.
        public var isPlaying: Bool { playbackState == .playing }

        /// Where playback was when the song, the state, or a seek last changed it. Compute progress
        /// from it with ``PlaybackPosition/time(at:clampedTo:)`` inside a `TimelineView`.
        public var position: PlaybackPosition { loader.position }

        /// How the player repeats, as last set on this player.
        ///
        /// MediaPlayer sends no notification when it changes, so a change made by another app shows
        /// up when this app becomes active, or right away if you use ``setRepeatMode(_:)``.
        public var repeatMode: MPMusicRepeatMode { loader.repeatMode }

        /// Whether the player shuffles; see ``repeatMode`` for when it updates.
        public var shuffleMode: MPMusicShuffleMode { loader.shuffleMode }

        /// The songs in the queue, in playing order. Empty unless the player reports its queue,
        /// which only `MPMusicPlayerController.applicationQueuePlayer` does.
        public var queue: [Song] { loader.queue }

        /// The current song's place in ``queue``, or `nil` when the queue isn't known.
        public var queueIndex: Int? { loader.queueIndex }

        /// The songs after the current one in ``queue``, for an Up Next list.
        public var upNext: [Song] {
            guard let queueIndex, queueIndex + 1 < queue.count else { return [] }
            return Array(queue[(queueIndex + 1)...])
        }

        /// Jumps to `time`, in seconds, and refreshes ``position``.
        public func seek(to time: TimeInterval) { loader.seek(to: time) }

        /// Sets how the player repeats and refreshes ``repeatMode``.
        public func setRepeatMode(_ mode: MPMusicRepeatMode) { loader.setRepeatMode(mode) }

        /// Sets whether the player shuffles and refreshes ``shuffleMode``.
        public func setShuffleMode(_ mode: MPMusicShuffleMode) { loader.setShuffleMode(mode) }
    }
}
