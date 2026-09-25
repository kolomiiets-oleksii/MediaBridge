import Foundation
import MediaPlayer

/// Primary interface for accessing the device's music library.
///
/// `MusicLibrary` provides a high-level API for fetching songs and media items from the user's
/// music library. It coordinates authorization requests and service layer queries, handling
/// permission checks automatically before returning results.
///
/// ## Architecture
/// This class acts as a facade over two internal systems:
/// - Authorization management via `AuthorizationManagerProtocol`
/// - Media queries via `MusicLibraryServiceProtocol`
///
/// ## Usage
///
/// Create an instance and use it directly:
/// ```swift
/// let library = MusicLibrary()
/// let songs = try await library.songs()
/// let artist = try await library.mediaItems(ofType: .music, matching: .artist("Taylor Swift"), .contains, groupingType: .album)
/// ```
///
/// For SwiftUI apps, inject the library via environment values:
/// ```swift
/// extension EnvironmentValues {
///     @Entry var library: MusicLibraryProtocol = MusicLibrary()
/// }
///
/// struct ContentView: View {
///     @Environment(\.library) var library
///
///     var body: some View {
///         VStack {
///             // Optional: fetches prompt on their own; this just picks the moment
///             if library.authorizationStatus == .notDetermined {
///                 Button("Allow Music Library Access") {
///                     Task { try? await library.requestAuthorization() }
///                 }
///             }
///         }
///         .task {
///             let songs = try? await library.songs(
///                 sortedBy: \MPMediaItem.skipCount,
///                 order: .reverse
///             )
///         }
///     }
/// }
/// ```
///
/// ## Dependency Injection
/// For testing or custom behavior, inject your implementations:
/// ```swift
/// let yourAuth = YourAuthorizationManager(isAuthorized: true)
/// let yourService = YourMusicLibraryService()
/// let library = MusicLibrary(auth: yourAuth, service: yourService)
/// ```
public final class MusicLibrary: MusicLibraryProtocol {
    private let auth: any AuthorizationManagerProtocol
    private let service: any MusicLibraryServiceProtocol
    private let changeSource: any LibraryChangesProtocol

    public var authorizationStatus: MPMediaLibraryAuthorizationStatus {
        auth.status()
    }

    /// Creates a new music library instance.
    ///
    /// By default, this initializer uses the production implementations (`.live`) for both
    /// authorization management and music library services. Customize via dependency injection
    /// for testing or specialized behavior.
    ///
    /// - Parameters:
    ///   - auth: The authorization manager to handle music library access permissions.
    ///     Defaults to `.live` for production use. Pass a mock implementation for testing.
    ///   - service: The service layer for querying media items.
    ///     Defaults to `.live` for production use. Pass a mock implementation for testing.
    ///   - changes: The source behind ``changes``. Defaults to `.live`, which observes the
    ///     device library.
    ///
    /// ## Examples
    ///
    /// Create a library for production use with default implementations:
    /// ```swift
    /// let library = MusicLibrary()
    /// ```
    ///
    /// Create a library with only a custom authorization manager:
    /// ```swift
    /// let customAuth = MyCustomAuthorizationManager()
    /// let customService = MyCustomMusicLibraryService()
    /// let library = MusicLibrary(auth: customAuth, service: yourService)
    /// ```
    public init(
        auth: any AuthorizationManagerProtocol = .live,
        service: any MusicLibraryServiceProtocol = .live,
        changes: any LibraryChangesProtocol = .live
    ) {
        self.auth = auth
        self.service = service
        self.changeSource = changes
    }

    public var changes: AsyncStream<Date> {
        changeSource.changes()
    }

    // MARK: - Authorization

    @discardableResult
    public func requestAuthorization() async throws -> MPMediaLibraryAuthorizationStatus {
        try await auth.authorize()
    }

    // MARK: - General Media Queries

    public func fetchAll(_ type: MPMediaType, groupingType: MPMediaGrouping) async throws -> [MPMediaItem] {
        try await checkIfAuthorized()
        return try await service.items(MediaQueryRequest(mediaType: type, grouping: groupingType))
    }

    public func mediaItems(
        ofType type: MPMediaType,
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem] {
        try await checkIfAuthorized()
        return try await service.items(
            MediaQueryRequest(mediaType: type, filter: .init(predicate, comparisonType), grouping: groupingType))
    }

    public func mediaItemCollections(
        ofType type: MPMediaType,
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection] {
        try await checkIfAuthorized()
        return try await service.collections(
            MediaQueryRequest(mediaType: type, filter: .init(predicate, comparisonType), grouping: groupingType))
    }

