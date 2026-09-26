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

    /// Returns the app's playlist with `id`, creating it from `metadata` when it doesn't exist.
    ///
    /// With `metadata` `nil`, only looks the playlist up and returns `nil` when there is none.
    func playlist(id: UUID, creating metadata: PlaylistMetadata?) async throws -> MPMediaPlaylist?

    /// Appends `items` to `playlist`. Only playlists your app created can be changed.
    func add(_ items: [MPMediaItem], to playlist: MPMediaPlaylist) async throws

    /// Adds the Apple Music catalog item with `productID` to the library and returns what was
    /// added: items for a song, collections for an album or playlist.
    func addItem(productID: String) async throws -> [MPMediaEntity]

    /// Appends the Apple Music catalog item with `productID` to `playlist`.
    func add(productID: String, to playlist: MPMediaPlaylist) async throws
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

    /// Throws ``MusicLibraryError/writesUnsupported``, for read-only services.
    public func playlist(id: UUID, creating metadata: PlaylistMetadata?) async throws -> MPMediaPlaylist? {
        throw MusicLibraryError.writesUnsupported
    }

    /// Throws ``MusicLibraryError/writesUnsupported``, for read-only services.
    public func add(_ items: [MPMediaItem], to playlist: MPMediaPlaylist) async throws {
        throw MusicLibraryError.writesUnsupported
    }

    /// Throws ``MusicLibraryError/writesUnsupported``, for read-only services.
    public func addItem(productID: String) async throws -> [MPMediaEntity] {
        throw MusicLibraryError.writesUnsupported
    }

    /// Throws ``MusicLibraryError/writesUnsupported``, for read-only services.
    public func add(productID: String, to playlist: MPMediaPlaylist) async throws {
        throw MusicLibraryError.writesUnsupported
    }
}
