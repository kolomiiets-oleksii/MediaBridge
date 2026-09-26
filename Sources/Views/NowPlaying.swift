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

    /// The playback state, as `$song.playbackState` and `$song.isPlaying`.
    public var projectedValue: Status {
        Status(playbackState: loader.playbackState)
    }

    public func update() {
        loader.update(player: player)
    }

    /// The playback state of a ``NowPlaying`` song.
    public struct Status: Sendable {
        /// Whether the player is playing, paused, stopped, interrupted, or seeking.
        public let playbackState: MPMusicPlaybackState

        /// Whether the song is playing now.
        public var isPlaying: Bool { playbackState == .playing }
    }
}
