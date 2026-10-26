import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("PlaybackPosition")
struct PlaybackPositionTests {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)

    @Suite("Given a position")
    struct Math {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        @Test("When it plays at normal speed, then time moves with the clock")
        func playing() {
            let position = PlaybackPosition(time: 30, date: start, rate: 1)
            #expect(position.time(at: start.addingTimeInterval(12)) == 42)
        }

        @Test("When it is paused, then time stays where it was")
        func paused() {
            let position = PlaybackPosition(time: 30, date: start, rate: 0)
            #expect(position.time(at: start.addingTimeInterval(500)) == 30)
        }

        @Test("When the rate is 2, then time moves twice as fast")
        func fast() {
            let position = PlaybackPosition(time: 10, date: start, rate: 2)
            #expect(position.time(at: start.addingTimeInterval(5)) == 20)
        }

        @Test("When asked about a moment before it was read, then time doesn't run backwards")
        func earlier() {
            let position = PlaybackPosition(time: 30, date: start, rate: 1)
            #expect(position.time(at: start.addingTimeInterval(-10)) == 30)
        }

        @Test("When the song's duration is given, then time stops at its end")
        func clamped() {
            let position = PlaybackPosition(time: 100, date: start, rate: 1)
            #expect(position.time(at: start.addingTimeInterval(60), clampedTo: 120) == 120)
            #expect(position.time(at: start.addingTimeInterval(60)) == 160)
        }

        @Test("When nothing has played, then the zero position is at time 0")
        func zero() {
            #expect(PlaybackPosition.zero.time(at: Date()) == 0)
        }
    }

    @Suite("Given a player")
    struct FromPlayer {
        @Test("When playing, then the position moves at the player's rate")
        func playing() {
            let player = MockMusicPlayer()
            player.playbackState = .playing
            player.currentPlaybackTime = 12
            player.currentPlaybackRate = 1.5

            let position = player.playbackPosition

            #expect(position.time == 12)
            #expect(position.rate == 1.5)
        }

        @Test("When playing and the player reports rate 0, then it moves at normal speed")
        func zeroRateWhilePlaying() {
            let player = MockMusicPlayer()
            player.playbackState = .playing
            player.currentPlaybackRate = 0

            #expect(player.playbackPosition.rate == 1)
        }

        @Test("When paused or stopped, then the position doesn't move")
        func notPlaying() {
            let player = MockMusicPlayer()
            player.currentPlaybackTime = 12
            for state in [MPMusicPlaybackState.paused, .stopped, .interrupted] {
                player.playbackState = state
                #expect(player.playbackPosition.rate == 0)
            }
        }

        @Test("When MediaPlayer reports no time, then the position is at the start")
        func notFinite() {
            let player = MockMusicPlayer()
            player.currentPlaybackTime = .nan
            #expect(player.playbackPosition.time == 0)
        }

        @Test("When nothing is queued, then there is no index")
        func noIndex() {
            let player = MockMusicPlayer()
            #expect(player.nowPlayingIndex == nil)
            player.indexOfNowPlayingItem = 3
            #expect(player.nowPlayingIndex == 3)
        }

        @Test("When a conforming type doesn't implement the 1.5 members, then the defaults apply")
        func defaults() async throws {
            final class Minimal: MusicPlayerProtocol {
                var nowPlayingItem: MPMediaItem? { nil }
                var playbackState: MPMusicPlaybackState { .stopped }
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
            let player = Minimal()

            #expect(player.currentPlaybackTime == 0)
            #expect(player.repeatMode == .default)
            #expect(player.nowPlayingIndex == nil)
            #expect(try await player.queuedSongs() == nil)
        }
    }

    @Suite("Given a loader")
    @MainActor
    struct Loading {
        let items = [StubMediaItem.song("A"), StubMediaItem.song("B"), StubMediaItem.song("C")]

        @Test("When first updated, then it reads position, repeat and shuffle")
        func reads() {
            let player = MockMusicPlayer()
            player.playbackState = .playing
            player.currentPlaybackTime = 20
            player.repeatMode = .all
            player.shuffleMode = .songs
            let loader = NowPlayingLoader()

            loader.update(player: player)

            #expect(loader.position.time == 20)
            #expect(loader.position.rate == 1)
            #expect(loader.repeatMode == .all)
            #expect(loader.shuffleMode == .songs)
        }

        @Test("When seeking, then the player moves and the position is read again")
        func seeks() {
            let player = MockMusicPlayer()
            let loader = NowPlayingLoader()
            loader.update(player: player)

            loader.seek(to: 75)

            #expect(player.currentPlaybackTime == 75)
            #expect(loader.position.time == 75)
        }

        @Test("When seeking before the start, then it seeks to 0")
        func seekClamps() {
            let player = MockMusicPlayer()
            let loader = NowPlayingLoader()
            loader.update(player: player)

            loader.seek(to: -5)

            #expect(player.currentPlaybackTime == 0)
        }

        @Test("When repeat and shuffle are set, then the player and the loader follow")
        func setsModes() {
            let player = MockMusicPlayer()
            let loader = NowPlayingLoader()
            loader.update(player: player)

            loader.setRepeatMode(.one)
            loader.setShuffleMode(.albums)

            #expect(player.repeatMode == .one)
            #expect(loader.repeatMode == .one)
            #expect(player.shuffleMode == .albums)
            #expect(loader.shuffleMode == .albums)
        }

        @Test("When the player pauses, then the position stops moving")
        func pauseFreezes() async {
            let player = MockMusicPlayer()
            player.playbackState = .playing
            let loader = NowPlayingLoader()
            loader.update(player: player)
            await Task.yield()

            player.playbackState = .paused
            NotificationCenter.default.post(name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
            while loader.position.rate != 0 { await Task.yield() }

            #expect(loader.position.rate == 0)
        }

        @Test("When the player reports its queue, then the loader shows it with the current index")
        func queue() async {
            let player = MockMusicPlayer()
            player.queue = items.map(Song.init)
            player.indexOfNowPlayingItem = 1
            let loader = NowPlayingLoader()

            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            #expect(loader.queue.map(\.title) == ["A", "B", "C"])
            #expect(loader.queueIndex == 1)
        }

        @Test("When the queue changes, then the loader reads it again")
        func queueChanges() async {
            let player = MockMusicPlayer()
            player.queue = [Song(items[0])]
            let loader = NowPlayingLoader(queueGap: 0)
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            player.queue = items.map(Song.init)
            NotificationCenter.default.post(name: .MPMusicPlayerControllerQueueDidChange, object: player)
            while loader.queue.count != 3 { await Task.yield() }

            #expect(loader.queue.count == 3)
        }

        @Test("When the player can't report its queue, then the loader's queue is empty and has no index")
        func noQueue() async {
            let player = MockMusicPlayer()
            player.indexOfNowPlayingItem = 2
            let loader = NowPlayingLoader()

            loader.update(player: player)
            for _ in 0..<10 { await Task.yield() }

            #expect(loader.queue.isEmpty)
            #expect(loader.queueIndex == nil)
        }

        @Test("When the queue is known, then Up Next is the songs after the current one")
        func upNext() async {
            let player = MockMusicPlayer()
            player.queue = items.map(Song.init)
            player.indexOfNowPlayingItem = 0
            let loader = NowPlayingLoader()
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            let status = NowPlaying.Status(loader: loader)

            #expect(status.upNext.map(\.title) == ["B", "C"])
            #expect(status.queueIndex == 0)
        }

        @Test("When the current song is last, then Up Next is empty")
        func upNextAtEnd() async {
            let player = MockMusicPlayer()
            player.queue = items.map(Song.init)
            player.indexOfNowPlayingItem = 2
            let loader = NowPlayingLoader()
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            #expect(NowPlaying.Status(loader: loader).upNext.isEmpty)
        }
    }

    /// A player whose queue read announces itself, as a real queue transaction might.
    final class EchoingPlayer: MusicPlayerProtocol {
        var nowPlayingItem: MPMediaItem?
        var playbackState: MPMusicPlaybackState = .playing
        var indexOfNowPlayingItem = 0
        private(set) var reads = 0
        var songs = [Song(StubMediaItem.song("A"))]
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

        @MainActor func queuedSongs() async throws(MusicLibraryError) -> [Song]? {
            reads += 1
            NotificationCenter.default.post(name: .MPMusicPlayerControllerQueueDidChange, object: self)
            await Task.yield()
            NotificationCenter.default.post(name: .MPMusicPlayerControllerQueueDidChange, object: self)
            // And once more after the read has returned.
            Task { @MainActor [self] in
                for _ in 0..<3 { await Task.yield() }
                NotificationCenter.default.post(name: .MPMusicPlayerControllerQueueDidChange, object: self)
            }
            return songs
        }
    }

    @Suite("Given a player whose queue read announces itself")
    @MainActor
    struct Echo {
        @Test("When reading the queue posts a queue change, then the loader doesn't read forever")
        func noLoop() async {
            let player = EchoingPlayer()
            let loader = NowPlayingLoader()
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            for _ in 0..<200 { await Task.yield() }

            // The first read, and at most a trailing one after the gap; never a loop.
            #expect(player.reads <= 2)
        }

        @Test("When playback changes, then the queue isn't read again")
        func playbackDoesNotReadQueue() async {
            let player = EchoingPlayer()
            let loader = NowPlayingLoader()
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            for _ in 0..<5 {
                NotificationCenter.default.post(name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
                NotificationCenter.default.post(name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
                loader.seek(to: 10)
                loader.setRepeatMode(.all)
                for _ in 0..<20 { await Task.yield() }
            }

            #expect(player.reads <= 2)
        }

        @Test("When the song changes, then the index follows without reading the queue again")
        func indexFollows() async {
            let player = EchoingPlayer()
            let loader = NowPlayingLoader()
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            player.indexOfNowPlayingItem = 4
            NotificationCenter.default.post(name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)
            while loader.queueIndex != 4 { await Task.yield() }

            #expect(player.reads <= 2)
        }

        @Test("When reads keep finding the queue unchanged, then the gap between them grows")
        func backsOff() async throws {
            let player = EchoingPlayer()
            let loader = NowPlayingLoader(queueGap: 0.01, maximumQueueGap: 0.2)
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }

            try await Task.sleep(nanoseconds: 1_000_000_000)

            // Gaps of .01, .02, .04, .08, .16, then .2 apiece: about 8 reads in a second, not ~100.
            #expect(player.reads < 20)
        }

        @Test("When the queue really changes, then it is read again and the gap resets")
        func realChange() async throws {
            let player = EchoingPlayer()
            let loader = NowPlayingLoader(queueGap: 0.01, maximumQueueGap: 0.2)
            loader.update(player: player)
            while loader.queue.isEmpty { await Task.yield() }
            try await Task.sleep(nanoseconds: 300_000_000)

            player.songs = [StubMediaItem.song("A"), StubMediaItem.song("B")].map(Song.init)
            NotificationCenter.default.post(name: .MPMusicPlayerControllerQueueDidChange, object: player)
            while loader.queue.count != 2 { await Task.yield() }

            #expect(loader.queue.count == 2)
        }
    }

    @Suite("Given a preview player")
    @MainActor
    struct Preview {
        let items = [StubMediaItem.song("A"), StubMediaItem.song("B"), StubMediaItem.song("C")]

        @Test("When seeking, then the time is kept and the loader follows")
        func seeks() async {
            let player: PreviewMusicPlayer = .preview(queue: items, state: .playing)
            let loader = NowPlayingLoader()
            loader.update(player: player)

            loader.seek(to: 42)

            #expect(player.currentPlaybackTime == 42)
            #expect(loader.position.time == 42)
        }

        @Test("When the song changes or restarts, then the time goes back to 0")
        func resets() {
            let player: PreviewMusicPlayer = .preview(queue: items)
            player.currentPlaybackTime = 30
            player.skipToNextItem()
            #expect(player.currentPlaybackTime == 0)

            player.currentPlaybackTime = 30
            player.skipToBeginning()
            #expect(player.currentPlaybackTime == 0)
        }

        @Test("When asked for its queue and index, then it reports them")
        func queue() async throws {
            let player: PreviewMusicPlayer = .preview(queue: items)
            player.skipToNextItem()

            #expect(try await player.queuedSongs()?.map(\.title) == ["A", "B", "C"])
            #expect(player.indexOfNowPlayingItem == 1)
        }

        @Test("When songs are queued, then the loader's Up Next follows")
        func upNextFollows() async {
            let player: PreviewMusicPlayer = .preview(queue: items)
            let loader = NowPlayingLoader()
            loader.update(player: player)
            while loader.queue.count != 3 { await Task.yield() }

            player.playNext([Song(StubMediaItem.song("Next"))])
            while loader.queue.count != 4 { await Task.yield() }

            #expect(NowPlaying.Status(loader: loader).upNext.map(\.title) == ["Next", "B", "C"])
        }
    }
}
