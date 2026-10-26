import MediaBridge
import MediaPlayer
import SwiftUI

/// A full player built from public API only: progress without polling, seeking, repeat, shuffle,
/// and an Up Next list that can be edited on an `applicationQueuePlayer`.
struct PlayerView: View {
    @NowPlaying private var song
    @Environment(\.musicPlayer) private var player

    var body: some View {
        NavigationStack {
            List {
                if let song {
                    Section {
                        VStack(spacing: 16) {
                            ArtworkImage(song, size: 220, cornerRadius: 16)
                            VStack(spacing: 4) {
                                Text(song.title ?? "Unknown").font(.title2.bold())
                                Text(song.artist ?? "").foregroundStyle(.secondary)
                            }
                            progress(for: song)
                            controls
                        }
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    }

                    Section("Up Next") {
                        if $song.upNext.isEmpty {
                            Text($song.queueIndex == nil ? "This player doesn't report its queue." : "Nothing after this song.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach($song.upNext) { next in
                            SongRow(song: next)
                        }
                        .onDelete(perform: removeUpNext)
                    }
                } else {
                    ContentUnavailableView("Nothing Playing", systemImage: "music.note", description: Text("Tap a song to play it."))
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // `TimelineView` asks for the position twice a second; the player is never polled.
    private func progress(for song: Song) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let time = $song.position.time(at: context.date, clampedTo: song.duration)
            VStack(spacing: 4) {
                Slider(value: Binding(get: { time }, set: { $song.seek(to: $0) }), in: 0...max(song.duration, 1))
                HStack {
                    Text(Duration.seconds(time), format: .time(pattern: .minuteSecond))
                    Spacer()
                    Text(Duration.seconds(song.duration), format: .time(pattern: .minuteSecond))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 32) {
            Button("Shuffle", systemImage: "shuffle") {
                $song.setShuffleMode($song.shuffleMode == .off ? .songs : .off)
            }
            .tint($song.shuffleMode == .off ? .secondary : .accentColor)

            Button("Previous", systemImage: "backward.fill") { player.skipToPreviousItem() }

            Button($song.isPlaying ? "Pause" : "Play", systemImage: $song.isPlaying ? "pause.fill" : "play.fill") {
                $song.isPlaying ? player.pause() : player.play()
            }
            .font(.title)

            Button("Next", systemImage: "forward.fill") { player.skipToNextItem() }

            Button("Repeat", systemImage: $song.repeatMode == .one ? "repeat.1" : "repeat") {
                $song.setRepeatMode(nextRepeatMode(after: $song.repeatMode))
            }
            .tint($song.repeatMode == .none ? .secondary : .accentColor)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func nextRepeatMode(after mode: MPMusicRepeatMode) -> MPMusicRepeatMode {
        switch mode {
        case .none, .default: .all
        case .all: .one
        default: .none
        }
    }

    private func removeUpNext(at offsets: IndexSet) {
        guard let queuePlayer = player as? MPMusicPlayerApplicationController else { return }
        let removed = offsets.map { $song.upNext[$0] }
        Task { try? await queuePlayer.removeFromQueue(removed) }
    }
}

#if DEBUG
#Preview("Playing") {
    PlayerView()
        .musicPlayer(.preview(queue: DemoSongs.all, state: .playing))
}
#endif
