import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Seek clamp")
@MainActor
struct SeekClampTests {
    private func loader(duration: TimeInterval?, at time: TimeInterval = 10) -> (NowPlayingLoader, MockMusicPlayer) {
        let player = MockMusicPlayer()
        if let duration {
            player.nowPlayingItem = StubMediaItem([MPMediaItemPropertyPlaybackDuration: duration])
        }
        player.currentPlaybackTime = time
        let loader = NowPlayingLoader()
        loader.update(player: player)
        return (loader, player)
    }

    @Test("When seeking past the end, then it seeks to the song's duration")
    func clampsToDuration() {
        let (loader, player) = loader(duration: 200)
        loader.seek(to: 500)
        #expect(player.currentPlaybackTime == 200)
        loader.seek(to: .greatestFiniteMagnitude)
        #expect(player.currentPlaybackTime == 200)
    }

    @Test("When seeking inside the song, then it seeks there")
    func keepsValidTime() {
        let (loader, player) = loader(duration: 200)
        loader.seek(to: 42.5)
        #expect(player.currentPlaybackTime == 42.5)
    }

    @Test("When the duration is unknown, then the time is held to a day")
    func capsWithoutDuration() {
        let (loader, player) = loader(duration: nil)
        loader.seek(to: 1e300)
        #expect(player.currentPlaybackTime == 86_400)
        loader.seek(to: 60)
        #expect(player.currentPlaybackTime == 60)
    }

    @Test("When the duration is 0, then the day cap applies")
    func zeroDuration() {
        let (loader, player) = loader(duration: 0)
        loader.seek(to: 90)
        #expect(player.currentPlaybackTime == 90)
    }

    @Test("When the time is not a number or infinite, then the player doesn't move")
    func ignoresNonFinite() {
        let (loader, player) = loader(duration: 200, at: 33)
        for bad in [Double.nan, .infinity, -.infinity] {
            loader.seek(to: bad)
            #expect(player.currentPlaybackTime == 33)
        }
    }

    @Test("When seeking before the start, then it seeks to 0")
    func clampsToStart() {
        let (loader, player) = loader(duration: 200)
        loader.seek(to: -5)
        #expect(player.currentPlaybackTime == 0)
    }
}
