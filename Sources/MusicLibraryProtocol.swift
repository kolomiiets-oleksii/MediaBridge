import Foundation
import MediaPlayer

/// Protocol for fetching media items from the device's music library.
///
/// Every fetch checks authorization first and, if access hasn't been granted yet, requests it.
/// Call ``requestAuthorization()`` up front only to control when the system prompt appears.
public protocol MusicLibraryProtocol: Sendable {
    /// The current music library authorization status. Reading it never shows a prompt.
    ///
    /// ## Example
    /// ```swift
    /// switch library.authorizationStatus {
    /// case .authorized:
    ///     // Safe to fetch music library items
    /// case .denied, .restricted:
    ///     // Show error message to user
    /// case .notDetermined:
    ///     // Prompt user for authorization
    /// @unknown default:
    ///     // Handle future status values
    /// }
    /// ```
    var authorizationStatus: MPMediaLibraryAuthorizationStatus { get }

    /// Requests music library access authorization from the user.
    ///
    /// Shows the system prompt if the user hasn't decided yet. Fetch methods call this
    /// automatically, so use it directly only to choose when the prompt appears.
    ///
    /// - Returns: `.authorized`; any other outcome throws
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` with the resulting status
    ///   when access is denied or restricted
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try await library.requestAuthorization()
    /// } catch AuthorizationManagerError.unauthorized(let status) {
    ///     // .denied or .restricted: point the user to Settings
    /// }
    /// ```
    @discardableResult
    func requestAuthorization() async throws -> MPMediaLibraryAuthorizationStatus

    /// Yields the library's modification date each time the music library changes.
    ///
    /// Re-run your queries when it yields; previously fetched items may be stale. Each access
    /// starts a new observation, which ends when you stop iterating. Changes only arrive once
    /// access is authorized.
    ///
    /// ## Example
    /// ```swift
    /// .task {
    ///     for await _ in library.changes {
    ///         songs = (try? await library.songs()) ?? []
    ///     }
    /// }
    /// ```
    var changes: AsyncStream<Date> { get }

    /// Fetches all media items of a specific type, grouped by `groupingType`.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (typically `.music`)
    ///   - groupingType: How to group the returned items
    /// - Returns: Array of all media items matching the specified type
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let allSongs = try await library.fetchAll(.music, groupingType: .title)
    /// ```
    func fetchAll(
        _ type: MPMediaType,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem]

