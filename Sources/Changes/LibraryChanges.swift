import Foundation
import MediaPlayer

/// A source of music library change events.
///
/// ``MusicLibrary`` exposes these as ``MusicLibraryProtocol/changes``. Use
/// ``LibraryChangesProtocol/live`` in production and a custom source in tests.
public protocol LibraryChangesProtocol: Sendable {
    /// A new stream that yields the library's modification date each time the library changes.
    ///
    /// Each call starts its own observation, which ends when the consumer stops iterating.
    func changes() -> AsyncStream<Date>
}

/// The parts of `MPMediaLibrary` that change observation needs.
public protocol MediaLibraryChangeTracking: AnyObject {
    var lastModifiedDate: Date { get }
    func beginGeneratingLibraryChangeNotifications()
    func endGeneratingLibraryChangeNotifications()
}

extension MPMediaLibrary: MediaLibraryChangeTracking {}

extension LibraryChangesProtocol where Self == LiveLibraryChanges {
    /// Observes `MPMediaLibrary.default()` through the default notification center.
    public static var live: Self { LiveLibraryChanges() }
}

/// Observes `MPMediaLibraryDidChangeNotification` and yields the library's `lastModifiedDate`.
///
/// Notifications only arrive once the user has authorized music library access.
public struct LiveLibraryChanges: LibraryChangesProtocol {
    private let center: NotificationCenter
    private let library: @Sendable () -> TrackedLibrary

    /// - Parameters:
    ///   - center: The notification center that delivers `MPMediaLibraryDidChange`.
    ///   - library: Resolved when ``changes()`` is first observed, so creating a live
    ///     ``MusicLibrary`` doesn't touch MediaPlayer.
    public init(
        center: NotificationCenter = .default,
        library: @autoclosure @escaping @Sendable () -> any MediaLibraryChangeTracking = MPMediaLibrary.default()
    ) {
        self.center = center
        self.library = { TrackedLibrary(library()) }
    }

    public func changes() -> AsyncStream<Date> {
        let (stream, continuation) = AsyncStream<Date>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let library = library()
        let observer = ObserverToken(
            center.addObserver(forName: .MPMediaLibraryDidChange, object: nil, queue: nil) { _ in
                continuation.yield(library.lastModifiedDate)
            })
        library.beginGeneratingLibraryChangeNotifications()
        continuation.onTermination = { [center] _ in
            center.removeObserver(observer.token)
            library.endGeneratingLibraryChangeNotifications()
        }
        return stream
    }
}

// MediaPlayer's library object isn't `Sendable`; its change-tracking calls are thread-safe.
private struct TrackedLibrary: @unchecked Sendable {
    private let base: any MediaLibraryChangeTracking
    init(_ base: any MediaLibraryChangeTracking) { self.base = base }

    var lastModifiedDate: Date { base.lastModifiedDate }
    func beginGeneratingLibraryChangeNotifications() { base.beginGeneratingLibraryChangeNotifications() }
    func endGeneratingLibraryChangeNotifications() { base.endGeneratingLibraryChangeNotifications() }
}

private struct ObserverToken: @unchecked Sendable {
    let token: any NSObjectProtocol
    init(_ token: any NSObjectProtocol) { self.token = token }
}

struct SilentLibraryChanges: LibraryChangesProtocol {
    func changes() -> AsyncStream<Date> {
        AsyncStream { _ in }
    }
}
