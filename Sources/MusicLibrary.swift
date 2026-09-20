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
/// It ensures users have permission to access the music library before making queries.
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
///             // Optional: Request authorization if not yet determined
///             if library.authorizationStatus == .notDetermined {
///                 Button("Request Music Library Access") {
///                     Task {
///                         try await library.requestAuthorization()
///                     }
///                 }
///             }
///             // Use library here
///         }
///         .task {
///             let songs = try await library.songs(
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
        service: any MusicLibraryServiceProtocol = .live
    ) {
        self.auth = auth
        self.service = service
    }

    // MARK: - Authorization

    /// Requests music library access authorization from the user.
    ///
    /// Presents the system authorization prompt if the user hasn't yet decided.
    /// If authorization is already determined, returns the current status without prompting.
    /// Delegates to the underlying ``AuthorizationManagerProtocol`` implementation.
    ///
    /// - Returns: The authorization status after the request
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if the request fails or is denied
    @discardableResult
    public func requestAuthorization() async throws -> MPMediaLibraryAuthorizationStatus {
        try await auth.authorize()
    }

    // MARK: - General Media Queries

    /// Fetches all media items of a specific type.
    ///
    /// Retrieves all media items matching the specified type from the device's music library.
    /// Automatically checks authorization status before making the query.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (typically `.music`)
    ///   - groupingType: How to group the returned items (`.title`, `.album`, `.artist`, etc.)
    /// - Returns: Array of all media items matching the specified type
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    public func fetchAll(_ type: MPMediaType, groupingType: MPMediaGrouping) async throws -> [MPMediaItem] {
        try await checkIfAuthorized()
        return try await service.fetchAll(type, groupingType: groupingType)
    }

    /// Fetches media items of a specific type matching a predicate.
    ///
    /// Queries the music library for items matching the provided type and predicate.
    /// This is the most flexible method, allowing you to fetch any media type (music, podcasts, audiobooks)
    /// with custom filtering and grouping. Automatically checks authorization before querying.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (`.music`, `.podcast`, etc.)
    ///   - predicate: The predicate to filter items (e.g., `.artist("Taylor Swift")`, `.genre("Rock")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    ///   - groupingType: How to group the returned items
    /// - Returns: Array of media items matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    public func mediaItems(
        ofType type: MPMediaType,
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem] {
        try await checkIfAuthorized()
        return try await service.fetch(type, with: predicate, comparisonType: comparisonType, groupingType: groupingType)
    }

    /// Fetches media item collections of a specific type matching a predicate.
    ///
    /// Queries the music library for item collections matching the provided type and predicate.
    /// Returns grouped results (e.g., albums, artists) rather than individual items.
    /// Automatically checks authorization before querying.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (`.music`, `.podcast`, etc.)
    ///   - predicate: The predicate to filter collections (e.g., `.albumArtist("The Beatles")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    ///   - groupingType: How to group the returned collections (typically `.album` or `.albumArtist`)
    /// - Returns: Array of media item collections matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    public func mediaItemCollections(
        ofType type: MPMediaType,
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection] {
        try await checkIfAuthorized()
        return try await service.fetchCollections(type, with: predicate, comparisonType: comparisonType, groupingType: groupingType)
    }

    // MARK: - Specific calls

    public func songs<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItem, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItem] {
        try await fetchSorted("songs", sortedBy: sortingKey, order: order) {
            try await self.service.fetchAll(.music, groupingType: .title)
        }
    }

    public func albums<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await fetchSorted("albums", sortedBy: sortingKey, order: order) {
            try await self.service.fetchAllCollections(.music, groupingType: .album)
        }
    }

    public func songs(
        matching predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison
    ) async throws -> [MPMediaItem] {
        return try await mediaItems(ofType: .music, matching: predicate, comparisonType, groupingType: .title)
    }

    /// Fetches album collections matching a predicate.
    ///
    /// Convenience method for fetching music albums grouped by the specified grouping type.
    /// This is a specialized version of ``mediaItemCollections(ofType:matching:_:groupingType:)``
    /// that's pre-configured for music albums.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter albums (e.g., `.albumArtist("The Beatles")`, `.genre("Rock")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    ///   - groupingType: How to group the returned collections (typically `.album` or `.albumArtist`)
    /// - Returns: Array of album collections matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    ///
    /// ## Example
    /// ```swift
    /// let library = MusicLibrary()
    /// let beatlesAlbums = try await library.albums(
    ///     matching: .albumArtist("The Beatles"),
    ///     .equalTo,
    ///     groupingType: .album
    /// )
    /// ```
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
            try await self.service.fetchAllCollections(.music, groupingType: .artist)
        }
    }

    /// Fetches artist collections matching a predicate.
    ///
    /// Convenience method for fetching music artists grouped by the specified grouping type.
    /// This is a specialized version of ``mediaItemCollections(ofType:matching:_:groupingType:)``
    /// that's pre-configured for music artists.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter artists (e.g., `.artist("The Beatles")`, `.genre("Rock")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    ///   - groupingType: How to group the returned collections (typically `.artist` or `.albumArtist`)
    /// - Returns: Array of artist collections matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    ///
    /// ## Example
    /// ```swift
    /// let library = MusicLibrary()
    /// let artists = try await library.artists(
    ///     matching: .artist("The Beatles"),
    ///     .equalTo,
    ///     groupingType: .artist
    /// )
    /// ```
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
            try await self.service.fetchAllPlaylists()
        }
    }

    /// Fetches playlists matching a predicate.
    ///
    /// Convenience method for fetching playlists by name, ID, or other filterable property.
    /// Returns the concrete `MPMediaPlaylist` type for full access to playlist-specific properties
    /// such as `name`, `playlistAttributes`, `descriptionText`, and `seedItems`.
    ///
    /// Artwork is available via `playlist.representativeItem?.artwork` — the cover art of
    /// the first track in the playlist, which is how the system Music app surfaces it.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter playlists (e.g., `.playlistName("Favorites")`, `.playlistID(123)`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    /// - Returns: Array of playlists matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    ///
    /// ## Example
    /// ```swift
    /// let library = MusicLibrary()
    /// let chillPlaylists = try await library.playlists(
    ///     matching: .playlistName("Chill"),
    ///     .contains
    /// )
    /// for playlist in chillPlaylists {
    ///     let artwork = playlist.representativeItem?.artwork
    ///     let isSmartPlaylist = playlist.playlistAttributes.contains(.smart)
    /// }
    /// ```
    public func playlists(
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison
    ) async throws -> [MPMediaPlaylist] {
        try await checkIfAuthorized()
        return try await service.fetchPlaylists(with: predicate, comparisonType: comparisonType)
    }

    // MARK: - Private methods

    /// Checks authorization, runs the given fetch, and applies the optional sort key.
    ///
    /// Shared by every `sortedBy:order:` method so authorization, sorting, and the
    /// debug timing logs behave identically across songs, albums, artists, and playlists.
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
    @available(*, deprecated, renamed: "mediaItems(ofType:matching:_:groupingType:)")
    public func fetch(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem] {
        return try await mediaItems(ofType: type, matching: predicate, comparisonType, groupingType: groupingType)
    }

    @available(*, deprecated, renamed: "songs()")
    public func fetchSongs<T: Comparable>(
        sortedBy sortingKey: (KeyPath<MPMediaItem, T> & Sendable)?,
        order: SortOrder
    ) async throws -> [MPMediaItem] {
        return try await songs(sortedBy: sortingKey, order: order)
    }

    @available(*, deprecated, renamed: "songs(matching:comparisonType:)")
    public func fetchSong(
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison = .equalTo
    ) async throws -> [MPMediaItem] {
        return try await songs(matching: predicate, comparisonType: comparisonType)
    }
}