    /// Fetches all songs, optionally sorted by a key path.
    ///
    /// - Parameters:
    ///   - sortingKey: Optional key path to sort by (e.g., `\MPMediaItem.dateAdded`, `\MPMediaItem.skipCount`).
    ///     If `nil`, results keep library order and `order` is ignored.
    ///   - order: The sort order (`.forward` for ascending, `.reverse` for descending)
    /// - Returns: Array of songs, sorted if a key is provided
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Examples
    /// Fetch unsorted songs:
    /// ```swift
    /// let songs = try await library.songs()
    /// ```
    ///
    /// Fetch songs sorted by play count:
    /// ```swift
    /// let sorted = try await library.songs(
    ///     sortedBy: \MPMediaItem.playCount,
    ///     order: .forward
    /// )
    /// ```
    ///
    /// Fetch songs sorted by skip count:
    /// ```swift
    /// let frequent = try await library.songs(
    ///     sortedBy: \MPMediaItem.skipCount,
    ///     order: .reverse
    /// )
    /// ```
    func songs<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItem, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItem]

    /// Fetches songs matching a predicate, such as an artist, title, or genre.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter songs (e.g., `.persistentID(12345)`, `.artist("Beatles")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    /// - Returns: Array of matching songs
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let songs = try await library.songs(
    ///     matching: .artist("Taylor Swift"),
    ///     comparisonType: .contains
    /// )
    /// ```
    func songs(
        matching predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison
    ) async throws -> [MPMediaItem]

    /// Fetches media items of any type (music, podcasts, audiobooks) matching a predicate.
    ///
    /// The most general item query; the song, album, and artist methods are shortcuts over it.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (`.music`, `.podcast`, etc.)
    ///   - predicate: The predicate to filter items
    ///   - comparisonType: How to compare the predicate value
    ///   - groupingType: How to group the returned items
    /// - Returns: Array of media items matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let items = try await library.mediaItems(
    ///     ofType: .music,
    ///     matching: .genre("Rock"),
    ///     .contains,
    ///     groupingType: .album
    /// )
    /// ```
    func mediaItems(
        ofType type: MPMediaType,
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem]

    /// Fetches media item collections of any type matching a predicate.
    ///
    /// The collection counterpart of ``mediaItems(ofType:matching:_:groupingType:)``.
    ///
    /// - Parameters:
    ///   - type: The type of media to fetch (`.music`, `.podcast`, etc.)
    ///   - predicate: The predicate to filter items
    ///   - comparisonType: How to compare the predicate value
    ///   - groupingType: How to group the returned collections
    /// - Returns: Array of media item collections matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let albums = try await library.mediaItemCollections(
    ///     ofType: .music,
    ///     matching: .artist("Taylor Swift"),
    ///     .contains,
    ///     groupingType: .album
    /// )
    /// ```
    func mediaItemCollections(
        ofType type: MPMediaType,
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection]

    /// Fetches music albums matching a predicate.
    ///
    /// Shortcut for ``mediaItemCollections(ofType:matching:_:groupingType:)`` with `.music`.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter albums (e.g., `.albumArtist("The Beatles")`, `.genre("Rock")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    ///   - groupingType: How to group the returned collections (typically `.album` or `.albumArtist`)
    /// - Returns: Array of album collections matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let beatlesAlbums = try await library.albums(
    ///     matching: .albumArtist("The Beatles"),
    ///     .equalTo,
    ///     groupingType: .album
    /// )
    /// ```
    func albums(
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection]

    /// Fetches all albums, optionally sorted by a key path.
    ///
    /// - Parameters:
    ///   - sortingKey: Optional key path to sort by (e.g., `\MPMediaItemCollection.count`).
    ///     If `nil`, results keep library order and `order` is ignored.
    ///   - order: The sort order (`.forward` for ascending, `.reverse` for descending)
    /// - Returns: Array of albums, sorted if a key is provided
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Examples
    /// Fetch albums sorted by track count:
    /// ```swift
    /// let albums = try await library.albums(
    ///     sortedBy: \MPMediaItemCollection.count,
    ///     order: .reverse
    /// )
    /// ```
    ///
    /// Fetch unsorted albums:
    /// ```swift
    /// let albums = try await library.albums()
    /// ```
    func albums<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection]

    // MARK: - Artists

    /// Fetches music artists matching a predicate.
    ///
    /// Shortcut for ``mediaItemCollections(ofType:matching:_:groupingType:)`` with `.music`.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter artists (e.g., `.artist("The Beatles")`, `.genre("Rock")`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    ///   - groupingType: How to group the returned collections (typically `.artist`)
    /// - Returns: Array of artist collections matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let beatles = try await library.artists(
    ///     matching: .artist("The Beatles"),
    ///     .contains,
    ///     groupingType: .artist
    /// )
    /// ```
    func artists(
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection]

    /// Fetches all artists, optionally sorted by a key path.
    ///
    /// - Parameters:
    ///   - sortingKey: Optional key path to sort by (e.g., `\MPMediaItemCollection.count`).
    ///     If `nil`, results keep library order and `order` is ignored.
    ///   - order: The sort order (`.forward` for ascending, `.reverse` for descending)
    /// - Returns: Array of artists, sorted if a key is provided
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Examples
    /// Fetch artists sorted by track count:
    /// ```swift
    /// let artists = try await library.artists(
    ///     sortedBy: \MPMediaItemCollection.count,
    ///     order: .reverse
    /// )
    /// ```
    ///
    /// Fetch unsorted artists:
    /// ```swift
    /// let artists = try await library.artists()
    /// ```
    func artists<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection]

    // MARK: - Playlists

    /// Fetches playlists matching a predicate.
    ///
    /// Returns the concrete `MPMediaPlaylist` type, giving access to playlist-specific properties
    /// such as `name`, `playlistAttributes` (smart/genius/onTheGo), `descriptionText`, and `seedItems`.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to filter playlists (e.g., `.playlistName("Favorites")`, `.playlistID(123)`)
    ///   - comparisonType: How to compare the predicate value (`.equalTo`, `.contains`, etc.)
    /// - Returns: Array of playlists matching the criteria
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let results = try await library.playlists(matching: .playlistName("Chill"), .contains)
    /// ```
    func playlists(
        matching predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison
    ) async throws -> [MPMediaPlaylist]

    /// Fetches all playlists, optionally sorted by a key path.
    ///
    /// Returns `MPMediaPlaylist`, so playlist-specific properties are available.
    ///
    /// - Parameters:
    ///   - sortingKey: Optional key path to sort by (e.g., `\MPMediaPlaylist.name`).
    ///     If `nil`, results keep library order and `order` is ignored.
    ///   - order: The sort order (`.forward` for ascending, `.reverse` for descending)
    /// - Returns: Array of playlists, sorted if a key is provided
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Examples
    /// Fetch playlists sorted by name:
    /// ```swift
    /// let playlists = try await library.playlists(
    ///     sortedBy: \MPMediaPlaylist.name,
    ///     order: .forward
    /// )
    /// ```
    ///
    /// Fetch unsorted playlists:
    /// ```swift
    /// let playlists = try await library.playlists()
    /// ```
    func playlists<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaPlaylist, T>?,
        order: SortOrder
    ) async throws -> [MPMediaPlaylist]

}

