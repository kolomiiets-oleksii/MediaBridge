import Combine
import Foundation

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
final class MediaQueryLoader<Element: LibraryElement>: ObservableObject {
    @Published private(set) var elements: [Element] = []
    /// True until the current query's first result arrives. Later refetches triggered by library
    /// changes don't set it, so a list doesn't flash a spinner while a song plays.
    @Published private(set) var isLoading = false
    @Published private(set) var error: MusicLibraryError?

    private var query: LibraryQuery<Element>?
    private var library: (any MusicLibraryProtocol)?
    private var libraryIdentity: ObjectIdentifier?
    private var feed: Task<Void, Never>?
    private var feedCancellable: AnyCancellable?
    private var foregroundCancellable: AnyCancellable?
    private var awaitingFirstResult = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(notifications: NotificationCenter = .default) {
        #if canImport(UIKit)
            foregroundCancellable = notifications
                .publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { [weak self] _ in
                    Task { @MainActor in self?.recoverFromDeniedAccess() }
                }
        #endif
    }

    func update(query: LibraryQuery<Element>, library: any MusicLibraryProtocol) {
        let identity = Self.identity(of: library)
        guard identity != libraryIdentity || query != self.query else { return }

        self.query = query
        self.library = library
        libraryIdentity = identity
        start()
    }

    func reload() async {
        start()
        await settle()
    }

    /// Returns once the current query's first result is in.
    func settle() async {
        guard awaitingFirstResult else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func start() {
        guard let query, let library else { return }
        feed?.cancel()
        awaitingFirstResult = true
        let task = Task { [weak self] in
            self?.isLoading = true
            for await result in library.results(query) {
                guard !Task.isCancelled, let self else { return }
                self.apply(result)
            }
        }
        feed = task
        feedCancellable = AnyCancellable { task.cancel() }
    }

    private func apply(_ result: Result<[Element], MusicLibraryError>) {
        switch result {
        case .success(let elements):
            self.elements = elements
            error = nil
        case .failure(let error):
            self.error = error
        }
        isLoading = false
        awaitingFirstResult = false
        let waiting = waiters
        waiters = []
        waiting.forEach { $0.resume() }
    }

    /// Someone who denied access can turn it on in Settings and come back; fetch again then,
    /// since nothing else would tell this loader.
    private func recoverFromDeniedAccess() {
        guard case .unauthorized = error, library?.authorizationStatus == .authorized else { return }
        start()
    }

    private static func identity(of library: any MusicLibraryProtocol) -> ObjectIdentifier {
        type(of: library) is AnyClass ? ObjectIdentifier(library as AnyObject) : ObjectIdentifier(type(of: library))
    }
}
