import MediaPlayer
import SwiftUI
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

    @Suite("Given a list of artwork views")
    @MainActor
    struct Views {
        @Test("When 1,000 rows build their artwork views, then no song or album property is read")
        func initReadsNothing() {
            let items = (0..<1_000).map { _ in StubMediaItem([MPMediaItemPropertyTitle: "Song"]) }

            let songViews = items.map { ArtworkImage(Song($0), size: 44) }
            let albumViews = items.map { ArtworkImage(Album(MPMediaItemCollection(items: [$0])), size: 44) }

            #expect(songViews.count + albumViews.count == 2_000)
            #expect(items.allSatisfy { $0.reads.isEmpty })
        }

        @Test("When no corner radius is given, then it is an eighth of the size")
        func defaultCornerRadius() {
            let view = ArtworkImage(Song(StubMediaItem([:])), size: 48)
            #expect(view.size == 48)
            #expect(view.cornerRadius(side: 48) == 6)
        }

        @Test("When a corner radius is given, then the artwork uses it")
        func customCornerRadius() {
            let view = ArtworkImage(Song(StubMediaItem([:])), size: 48, cornerRadius: 4)
            #expect(view.cornerRadius(side: 48) == 4)
        }

        @Test("When a placeholder is given, then it replaces the default one and keeps the size and corner radius")
        func customPlaceholder() throws {
            let item = StubMediaItem([MPMediaItemPropertyTitle: "Song"])

            let view = ArtworkImage(Song(item), size: 48, cornerRadius: 4).placeholder { Text("No artwork") }

            let artwork = try #require(view as Any as? ArtworkView<Text>)
            #expect(artwork.size == 48)
            #expect(artwork.cornerRadius(side: 48) == 4)
            #expect(item.reads.isEmpty)
        }
    }

    @Suite("Given artwork without a size")
    @MainActor
    struct Flexible {
        @Test("When 1,000 rows build flexible artwork views, then no song or album property is read")
        func initReadsNothing() {
            let items = (0..<1_000).map { _ in StubMediaItem([MPMediaItemPropertyTitle: "Song"]) }

            let songViews = items.map { ArtworkImage(Song($0)) }
            let albumViews = items.map { ArtworkImage(Album(MPMediaItemCollection(items: [$0]))) }

            #expect(songViews.count + albumViews.count == 2_000)
            #expect(items.allSatisfy { $0.reads.isEmpty })
        }

        @Test("When no size is given, then the artwork fills the width it's offered")
        func fills() {
            #expect(ArtworkImage(Song(StubMediaItem([:]))).size == nil)
        }

        @Test("When laid out 160pt wide without a corner radius, then the corners are an eighth of that")
        func defaultCornerRadius() {
            let view = ArtworkImage(Album(MPMediaItemCollection(items: [StubMediaItem([:])])))
            #expect(view.cornerRadius(side: 160) == 20)
        }

        @Test("When given a corner radius and a placeholder, then both are kept")
        func placeholder() throws {
            let view = ArtworkImage(Song(StubMediaItem([:])), cornerRadius: 8).placeholder { Text("No artwork") }

            let artwork = try #require(view as Any as? ArtworkView<Text>)
            #expect(artwork.size == nil)
            #expect(artwork.cornerRadius(side: 160) == 8)
        }

        @Test("When offered 160pt of width, then it lays out as a 160pt square")
        func laysOutSquare() throws {
            guard #available(iOS 16, visionOS 1, *) else { return }
            let renderer = ImageRenderer(content: ArtworkImage(Song(StubMediaItem([:]))).frame(width: 160))

            let image = try #require(renderer.uiImage)

            #expect(image.size == CGSize(width: 160, height: 160))
        }

        @Test("When the width changes within a 64pt step, then the artwork isn't rendered again")
        func keepsRenderWithinStep() {
            #expect(ArtworkRequest.flexibleSide(for: 150) == 192)
            #expect(ArtworkRequest.flexibleSide(for: 170) == 192)
            #expect(ArtworkRequest.flexibleSide(for: 192) == 192)
        }

        @Test("When the width crosses a 64pt step, then the artwork renders at the next step")
        func rendersAtNextStep() {
            #expect(ArtworkRequest.flexibleSide(for: 193) == 256)
            #expect(ArtworkRequest.flexibleSide(for: 0) == 0)
        }

        @Test("When the rendered size or the item changes, then it's a new request")
        func requestIdentity() {
            let first = StubMediaItem([:])
            let second = StubMediaItem([:])
            let id = ObjectIdentifier(first)
            #expect(ArtworkRequest(id: id, side: 192) != ArtworkRequest(id: id, side: 256))
            #expect(ArtworkRequest(id: id, side: 192) != ArtworkRequest(id: ObjectIdentifier(second), side: 192))
            #expect(ArtworkRequest(id: id, side: 192) == ArtworkRequest(id: id, side: 192))
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
