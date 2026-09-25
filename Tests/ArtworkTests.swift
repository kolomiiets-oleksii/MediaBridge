import MediaPlayer
import Testing
import UIKit

@testable import MediaBridge

@Suite("Artwork")
struct ArtworkTests {
    final class SizeRecorder: @unchecked Sendable {
        var requested: [CGSize] = []
    }

    static func item(recording recorder: SizeRecorder) -> StubMediaItem {
        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { size in
            recorder.requested.append(size)
            return UIGraphicsImageRenderer(size: size).image { _ in }
        }
        return StubMediaItem([MPMediaItemPropertyArtwork: artwork, MPMediaItemPropertyTitle: "Hello"])
    }

    @Suite("Given a song with artwork")
    struct WithArtwork {
        @Test("When a row asks for 44pt artwork, then MediaPlayer renders it at that size")
        func requestedSize() throws {
            let recorder = SizeRecorder()
            let song = Song(ArtworkTests.item(recording: recorder))

            let image = try #require(song.artwork(size: CGSize(width: 44, height: 44)))

            #expect(image.size == CGSize(width: 44, height: 44))
            #expect(recorder.requested == [CGSize(width: 44, height: 44)])
        }

        @Test("When artwork is requested, then only the artwork property is read")
        func readsOnlyArtwork() {
            let item = ArtworkTests.item(recording: SizeRecorder())
            _ = Song(item).artwork(size: CGSize(width: 44, height: 44))
            #expect(item.reads == [MPMediaItemPropertyArtwork])
        }

        @Test("When an album asks for artwork, then its representative song's artwork is used")
        func album() {
            let recorder = SizeRecorder()
            let album = Album(MPMediaItemCollection(items: [ArtworkTests.item(recording: recorder)]))

            #expect(album.artwork(size: CGSize(width: 100, height: 100)) != nil)
            #expect(recorder.requested == [CGSize(width: 100, height: 100)])
        }
    }

    @Suite("Given the model types")
    struct Storage {
        @Test("When laid out in memory, then a Song holds nothing but its media item")
        func noStoredArtwork() {
            #expect(MemoryLayout<Song>.size == MemoryLayout<MPMediaItem>.size)
            #expect(MemoryLayout<Album>.size == MemoryLayout<MPMediaItemCollection>.size)
        }

        @Test("When a song has no artwork, then artwork is nil")
        func missing() {
            #expect(Song(StubMediaItem([:])).artwork(size: CGSize(width: 44, height: 44)) == nil)
        }
    }
}
