import MediaPlayer

/// Protocol for querying media items from the music library.
///
/// This protocol defines the service layer interface for fetching media items with flexible filtering and grouping.
/// It is primarily used by `MusicLibrary` for the concrete implementation, but can be injected for testing or custom implementations.
///
/// ## Usage
/// The protocol is designed for dependency injection:
/// - Use ``MusicLibraryServiceProtocol/live`` in production
/// - Pass mock implementations in tests
/// - Implement your own conforming type for custom behavior
///
/// ## Generic Types
///
/// The protocol defines two associated types for flexibility:
///
/// **Error Type (`E`):** Allows concrete implementations to define their own error types,
/// enabling type-safe error handling specific to each implementation.
///
/// **Query Type (`Q`):** Allows implementations to use different query types conforming to
/// `MediaQueryProtocol`. This enables using `MPMediaQuery` in production and mock queries in tests.
///
/// ## Example
///
/// Using with a mock query for testing:
/// ```swift
/// let service: any MusicLibraryServiceProtocol = MusicLibraryService<MockMediaQueryWithTwoItems>()
/// let songs = try await service.fetchAll(.music, groupingType: .album)
/// ```
public protocol MusicLibraryServiceProtocol: Sendable {
    associatedtype Q: MediaQueryProtocol

    // MARK: - Media Items
    
    /// Fetches all media items of a specific type with optional grouping.
    ///
    /// Retrieves all media items matching the specified media type from the music library.
    /// Results can be grouped by title, album, artist, or other criteria.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (typically `.music`)
    ///   - groupingType: How to organize the returned items
    /// - Returns: Array of media items matching the type
    /// - Throws: An error of specific type if the query fails 
    ///
    /// ## Example
    /// ```swift
    /// let items = try await service.fetchAll(.music, groupingType: .album)
    /// ```
    func fetchAll(
        _ type: MPMediaType,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem]

    /// Fetches media items matching a predicate with optional filtering.
    ///
    /// Queries the music library for items that match the provided predicate and media type.
    /// The comparison type determines how the predicate is matched.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (typically `.music`)
    ///   - predicate: The predicate to filter items
    ///   - comparisonType: How to compare the predicate value (e.g., `.equalTo`, `.contains`)
    ///   - groupingType: How to organize the returned items
    /// - Returns: Array of media items matching the predicate
    /// - Throws: An error of specific type if the query fails
    ///
    /// ## Example
    /// ```swift
    /// let items = try await service.fetch(
    ///     .music,
    ///     with: .artist("Taylor Swift"),
    ///     comparisonType: .contains,
    ///     groupingType: .album
    /// )
    /// ```
    func fetch(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem]
    
    // MARK: - Media Collections

    /// Fetches all media collections of a specific type with optional grouping.
    ///
    /// Retrieves all collections matching the specified media type from the music library.
    /// Results can be grouped by album, artist, or other criteria.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (typically `.music`)
    ///   - groupingType: How to organize the returned collections
    /// - Returns: Array of media item collections matching the type
    /// - Throws: An error of specific type if the query fails
    ///
    /// ## Example
    /// ```swift
    /// let albums = try await service.fetchAllCollections(.music, groupingType: .album)
    /// ```
    func fetchAllCollections(
        _ type: MPMediaType,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection]

    /// Fetches media collections matching a predicate with optional filtering.
    ///
    /// Queries the music library for collections that match the provided predicate and media type.
    /// The comparison type determines how the predicate is matched.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (typically `.music`)
    ///   - predicate: The predicate to filter collections
    ///   - comparisonType: How to compare the predicate value (e.g., `.equalTo`, `.contains`)
    ///   - groupingType: How to organize the returned collections
    /// - Returns: Array of media item collections matching the predicate
    /// - Throws: An error of specific type if the query fails
    ///
    /// ## Example
    /// ```swift
    /// let albums = try await service.fetchCollections(
    ///     .music,
    ///     with: .albumArtist("The Beatles"),
    ///     comparisonType: .equalTo,
    ///     groupingType: .album
    /// )
    /// ```
    func fetchCollections(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection]

    // MARK: - Playlists

    /// Fetches all playlists from the music library.
    ///
    /// Retrieves all playlists and returns them as their concrete `MPMediaPlaylist` type,
    /// giving access to playlist-specific properties such as `name`, `playlistAttributes`, and `seedItems`.
    ///
    /// - Returns: Array of all playlists in the library
    /// - Throws: An error of specific type if the query fails
    func fetchAllPlaylists() async throws -> [MPMediaPlaylist]

    /// Fetches playlists matching a predicate.
    ///
    /// Queries the music library for playlists matching the provided predicate.
    /// Use `.playlistName(_:)` or `.playlistID(_:)` as the predicate.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter playlists (e.g., `.playlistName("Favorites")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    /// - Returns: Array of playlists matching the criteria
    /// - Throws: An error of specific type if the query fails
    func fetchPlaylists(
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison
    ) async throws -> [MPMediaPlaylist]
}


