import Foundation
import MediaPlayer

/// The user's music library: queries, playlist writes, and change notifications.
///
/// Fetch typed models with ``fetch(_:)`` and ``sections(_:)``; ``items(_:)`` and
/// ``collections(_:)`` are the low-level queries they build on, returning MediaPlayer types.
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
    ///         songs = (try? await library.fetch(Song.query)) ?? []
    ///     }
    /// }
    /// ```
    var changes: AsyncStream<Date> { get }

    /// Fetches the media items matching a request.
    ///
    /// The low-level query behind ``fetch(_:)``, for when you need MediaPlayer's own types.
    ///
    /// ## Example
    /// ```swift
    /// let jazz = try await library.items(
    ///     MediaQueryRequest(mediaType: .music, filter: .init(.genre("Jazz")), grouping: .title)
    /// )
    /// ```
    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem]

    /// Fetches the collections matching a request, grouped by `request.grouping`.
    ///
    /// The low-level query behind ``fetch(_:)`` for albums, artists, and the other collections.
    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection]

    /// Fetches the items matching a request, split into index sections like the Music app's
    /// A–Z sidebar.
    func itemSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItem>]

    /// Fetches the collections matching a request, split into index sections.
    func collectionSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItemCollection>]

    /// Returns the playlist your app created with `id`, or `nil` when it doesn't exist.
    ///
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted
    ///   after the automatic authorization request
    func playlist(id: UUID) async throws -> Playlist?

    /// Returns the playlist your app created with `id`, creating it from `metadata` the first time.
    ///
    /// Generate the UUID once and store it: the same UUID always returns the same playlist, and
    /// `metadata` is ignored once the playlist exists. The playlist appears in the Music app.
    ///
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted
    ///   after the automatic authorization request, ``MusicLibraryError/playlistUnavailable(_:)``
    ///   if MediaPlayer creates nothing, or MediaPlayer's own error
    ///
    /// ## Example
    /// ```swift
    /// let playlist = try await library.playlist(
    ///     id: mostSkippedID,
    ///     orCreate: PlaylistMetadata(name: "Most Skipped", descriptionText: "Songs I skip")
    /// )
    /// try await library.add(songs, to: playlist)
    /// ```
    func playlist(id: UUID, orCreate metadata: PlaylistMetadata) async throws -> Playlist

    /// Appends `songs` to `playlist`, keeping their order. Does nothing when `songs` is empty.
    ///
    /// Only playlists your app created with ``playlist(id:orCreate:)`` can be changed; MediaPlayer
    /// throws for any other. Songs can't be removed: MediaPlayer has no API for it.
    ///
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted
    ///   after the automatic authorization request, or MediaPlayer's own error
    func add(_ songs: [Song], to playlist: Playlist) async throws

    /// Adds an Apple Music catalog song, album, or playlist to the user's library and returns the
    /// songs it added, in album or playlist order.
    ///
    /// The user needs Apple Music with Sync Library turned on: check MusicKit's
    /// `MusicSubscription.current.hasCloudLibraryEnabled` first. Nothing can remove songs from the
    /// library afterwards, so add only what the user asked for.
    ///
    /// - Parameter productID: The Apple Music catalog ID, such as a song's ``Song/playbackStoreID``
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted
    ///   after the automatic authorization request, or MediaPlayer's own error
    @discardableResult
    func add(productID: String) async throws -> [Song]

    /// Appends an Apple Music catalog song to a playlist your app created.
    ///
    /// Needs the same Apple Music capability as ``add(productID:)``.
    ///
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is still not granted
    ///   after the automatic authorization request, or MediaPlayer's own error
    func add(productID: String, to playlist: Playlist) async throws
}
