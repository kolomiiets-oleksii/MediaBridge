import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Song")
struct SongTests {
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    var item: StubMediaItem {
        StubMediaItem([
            MPMediaItemPropertyPersistentID: NSNumber(value: UInt64(42)),
            MPMediaItemPropertyTitle: "Yesterday",
            MPMediaItemPropertyArtist: "The Beatles",
            MPMediaItemPropertyAlbumTitle: "Help!",
            MPMediaItemPropertyAlbumArtist: "The Beatles",
            MPMediaItemPropertyGenre: "Rock",
            MPMediaItemPropertyComposer: "Lennon–McCartney",
            MPMediaItemPropertyPlayCount: NSNumber(value: 9),
            MPMediaItemPropertySkipCount: NSNumber(value: 2),
            MPMediaItemPropertyRating: NSNumber(value: 5),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: 125.5),
            MPMediaItemPropertyReleaseDate: date,
            MPMediaItemPropertyIsCloudItem: NSNumber(value: true),
            MPMediaItemPropertyIsExplicit: NSNumber(value: false),
        ])
    }

    @Suite("Given a large library")
    struct Wrapping {
        @Test("When 10,000 items are wrapped as songs, then no property is read")
        func zeroCopy() {
            let items = (0..<10_000).map { StubMediaItem([MPMediaItemPropertyTitle: "Song \($0)"]) }

            let songs = items.map(Song.init)

            #expect(songs.count == 10_000)
            #expect(items.allSatisfy { $0.reads.isEmpty })
        }

        @Test("When a song is wrapped, then mediaItem is the same object")
        func escapeHatch() {
            let item = StubMediaItem([:])
            #expect(Song(item).mediaItem === item)
        }
    }

    @Suite("Given a wrapped song")
    struct Properties {
        @Test("When reading its properties, then each forwards to the media item")
        func forwards() {
            let song = Song(SongTests().item)

            #expect(song.id == 42)
            #expect(song.title == "Yesterday")
            #expect(song.artist == "The Beatles")
            #expect(song.albumTitle == "Help!")
            #expect(song.albumArtist == "The Beatles")
            #expect(song.genre == "Rock")
            #expect(song.composer == "Lennon–McCartney")
            #expect(song.playCount == 9)
            #expect(song.skipCount == 2)
            #expect(song.rating == 5)
            #expect(song.duration == 125.5)
            #expect(song.releaseDate == SongTests().date)
            #expect(song.isCloudItem)
            #expect(!song.isExplicit)
        }

        @Test("When reading one property, then only that property is fetched")
        func readsOnDemand() {
            let item = SongTests().item
            _ = Song(item).title
            #expect(item.reads == [MPMediaItemPropertyTitle])
        }

        @Test("When a property is missing, then counts default to zero and flags to false")
        func defaults() {
            let song = Song(StubMediaItem([:]))
            #expect(song.title == nil)
            #expect(song.playCount == 0)
            #expect(!song.isCloudItem)
        }

        @Test("When two songs wrap the same persistent ID, then they are equal and hash alike")
        func identity() {
            let a = Song(StubMediaItem([MPMediaItemPropertyPersistentID: NSNumber(value: UInt64(7))]))
            let b = Song(StubMediaItem([MPMediaItemPropertyPersistentID: NSNumber(value: UInt64(7))]))
            #expect(a == b)
            #expect(Set([a, b]).count == 1)
        }
    }
}