extension MusicLibraryProtocol {
    /// A stream that never yields, for conformers that don't observe the library.
    public var changes: AsyncStream<Date> { SilentLibraryChanges().changes() }

    // MARK: - Deprecated

    @available(*, deprecated, renamed: "songs(sortedBy:order:)")
    public func fetchSongs<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItem, T>?,
        order: SortOrder
    ) async throws -> [MPMediaItem] {
        try await songs(sortedBy: sortingKey, order: order)
    }

    /// Fetches a specific song with a default comparison type.
    ///
    /// Convenience method that fetches a song matching the provided predicate,
    /// using `.equalTo` as the default comparison type.
    ///
    /// - Parameters:
    ///   - predicate: The predicate to identify the song (e.g., `.persistentID(12345)`, `.artist("Beatles")`)
    ///   - comparisonType: How to compare the predicate value (defaults to `.equalTo`)
    /// - Returns: Array of matching songs (typically contains 0 or 1 item)
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// // Using default .equalTo comparison
    /// let songs = try await library.fetchSong(with: .persistentID(12345))
    /// ```
    @available(*, deprecated, renamed: "songs(matching:comparisonType:)")
    public func fetchSong(
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison = .equalTo
    ) async throws -> [MPMediaItem] {
        try await songs(matching: predicate, comparisonType: comparisonType)
    }

    @available(*, deprecated, renamed: "mediaItems(ofType:matching:_:groupingType:)")
    public func fetch(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem] {
        try await mediaItems(ofType: type, matching: predicate, comparisonType, groupingType: groupingType)
    }
}

extension MusicLibraryProtocol {
    /// Fetches all songs without sorting.
    ///
    /// Equivalent to `songs(sortedBy: nil, order: .forward)`.
    ///
    /// - Returns: All songs, in library order
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let allSongs = try await library.songs()
    /// ```
    public func songs() async throws -> [MPMediaItem] {
        return try await songs(sortedBy: SortKey<MPMediaItem, Never>?.none, order: .forward)
    }

    /// Fetches all albums without sorting.
    ///
    /// Equivalent to `albums(sortedBy: nil, order: .forward)`.
    ///
    /// - Returns: All albums, in library order
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let allAlbums = try await library.albums()
    /// ```
    public func albums() async throws -> [MPMediaItemCollection] {
        return try await albums(sortedBy: SortKey<MPMediaItemCollection, Never>?.none, order: .forward)
    }

    /// Fetches all artists without sorting.
    ///
    /// Equivalent to `artists(sortedBy: nil, order: .forward)`.
    ///
    /// - Returns: All artists, in library order
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let allArtists = try await library.artists()
    /// ```
    public func artists() async throws -> [MPMediaItemCollection] {
        return try await artists(sortedBy: SortKey<MPMediaItemCollection, Never>?.none, order: .forward)
    }

    /// Fetches all playlists without sorting.
    ///
    /// Equivalent to `playlists(sortedBy: nil, order: .forward)`.
    ///
    /// - Returns: All playlists, in library order
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let allPlaylists = try await library.playlists()
    /// ```
    public func playlists() async throws -> [MPMediaPlaylist] {
        return try await playlists(sortedBy: SortKey<MPMediaPlaylist, Never>?.none, order: .forward)
    }

    // MARK: - Deprecated

    /// Fetches all songs without sorting.
    ///
    /// Convenience method that fetches all songs with default behavior (unsorted, forward order).
    /// Equivalent to calling `fetchSongs(sortedBy: nil, order: .forward)`.
    ///
    /// - Returns: Array of all songs in the library, unsorted
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted after the automatic authorization request
    ///
    /// ## Example
    /// ```swift
    /// let allSongs = try await library.fetchSongs()
    /// ```
    @available(*, deprecated, renamed: "songs()")
    public func fetchSongs() async throws -> [MPMediaItem] {
        return try await songs()
    }
}
