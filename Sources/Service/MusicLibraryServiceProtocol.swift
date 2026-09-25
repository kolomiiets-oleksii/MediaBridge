import MediaPlayer

/// The query layer behind ``MusicLibrary``.
///
/// A service answers ``MediaQueryRequest``s with items or collections. ``MusicLibrary`` builds
/// every public call (songs, albums, artists, playlists, and the generic queries) from these two
/// methods and handles authorization, sorting, and playlist filtering itself, so a custom service
/// only has to run queries.
///
/// Use ``MusicLibraryServiceProtocol/live`` in production. ``MusicLibraryService`` takes its query
/// type as a generic parameter conforming to ``MediaQueryProtocol``: `MPMediaQuery` in production,
/// a mock query in tests.
///
/// ## Example
/// ```swift
/// struct FixtureService: MusicLibraryServiceProtocol {
///     let songs: [MPMediaItem]
///     func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] { songs }
///     func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] { [] }
/// }
///
/// let library = MusicLibrary(service: FixtureService(songs: fixtures))
/// ```
public protocol MusicLibraryServiceProtocol: Sendable {
    /// Returns the media items matching `request`, or an empty array when nothing matches.
    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem]

    /// Returns the collections matching `request`, grouped by `request.grouping`, or an empty
    /// array when nothing matches.
    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection]
}
