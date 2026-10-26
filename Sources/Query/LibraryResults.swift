import Foundation

extension MusicLibraryProtocol {
    /// Streams a ``LibraryQuery``'s results: once now, then again each time the library changes.
    ///
    /// This is what ``MediaQuery`` runs on, for code that isn't a SwiftUI view: an `@Observable`
    /// model, a view controller, a test.
    ///
    /// ```swift
    /// for await result in library.results(.songs.sorted(by: \.title)) {
    ///     switch result {
    ///     case .success(let songs): self.songs = songs
    ///     case .failure(let error): self.error = error
    ///     }
    /// }
    /// ```
    ///
    /// - A failure is delivered as a `.failure` and the stream keeps going, so one failed refetch
    ///   doesn't end updates. That is why this isn't a throwing stream.
    /// - Library changes arrive in bursts (playing a song updates its play count and last played
    ///   date), so changes within `interval` of each other cause one refetch, not several.
    /// - A slow consumer sees only the newest result.
    /// - The stream runs until you stop iterating.
    ///
    /// - Parameters:
    ///   - query: The query to run.
    ///   - interval: How long, in seconds, to wait for a burst of changes to settle before refetching.
    public func results<Element: LibraryElement>(
        _ query: LibraryQuery<Element>,
        coalescing interval: TimeInterval = 0.3
    ) -> AsyncStream<Result<[Element], MusicLibraryError>> {
        let (stream, continuation) = AsyncStream<Result<[Element], MusicLibraryError>>.makeStream(
            bufferingPolicy: .bufferingNewest(1))
        let feed = ResultsFeed(library: self, query: query, interval: interval, continuation: continuation)
        let task = Task { await feed.run() }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }
}

private struct ResultsFeed<Library: MusicLibraryProtocol, Element: LibraryElement>: Sendable {
    let library: Library
    let query: LibraryQuery<Element>
    let interval: TimeInterval
    let continuation: AsyncStream<Result<[Element], MusicLibraryError>>.Continuation

    func run() async {
        let tally = Tally()
        let (triggers, trigger) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        var listener = listen(tally, trigger)
        defer { listener.cancel() }

        let wasAuthorized = library.authorizationStatus == .authorized
        var handled = tally.count
        await publish()

        // The library reports changes only once access is granted, so an observation begun
        // before the system prompt may never hear anything. Begin it again.
        if !wasAuthorized, library.authorizationStatus == .authorized {
            listener.cancel()
            listener = listen(tally, trigger)
        }

        for await _ in triggers {
            try? await Task.sleep(nanoseconds: UInt64(max(interval, 0) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            // Changes that landed while we waited were already folded into this count.
            guard tally.count != handled else { continue }
            handled = tally.count
            await publish()
        }
    }

    // `changes` is read here, before the fetch starts, so a change during the fetch isn't missed.
    private func listen(_ tally: Tally, _ trigger: AsyncStream<Void>.Continuation) -> Task<Void, Never> {
        let changes = library.changes
        return Task {
            for await _ in changes {
                tally.record()
                trigger.yield()
            }
        }
    }

    private func publish() async {
        let result: Result<[Element], MusicLibraryError>
        do throws(MusicLibraryError) {
            result = .success(try await library.fetch(query))
        } catch {
            result = .failure(error)
        }
        guard !Task.isCancelled else { return }
        continuation.yield(result)
    }
}

private final class Tally: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int { lock.withLock { value } }
    func record() { lock.withLock { value += 1 } }
}
