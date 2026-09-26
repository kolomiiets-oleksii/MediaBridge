import Combine
import MediaPlayer

@MainActor
final class NowPlayingLoader: ObservableObject {
    @Published private(set) var song: Song?
    @Published private(set) var playbackState: MPMusicPlaybackState = .stopped

    private var player: (any MusicPlayerProtocol)?
    private var observation: AnyCancellable?

    func update(player: any MusicPlayerProtocol) {
        guard player !== self.player else { return }
        observation = nil
        self.player = player
        refresh()
        observation = observe(player)
    }

    private func observe(_ player: any MusicPlayerProtocol) -> AnyCancellable {
        let center = NotificationCenter.default
        let (changes, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let names: [Notification.Name] = [.MPMusicPlayerControllerNowPlayingItemDidChange, .MPMusicPlayerControllerPlaybackStateDidChange]
        let observers = names.map { name in
            center.addObserver(forName: name, object: player, queue: nil) { _ in continuation.yield() }
        }
        player.beginGeneratingPlaybackNotifications()
        let task = Task { [weak self] in
            for await _ in changes {
                self?.refresh()
            }
        }
        return AnyCancellable {
            observers.forEach(center.removeObserver)
            continuation.finish()
            task.cancel()
            player.endGeneratingPlaybackNotifications()
        }
    }

    private func refresh() {
        let song = player?.nowPlayingSong
        if song?.mediaItem !== self.song?.mediaItem { self.song = song }
        let state = player?.playbackState ?? .stopped
        if state != playbackState { playbackState = state }
    }
}
