import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

/// A player that, like `MPMusicPlayerController` on a device, keeps reporting the time from
/// before a seek until it has applied it.
final class LaggingPlayer: MusicPlayerProtocol {
    var nowPlayingItem: MPMediaItem?
    var playbackState: MPMusicPlaybackState = .playing
    var currentPlaybackRate: Float = 1
    var indexOfNowPlayingItem = NSNotFound
    private var reportedTime: TimeInterval = 10
    private var pendingTime: TimeInterval?

    var currentPlaybackTime: TimeInterval {
        get { reportedTime }
        set { pendingTime = newValue }
    }

    /// The player finishes the seek, landing at `drift` seconds past the requested time.
    func applySeek(drift: TimeInterval = 0) {
        if let pendingTime { reportedTime = pendingTime + drift }
        pendingTime = nil
    }

    func setQueue(with descriptor: MPMusicPlayerQueueDescriptor) {}
    func prepend(_ descriptor: MPMusicPlayerQueueDescriptor) {}
    func append(_ descriptor: MPMusicPlayerQueueDescriptor) {}
    func play() {}
    func pause() {}
    func stop() {}
    func skipToNextItem() {}
    func skipToPreviousItem() {}
    func skipToBeginning() {}
    func beginGeneratingPlaybackNotifications() {}
    func endGeneratingPlaybackNotifications() {}
}

@Suite("Seek position (#98)")
@MainActor
struct SeekPositionTests {
    let clock = ManualClock()
    let player = LaggingPlayer()

    func loader() -> NowPlayingLoader {
        let loader = NowPlayingLoader(seekSettleDelay: 0.5, clock: clock.loaderClock)
        loader.update(player: player)
        return loader
    }

    @Test("When the player still reports the old time after a seek, then the position is the target and keeps moving")
    func publishesTarget() {
        let loader = loader()

        let before = Date()
        loader.seek(to: 120)

        #expect(loader.position.time == 120)
        #expect(loader.position.rate == 1)
        #expect(loader.position.date >= before)
        #expect(loader.position.time(at: loader.position.date.addingTimeInterval(5)) == 125)
    }

    @Test("When paused and the player lags, then the position is the target and stays there")
    func pausedTarget() {
        player.playbackState = .paused
        let loader = loader()

        loader.seek(to: 45)

        #expect(loader.position.time == 45)
        #expect(loader.position.rate == 0)
    }

    @Test("When the player has applied the seek, then the position settles on the player's real time")
    func settles() async {
        let loader = loader()

        loader.seek(to: 120)
        player.applySeek(drift: 0.5)
        await clock.advance(by: 0.4)
        #expect(loader.position.time == 120)

        await clock.advance(by: 0.1)
        #expect(loader.position.time == 120.5)
    }

    @Test("When seeking again before the first seek settles, then the first seek's re-read doesn't overwrite the latest target")
    func latestWins() async {
        let loader = loader()

        loader.seek(to: 30)
        await clock.advance(by: 0.25)
        loader.seek(to: 90)
        // Past the first seek's settle time, before the second's; the player still reports 10.
        await clock.advance(by: 0.35)

        #expect(loader.position.time == 90)
        #expect(clock.pendingSleepers == 1)
    }
}
