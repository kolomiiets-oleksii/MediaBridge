import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Playback queue")
struct PlaybackQueueTests {

    @Suite("Given songs to play")
    struct Songs {
        @Test("When they become a queue, then it holds the same media items in the same order")
        func keepsOrder() {
            let items = [StubMediaItem.song("Help!"), StubMediaItem.song("Hello"), StubMediaItem.song("Angie")]

            let queue = MPMediaItemCollection(songs: items.map(Song.init))

            #expect(queue.items.map(ObjectIdentifier.init) == items.map(ObjectIdentifier.init))
        }

        @Test("When they become a queue, then no song property is read")
        func readsNothing() {
            let items = (0..<100).map { _ in StubMediaItem([MPMediaItemPropertyTitle: "Song"]) }

            _ = MPMediaItemCollection(songs: items.map(Song.init))

            #expect(items.allSatisfy { $0.reads.isEmpty })
        }
    }

    @Suite("Given a player")
    struct Queueing {
        let player = MockMusicPlayer()
        let items = [StubMediaItem.song("Help!"), StubMediaItem.song("Hello"), StubMediaItem.song("Angie")]

        @Test("When songs are queued, then the player gets them in order, starting at the first")
        func queues() throws {
            player.setQueue(with: items.map(Song.init))

            let queue = try #require(player.queued.first)
            #expect(queue.songIdentities == items.map(ObjectIdentifier.init))
            #expect(queue.startIdentity == nil)
        }

        @Test("When songs are queued starting at one of them, then playback starts at that song")
        func startsAt() throws {
            let songs = items.map(Song.init)

            player.setQueue(with: songs, startingAt: songs[1])

            let queue = try #require(player.queued.first)
            #expect(queue.songIdentities == items.map(ObjectIdentifier.init))
            #expect(queue.startIdentity == ObjectIdentifier(items[1]))
        }
    }

    @Suite("Given a player with a queue")
    struct UpNext {
        let player = MockMusicPlayer()
        let items = [StubMediaItem.song("Help!"), StubMediaItem.song("Hello")]

        @Test("When songs play next, then they're inserted after the current song")
        func playNext() throws {
            player.playNext(items.map(Song.init))

            let inserted = try #require(player.prepended.first)
            #expect(inserted.songIdentities == items.map(ObjectIdentifier.init))
            #expect(player.appended.isEmpty)
        }

        @Test("When songs play later, then they're added to the end of the queue")
        func playLater() throws {
            player.playLater(items.map(Song.init))

            let added = try #require(player.appended.first)
            #expect(added.songIdentities == items.map(ObjectIdentifier.init))
            #expect(player.prepended.isEmpty)
        }

        @Test("When there are no songs, then the queue isn't touched")
        func empty() {
            player.playNext([])
            player.playLater([])

            #expect(player.prepended.isEmpty)
            #expect(player.appended.isEmpty)
        }
    }
}

@Suite("Now playing song")
struct NowPlayingSongTests {
    @Test("When the player has a current item, then nowPlayingSong wraps that same item")
    func wraps() throws {
        let player = MockMusicPlayer()
        let item = StubMediaItem.song("Hello")
        player.nowPlayingItem = item

        let song = try #require(player.nowPlayingSong)

        #expect(song.mediaItem === item)
    }

    @Test("When nothing is playing, then nowPlayingSong is nil")
    func empty() {
        #expect(MockMusicPlayer().nowPlayingSong == nil)
    }
}
