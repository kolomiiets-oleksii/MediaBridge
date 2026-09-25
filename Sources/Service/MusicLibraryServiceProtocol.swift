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

    /// Returns the items matching `request` split into index sections.
    func itemSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItem>]

    /// Returns the collections matching `request` split into index sections.
    func collectionSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItemCollection>]
}

extension MusicLibraryServiceProtocol {
    /// Groups ``items(_:)`` by the first letter of their title for the request's grouping.
    public func itemSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItem>] {
        MediaSection.alphabetical(try await items(request), grouping: request.grouping)
    }

    /// Groups ``collections(_:)`` by the first letter of their title for the request's grouping.
    public func collectionSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItemCollection>] {
        MediaSection.alphabetical(try await collections(request), grouping: request.grouping)
    }
}
