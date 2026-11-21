import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Song source")
struct SongSourceTests {
    static func song(storeID: String?, protected: Bool? = nil) -> Song {
        var values: [String: Any] = [:]
        if let storeID { values[MPMediaItemPropertyPlaybackStoreID] = storeID }
        if let protected { values[MPMediaItemPropertyHasProtectedAsset] = NSNumber(value: protected) }
        return Song(StubMediaItem(values))
    }

    @Suite("Given a song with no store ID")
    struct OwnFile {
        @Test("When the store ID is missing, then the source is ownFile")
        func missing() {
            #expect(SongSourceTests.song(storeID: nil).source == .ownFile)
        }

        @Test("When the store ID is empty, then the source is ownFile")
        func empty() {
            #expect(SongSourceTests.song(storeID: "").source == .ownFile)
        }

        @Test("When the store ID is \"0\", then the source is ownFile")
        func zero() {
            #expect(SongSourceTests.song(storeID: "0").source == .ownFile)
        }

        @Test("When the store ID is missing but the asset is protected, then the source is still ownFile")
        func protectedWithoutStoreID() {
            #expect(SongSourceTests.song(storeID: nil, protected: true).source == .ownFile)
        }

        @Test("When the store ID is missing, then the protected flag is not read")
        func readsStoreIDOnly() {
            let item = StubMediaItem([:])
            _ = Song(item).source
            #expect(item.reads == [MPMediaItemPropertyPlaybackStoreID])
        }
    }

    @Suite("Given a song with a store ID")
    struct Catalog {
        @Test("When the asset is protected, then the source is appleMusic")
        func protected() {
            #expect(SongSourceTests.song(storeID: "1440839718", protected: true).source == .appleMusic)
        }

        @Test("When the asset is unprotected, then the source is purchased")
        func unprotected() {
            #expect(SongSourceTests.song(storeID: "1440839718", protected: false).source == .purchased)
        }

        @Test("When the protected flag is missing, then the source is purchased")
        func flagMissing() {
            #expect(SongSourceTests.song(storeID: "1440839718").source == .purchased)
        }
    }

    @Suite("Given a mixed fetch")
    struct Mixed {
        @Test("When reading mediaType and assetURL, then each forwards to the media item")
        func kindAndFile() {
            let url = URL(string: "ipod-library://item/item.mp3?id=8")!
            let video = Song(StubMediaItem([
                MPMediaItemPropertyMediaType: NSNumber(value: MPMediaType.musicVideo.rawValue),
                MPMediaItemPropertyAssetURL: url,
            ]))

            #expect(video.mediaType == .musicVideo)
            #expect(video.assetURL == url)
            #expect(Song(StubMediaItem([:])).mediaType == [])
            #expect(Song(StubMediaItem([:])).assetURL == nil)
        }

        @Test("When filtering by source, then the condition runs in memory")
        func filtersInMemory() {
            #expect(Song.predicate(for: \Song.source, value: SongSource.ownFile) == nil)
            #expect(Song.predicate(for: \Song.playbackStoreID, value: "0") == nil)
        }
    }
}