    public func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] {
        try await checkIfAuthorized()
        return try await service.items(request)
    }

    public func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] {
        try await checkIfAuthorized()
        return try await service.collections(request)
    }

    public func itemSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItem>] {
        try await checkIfAuthorized()
        return try await service.itemSections(request)
    }

    public func collectionSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItemCollection>] {
        try await checkIfAuthorized()
        return try await service.collectionSections(request)
    }

    // MARK: - Specific calls

    public func songs<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItem, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItem] {
        try await fetchSorted("songs", sortedBy: sortingKey, order: order) {
            try await self.service.items(MediaQueryRequest(mediaType: .music, grouping: .title))
        }
    }

    public func albums<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await fetchSorted("albums", sortedBy: sortingKey, order: order) {
            try await self.service.collections(MediaQueryRequest(mediaType: .music, grouping: .album))
        }
    }

    public func songs(
        matching predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison
    ) async throws -> [MPMediaItem] {
        return try await mediaItems(ofType: .music, matching: predicate, comparisonType, groupingType: .title)
    }

    public func albums(
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection] {
        return try await mediaItemCollections(ofType: .music, matching: predicate, comparisonType, groupingType: groupingType)
    }

    public func artists<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await fetchSorted("artists", sortedBy: sortingKey, order: order) {
            try await self.service.collections(MediaQueryRequest(mediaType: .music, grouping: .artist))
        }
    }

    public func artists(
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection] {
        return try await mediaItemCollections(ofType: .music, matching: predicate, comparisonType, groupingType: groupingType)
    }

    public func playlists<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaPlaylist, T>?,
        order: SortOrder
    ) async throws -> [MPMediaPlaylist] {
        try await fetchSorted("playlists", sortedBy: sortingKey, order: order) {
            try await self.playlists(from: MediaQueryRequest(grouping: .playlist))
        }
    }

    public func playlists(
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison
    ) async throws -> [MPMediaPlaylist] {
        try await checkIfAuthorized()
        return try await playlists(from: MediaQueryRequest(filter: .init(predicate, comparisonType), grouping: .playlist))
    }

    // MARK: - Private methods

    private func playlists(from request: MediaQueryRequest) async throws -> [MPMediaPlaylist] {
        let collections = try await service.collections(request)
        let playlists = collections.compactMap { $0 as? MPMediaPlaylist }
        if playlists.count != collections.count {
            log.debug("Discarded \(collections.count - playlists.count) non-playlist collections for \(request.description)")
        }
        return playlists
    }

    private func fetchSorted<Element, Value: Comparable>(
        _ label: String,
        sortedBy sortingKey: SortKey<Element, Value>?,
        order: SortOrder,
        fetch: () async throws -> [Element]
    ) async throws -> [Element] {
        #if DEBUG
            let start = Date()
            log.debug("Started fetching and sorting \(label)")
        #endif

        try await checkIfAuthorized()
        let elements = try await fetch()

        #if DEBUG
            log.debug("Fetched \(elements.count) \(label) in \(Date.now.timeIntervalSince(start)) seconds")
        #endif

        guard let sortingKey else { return elements }

        #if DEBUG
            let startSorting = Date()
        #endif

        let sorted = elements.sorted(using: KeyPathComparator(sortingKey, order: order))

        #if DEBUG
            log.debug("Sorted \(elements.count) \(label) in \(Date.now.timeIntervalSince(startSorting)) seconds")
            log.debug("Fetched and sorted \(elements.count) \(label) in \(Date.now.timeIntervalSince(start)) seconds")
        #endif

        return sorted
    }

    private func checkIfAuthorized() async throws {
        let status = authorizationStatus

        guard case .authorized = status else {
            log.debug("Unauthorized with status: \(status.description). Requesting authorization...")
            let statusAfterRequest = try await requestAuthorization()

            guard case .authorized = statusAfterRequest else {
                throw AuthorizationManagerError.unauthorized(statusAfterRequest)
            }

            return
        }
    }
}

// MARK: - Deprecated
extension MusicLibrary {
    @available(*, deprecated, renamed: "mediaItems(ofType:matching:_:groupingType:)", message: "Removed in 1.0.0.")
    public func fetch(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem] {
        return try await mediaItems(ofType: type, matching: predicate, comparisonType, groupingType: groupingType)
    }

    @available(*, deprecated, renamed: "songs()", message: "Removed in 1.0.0.")
    public func fetchSongs<T: Comparable>(
        sortedBy sortingKey: (KeyPath<MPMediaItem, T> & Sendable)?,
        order: SortOrder
    ) async throws -> [MPMediaItem] {
        return try await songs(sortedBy: sortingKey, order: order)
    }

    @available(*, deprecated, renamed: "songs(matching:comparisonType:)", message: "Removed in 1.0.0.")
    public func fetchSong(
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison = .equalTo
    ) async throws -> [MPMediaItem] {
        return try await songs(matching: predicate, comparisonType: comparisonType)
    }
}
