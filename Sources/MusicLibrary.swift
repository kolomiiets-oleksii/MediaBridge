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
/// let songs = try await library.fetch(Song.query.filter(\.artist, .contains("Taylor Swift")))
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
///             let songs = try? await library.fetch(Song.query.sorted(by: \.skipCount, .reverse))
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

    // MARK: - Queries

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

    // MARK: - Playlist Writes

    public func playlist(id: UUID) async throws -> Playlist? {
        try await checkIfAuthorized()
        return try await service.playlist(id: id, creating: nil).map(Playlist.init)
    }

    public func playlist(id: UUID, orCreate metadata: PlaylistMetadata) async throws -> Playlist {
        try await checkIfAuthorized()
        guard let playlist = try await service.playlist(id: id, creating: metadata) else {
            throw MusicLibraryError.playlistUnavailable(id)
        }
        return Playlist(playlist)
    }

    public func add(_ songs: [Song], to playlist: Playlist) async throws {
        try await checkIfAuthorized()
        guard !songs.isEmpty else { return }
        try await service.add(songs.map(\.mediaItem), to: playlist.mediaPlaylist)
    }

    @discardableResult
    public func add(productID: String) async throws -> [Song] {
        try await checkIfAuthorized()
        return try await service.addItem(productID: productID).flatMap { entity -> [Song] in
            switch entity {
            case let item as MPMediaItem: [Song(item)]
            case let collection as MPMediaItemCollection: collection.items.map(Song.init)
            default: []
            }
        }
    }

    public func add(productID: String, to playlist: Playlist) async throws {
        try await checkIfAuthorized()
        try await service.add(productID: productID, to: playlist.mediaPlaylist)
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
