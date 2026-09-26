import MediaPlayer
import SwiftUI
import Testing

@testable import MediaBridge

@Suite("NowPlaying")
@MainActor
struct NowPlayingTests {

    @Suite("Given a loader")
    @MainActor
    struct Loading {
        @Test("When first updated, then it shows the current song and state and starts listening")
        func reads() {
            let player = MockMusicPlayer()
            let item = StubMediaItem.song("Hello")
            player.nowPlayingItem = item
            player.playbackState = .playing
            let loader = NowPlayingLoader()

            loader.update(player: player)

            #expect(loader.song?.mediaItem === item)
            #expect(loader.playbackState == .playing)
            #expect(player.notificationRequests == 1)
        }

        @Test("When the player changes songs, then the loader follows")
        func followsSong() async {
            let player = MockMusicPlayer()
            let loader = NowPlayingLoader()
            loader.update(player: player)
            await Task.yield()

            let item = StubMediaItem.song("Angie")
            player.nowPlayingItem = item
            NotificationCenter.default.post(name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
            while loader.song?.mediaItem !== item { await Task.yield() }

            #expect(loader.song?.title == "Angie")
        }

        @Test("When the player pauses, then the loader follows")
        func followsState() async {
            let player = MockMusicPlayer()
            player.playbackState = .playing
            let loader = NowPlayingLoader()
            loader.update(player: player)
            await Task.yield()

            player.playbackState = .paused
            NotificationCenter.default.post(name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
            while loader.playbackState != .paused { await Task.yield() }

            #expect(loader.playbackState == .paused)
        }

        @Test("When updated with the same player, then it doesn't listen twice")
        func dedupes() {
            let player = MockMusicPlayer()
            let loader = NowPlayingLoader()

            loader.update(player: player)
            loader.update(player: player)

            #expect(player.notificationRequests == 1)
        }

        @Test("When the player is replaced, then it stops listening to the old one")
        func switches() {
            let old = MockMusicPlayer()
            let new = MockMusicPlayer()
            new.nowPlayingItem = StubMediaItem.song("Help!")
            let loader = NowPlayingLoader()

            loader.update(player: old)
            loader.update(player: new)

            #expect(old.notificationRequests == 0)
            #expect(new.notificationRequests == 1)
            #expect(loader.song?.title == "Help!")
        }
    }

    @Suite("Given a preview player")
    @MainActor
    struct Preview {
        let items = [StubMediaItem.song("A"), StubMediaItem.song("B"), StubMediaItem.song("C")]

        @Test("When created with a queue, then the first song is current")
        func initial() {
            let player: PreviewMusicPlayer = .preview(queue: items, state: .playing)

            #expect(player.nowPlayingSong?.title == "A")
            #expect(player.playbackState == .playing)
        }

        @Test("When queued starting at a song, then that song is current")
        func startsAt() {
            let player: PreviewMusicPlayer = .preview()
            let songs = items.map(Song.init)

            player.setQueue(with: songs, startingAt: songs[2])

            #expect(player.queue.map(\.title) == ["A", "B", "C"])
            #expect(player.nowPlayingSong?.title == "C")
        }

        @Test("When songs play next and later, then they're inserted after the current song and at the end")
        func upNext() {
            let player: PreviewMusicPlayer = .preview(queue: items)

            player.playNext([Song(StubMediaItem.song("Next"))])
            player.playLater([Song(StubMediaItem.song("Last"))])

            #expect(player.queue.map(\.title) == ["A", "Next", "B", "C", "Last"])
        }

        @Test("When skipping, then the current song moves through the queue and stops at the ends")
        func skips() {
            let player: PreviewMusicPlayer = .preview(queue: items)

            player.skipToNextItem()
            #expect(player.nowPlayingSong?.title == "B")
            player.skipToPreviousItem()
            player.skipToPreviousItem()
            #expect(player.nowPlayingSong?.title == "A")
        }

        @Test("When played, paused, and stopped, then the state follows")
        func states() {
            let player: PreviewMusicPlayer = .preview(queue: items)

            player.play()
            #expect(player.playbackState == .playing)
            player.pause()
            #expect(player.playbackState == .paused)
            player.stop()
            #expect(player.playbackState == .stopped)
        }

        @Test("When set on a view, then the preview spelling reads like the other environment values")
        func environmentSpelling() {
            _ = Text("Now Playing").musicPlayer(.preview(queue: items, state: .playing))
        }

        @Test("When a loader watches it and it skips, then the loader follows")
        func drivesLoader() async {
            let player: PreviewMusicPlayer = .preview(queue: items)
            let loader = NowPlayingLoader()
            loader.update(player: player)
            await Task.yield()

            player.skipToNextItem()
            while loader.song?.title != "B" { await Task.yield() }

            #expect(loader.song?.title == "B")
        }
    }
}
