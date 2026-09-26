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
}
