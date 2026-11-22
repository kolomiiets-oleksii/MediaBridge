import Foundation
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

    final class ThreadRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var recorded: [Bool] = []
        var values: [Bool] { lock.withLock { recorded } }
        func record(_ value: Bool) { lock.withLock { recorded.append(value) } }
    }

    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0
        var value: Int { lock.withLock { count } }
        func increment() { lock.withLock { count += 1 } }
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
            let id = ArtworkKey(kind: .song, id: 1)
            #expect(ArtworkRequest(id: id, side: 192) != ArtworkRequest(id: id, side: 256))
            #expect(ArtworkRequest(id: id, side: 192) != ArtworkRequest(id: ArtworkKey(kind: .song, id: 2), side: 192))
            #expect(ArtworkRequest(id: id, side: 192) != ArtworkRequest(id: ArtworkKey(kind: .album, id: 1), side: 192))
            #expect(ArtworkRequest(id: id, side: 192) == ArtworkRequest(id: id, side: 192))
        }

        @Test("When a refetch returns new objects for the same songs, then the artwork request is unchanged")
        func requestSurvivesRefetch() throws {
            let before = StubMediaItem([MPMediaItemPropertyPersistentID: NSNumber(value: 42)])
            let after = StubMediaItem([MPMediaItemPropertyPersistentID: NSNumber(value: 42)])
            let beforeView = try #require(ArtworkImage(Song(before), size: 44).placeholder { Text("") } as Any as? ArtworkView<Text>)
            let afterView = try #require(ArtworkImage(Song(after), size: 44).placeholder { Text("") } as Any as? ArtworkView<Text>)

            #expect(beforeView.key() == afterView.key())
            #expect(beforeView.key() == ArtworkKey(kind: .song, id: 42))
        }
    }

    @Suite("Given the artwork cache")
    struct Cache {
        static let request = ArtworkRequest(id: ArtworkKey(kind: .song, id: 7), side: 100)

        static func image() -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        }

        @Test("When an image was rendered, then the same request is served from the cache")
        func hit() async throws {
            let cache = ArtworkCache()
            let calls = SizeRecorder()

            let first = await cache.render(Self.request) { size in
                calls.requested.append(size)
                return Self.image()
            }

            #expect(first != nil)
            #expect(cache.image(for: Self.request) === first)
            #expect(cache.image(for: ArtworkRequest(id: Self.request.id, side: 200)) == nil)
            #expect(calls.requested == [CGSize(width: 100, height: 100)])
        }

        @Test("When the artwork is rendered, then it isn't on the main thread")
        func offMain() async {
            let cache = ArtworkCache()
            let onMain = ThreadRecorder()

            _ = await cache.render(Self.request) { _ in
                onMain.record(Thread.isMainThread)
                return Self.image()
            }

            #expect(onMain.values == [false])
        }

        @Test("When an item has no persistent ID, then its artwork isn't cached")
        func uncacheable() async {
            let cache = ArtworkCache()
            let request = ArtworkRequest(id: ArtworkKey(kind: .song, id: 0), side: 100)

            _ = await cache.render(request) { _ in Self.image() }

            #expect(cache.image(for: request) == nil)
        }

        @Test("When one of two callers sharing a render is cancelled, then the other still gets the image")
        func cancelOneOfTwo() async {
            let cache = ArtworkCache()
            let gate = DispatchSemaphore(value: 0)
            let renders = Counter()
            let render: @Sendable (CGSize) -> UIImage? = { _ in
                renders.increment()
                gate.wait()
                return Self.image()
            }

            let cancelled = Task { await cache.render(Self.request, with: render) }
            let kept = Task { await cache.render(Self.request, with: render) }
            while renders.value == 0 { try? await Task.sleep(nanoseconds: 5_000_000) }
            // Let the second caller join the running render before the first one leaves.
            try? await Task.sleep(nanoseconds: 100_000_000)
            cancelled.cancel()
            gate.signal()

            #expect(await kept.value != nil)
            #expect(renders.value == 1)
        }

        @Test("When there is no artwork, then nothing is cached")
        func none() async {
            let cache = ArtworkCache()
            let image = await cache.render(Self.request) { _ in nil }

            #expect(image == nil)
            #expect(cache.image(for: Self.request) == nil)
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
