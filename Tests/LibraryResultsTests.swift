import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

/// Access that starts at one status and ends at another once "requested", like the system prompt.
final class SwitchableAuthorization: AuthorizationManagerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var current: MPMediaLibraryAuthorizationStatus
    private let afterRequest: MPMediaLibraryAuthorizationStatus

    init(_ status: MPMediaLibraryAuthorizationStatus, afterRequest: MPMediaLibraryAuthorizationStatus? = nil) {
        current = status
        self.afterRequest = afterRequest ?? status
    }

    func set(_ status: MPMediaLibraryAuthorizationStatus) { lock.withLock { current = status } }

    func status() -> MPMediaLibraryAuthorizationStatus { lock.withLock { current } }

    func authorize() async throws -> MPMediaLibraryAuthorizationStatus {
        lock.withLock {
            if current == .notDetermined { current = afterRequest }
            return current
        }
    }
}

/// Counts how many times the library starts observing, and lets a test fire changes.
final class CountingChanges: LibraryChangesProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var observations = 0
    private var terminated = 0
    private var continuations: [AsyncStream<Date>.Continuation] = []

    var started: Int { lock.withLock { observations } }
    var ended: Int { lock.withLock { terminated } }

    func changes() -> AsyncStream<Date> {
        let (stream, continuation) = AsyncStream<Date>.makeStream()
        lock.withLock {
            observations += 1
            continuations.append(continuation)
        }
        continuation.onTermination = { [self] _ in lock.withLock { terminated += 1 } }
        return stream
    }

    func fire() {
        let live = lock.withLock { continuations }
        live.forEach { $0.yield(Date()) }
    }
}

@Suite("Library results")
struct LibraryResultsTests {
    static let interval = 0.02

    static func titles(_ result: Result<[Song], MusicLibraryError>?) -> [String?]? {
        try? result?.get().map(\.title)
    }

    @Test("When iteration starts, then the first result is the query's fetch")
    func initial() async {
        let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: [StubMediaItem.song("A")]), changes: CountingChanges())
        var results = library.results(.songs, coalescing: Self.interval).makeAsyncIterator()

        #expect(Self.titles(await results.next()) == ["A"])
    }

    @Test("When the library changes, then the query's results arrive again")
    func refetches() async {
        let changes = CountingChanges()
        let service = MockMusicLibraryService(items: [StubMediaItem.song("A")])
        let library = MusicLibrary(auth: .mock, service: service, changes: changes)
        var results = library.results(.songs, coalescing: Self.interval).makeAsyncIterator()
        _ = await results.next()

        changes.fire()

        #expect(Self.titles(await results.next()) == ["A"])
        #expect(service.requests.count == 2)
    }

    @Test("When changes come in a burst, then they cause one refetch")
    func coalesces() async throws {
        let changes = CountingChanges()
        let service = MockMusicLibraryService()
        let library = MusicLibrary(auth: .mock, service: service, changes: changes)
        var results = library.results(.songs, coalescing: 0.05).makeAsyncIterator()
        _ = await results.next()

        for _ in 0..<5 { changes.fire() }
        _ = await results.next()
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(service.requests.count == 2)
    }

    @Test("When a fetch fails, then the failure is delivered and the stream keeps going")
    func survivesFailure() async {
        let changes = CountingChanges()
        let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: .mock, changes: changes)
        var results = library.results(.songs, coalescing: Self.interval).makeAsyncIterator()

        let first = await results.next()
        changes.fire()
        let second = await results.next()

        #expect(throws: MusicLibraryError.unauthorized(.denied)) { try first?.get() }
        #expect(throws: MusicLibraryError.unauthorized(.denied)) { try second?.get() }
    }

    @Test("When iteration stops, then the library stops observing changes")
    func stops() async {
        let changes = CountingChanges()
        let library = MusicLibrary(auth: .mock, service: .mock, changes: changes)
        do {
            var results = library.results(.songs, coalescing: Self.interval).makeAsyncIterator()
            _ = await results.next()
        }

        while changes.ended < changes.started { await Task.yield() }

        #expect(changes.started == 1)
        #expect(changes.ended == 1)
    }

    @Test("When access is already granted, then the library is observed once")
    func observesOnceWhenAuthorized() async {
        let changes = CountingChanges()
        let library = MusicLibrary(auth: .mock, service: .mock, changes: changes)
        var results = library.results(.songs, coalescing: Self.interval).makeAsyncIterator()
        _ = await results.next()

        #expect(changes.started == 1)
    }

    @Test("When the first fetch is what grants access, then the library is observed again afterwards")
    func observesAgainAfterGrant() async {
        let changes = CountingChanges()
        let auth = SwitchableAuthorization(.notDetermined, afterRequest: .authorized)
        let library = MusicLibrary(auth: auth, service: MockMusicLibraryService(items: [StubMediaItem.song("A")]), changes: changes)
        var results = library.results(.songs, coalescing: Self.interval).makeAsyncIterator()

        #expect(Self.titles(await results.next()) == ["A"])
        while changes.started < 2 { await Task.yield() }

        changes.fire()
        #expect(Self.titles(await results.next()) == ["A"])
    }
}
