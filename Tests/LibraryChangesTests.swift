import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Library changes")
struct LibraryChangesTests {

    @Suite("Given the live change source")
    struct Live {
        let center = NotificationCenter()
        let tracker = MockChangeTracker(lastModified: Date(timeIntervalSince1970: 1_000))

        @Test("When the media library posts a change, then changes yields its modification date")
        func yieldsOnNotification() async {
            let source = LiveLibraryChanges(center: center, library: tracker)
            var iterator = source.changes().makeAsyncIterator()

            center.post(name: .MPMediaLibraryDidChange, object: nil)

            #expect(await iterator.next() == Date(timeIntervalSince1970: 1_000))
        }

        @Test("When a consumer starts listening, then the library starts generating notifications")
        func beginsGenerating() {
            let source = LiveLibraryChanges(center: center, library: tracker)
            let stream = source.changes()

            #expect(tracker.begins == 1)
            withExtendedLifetime(stream) {}
        }

        @Test("When the consumer stops listening, then notification generation is balanced")
        func endsGenerating() async {
            let source = LiveLibraryChanges(center: center, library: tracker)
            let task = Task {
                for await _ in source.changes() {}
            }
            await tracker.waitForBegins(1)

            task.cancel()
            await task.value

            #expect(tracker.ends == 1)
        }
    }

    @Suite("Given a MusicLibrary")
    struct Library {
        @Test("When its change source emits, then library.changes forwards it")
        func forwards() async {
            let (stream, continuation) = AsyncStream<Date>.makeStream()
            let library = MusicLibrary(auth: .mock, service: .mock, changes: MockLibraryChanges(stream: stream))
            var iterator = library.changes.makeAsyncIterator()

            continuation.yield(Date(timeIntervalSince1970: 42))

            #expect(await iterator.next() == Date(timeIntervalSince1970: 42))
        }

        @Test("When it is a preview, then changes never ends on its own")
        func previewStaysOpen() async {
            let library: MusicLibrary = .accessAuthorized
            let task = Task { () -> Bool in
                for await _ in library.changes { return true }
                return false
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            task.cancel()

            #expect(await task.value == false)
        }
    }
}

final class MockChangeTracker: MediaLibraryChangeTracking, @unchecked Sendable {
    private let lock = NSLock()
    private var beginCount = 0
    private var endCount = 0
    let lastModifiedDate: Date

    init(lastModified: Date) {
        lastModifiedDate = lastModified
    }

    var begins: Int { lock.withLock { beginCount } }
    var ends: Int { lock.withLock { endCount } }

    func beginGeneratingLibraryChangeNotifications() { lock.withLock { beginCount += 1 } }
    func endGeneratingLibraryChangeNotifications() { lock.withLock { endCount += 1 } }

    func waitForBegins(_ count: Int) async {
        while begins < count { await Task.yield() }
    }
}

struct MockLibraryChanges: LibraryChangesProtocol {
    let stream: AsyncStream<Date>
    func changes() -> AsyncStream<Date> { stream }
}
