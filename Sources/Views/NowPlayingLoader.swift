import Combine
import MediaPlayer

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
final class NowPlayingLoader: ObservableObject {
    @Published private(set) var song: Song?
    @Published private(set) var playbackState: MPMusicPlaybackState = .stopped
    @Published private(set) var position = PlaybackPosition.zero
    @Published private(set) var repeatMode: MPMusicRepeatMode = .default
    @Published private(set) var shuffleMode: MPMusicShuffleMode = .default
    @Published private(set) var queue: [Song] = []
    @Published private(set) var queueIndex: Int?

    private var player: (any MusicPlayerProtocol)?
    private var observation: AnyCancellable?
    private var queueTask: Task<Void, Never>?
    private var queueIsKnown = false
    private var queueReadInFlight = false
    private var queueReadFinished = Date.distantPast
    private var queueIDs: [UInt64]?
    private var queueGap: TimeInterval
    private var trailingRead: Task<Void, Never>?
    private let baseQueueGap: TimeInterval
    private let maximumQueueGap: TimeInterval

    /// Reading the queue is a transaction on the player. If a transaction announced itself, each
    /// read would start the next, so reads are spaced out: at least `queueGap` apart, with the gap
    /// doubling (up to `maximumQueueGap`) each time a read finds the queue unchanged and resetting
    /// when it finds a change. A real change is read at once if the gap has passed and after it
    /// otherwise; an echo settles into one read per `maximumQueueGap`.
    init(queueGap: TimeInterval = 0.5, maximumQueueGap: TimeInterval = 30) {
        baseQueueGap = queueGap
        self.queueGap = queueGap
        self.maximumQueueGap = maximumQueueGap
    }

    func update(player: any MusicPlayerProtocol) {
        guard player !== self.player else { return }
        observation = nil
        queueTask?.cancel()
        trailingRead?.cancel()
        self.player = player
        queue = []
        queueIndex = nil
        queueIsKnown = false
        queueReadInFlight = false
        queueReadFinished = .distantPast
        queueIDs = nil
        queueGap = baseQueueGap
        refreshPlayback()
        readQueue()
        observation = observe(player)
    }

    func seek(to time: TimeInterval) {
        player?.currentPlaybackTime = max(0, time)
        refreshPlayback()
    }

    func setRepeatMode(_ mode: MPMusicRepeatMode) {
        player?.repeatMode = mode
        refreshPlayback()
    }

    func setShuffleMode(_ mode: MPMusicShuffleMode) {
        player?.shuffleMode = mode
        refreshPlayback()
    }

    private func observe(_ player: any MusicPlayerProtocol) -> AnyCancellable {
        let center = NotificationCenter.default
        let (playbackChanges, playback) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let (queueChanges, queue) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        var observers: [any NSObjectProtocol] = [
            .MPMusicPlayerControllerNowPlayingItemDidChange, .MPMusicPlayerControllerPlaybackStateDidChange,
        ].map { name in
            center.addObserver(forName: name, object: player, queue: nil) { _ in playback.yield() }
        }
        observers.append(
            center.addObserver(forName: .MPMusicPlayerControllerQueueDidChange, object: player, queue: nil) { _ in queue.yield() })
        #if canImport(UIKit)
            // Repeat and shuffle have no notification, and another app can change them while this one
            // is in the background, so look again when the app comes back.
            observers.append(
                center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
                    playback.yield()
                })
        #endif
        player.beginGeneratingPlaybackNotifications()
        let playbackTask = Task { [weak self] in
            for await _ in playbackChanges {
                self?.refreshPlayback()
            }
        }
        let queueTask = Task { [weak self] in
            for await _ in queueChanges {
                self?.queueDidChange()
            }
        }
        return AnyCancellable {
            observers.forEach(center.removeObserver)
            playback.finish()
            queue.finish()
            playbackTask.cancel()
            queueTask.cancel()
            player.endGeneratingPlaybackNotifications()
        }
    }

    /// Everything that changes with playback. The queue is not read here: that is a transaction on
    /// the player, so it happens once when the player is set and when the queue itself changes.
    private func refreshPlayback() {
        guard let player else { return }
        let song = player.nowPlayingSong
        if song?.mediaItem !== self.song?.mediaItem { self.song = song }
        let state = player.playbackState
        if state != playbackState { playbackState = state }
        position = player.playbackPosition
        if player.repeatMode != repeatMode { repeatMode = player.repeatMode }
        if player.shuffleMode != shuffleMode { shuffleMode = player.shuffleMode }
        if queueIsKnown { queueIndex = player.nowPlayingIndex }
    }

    private func queueDidChange() {
        guard !queueReadInFlight, trailingRead == nil else { return }
        let wait = queueGap - Date().timeIntervalSince(queueReadFinished)
        guard wait > 0 else { return readQueue() }
        trailingRead = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            trailingRead = nil
            readQueue()
        }
    }

    private func readQueue() {
        guard let player else { return }
        queueTask?.cancel()
        queueReadInFlight = true
        queueTask = Task { [weak self] in
            let songs = (try? await player.queuedSongs()) ?? nil
            guard !Task.isCancelled, let self else { return }
            queueReadInFlight = false
            queueReadFinished = Date()
            let ids = songs?.map(\.id)
            queueGap = ids == queueIDs ? min(max(queueGap, 0.001) * 2, maximumQueueGap) : baseQueueGap
            queueIDs = ids
            queueIsKnown = songs != nil
            queue = songs ?? []
            queueIndex = songs == nil ? nil : player.nowPlayingIndex
        }
    }
}
