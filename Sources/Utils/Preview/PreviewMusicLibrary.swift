import Foundation
import MediaPlayer

#if DEBUG
    /// A debug-only `MusicLibraryProtocol` implementation for use in SwiftUI previews.
    ///
    /// Pre-populate it with mock data and inject it via the environment:
    /// ```swift
    /// #Preview {
    ///     ContentView()
    ///         .environment(\.library, .accessAuthorized)
    /// }
    /// ```
    /// Use the static factory methods on `MusicLibraryProtocol` (e.g. `.accessAuthorized`,
    /// `.accessDenied`) for common configurations, or construct a custom instance directly.
    /// - Note: `@unchecked Sendable` because the stored `MPMediaItem`,
    ///   `MPMediaItemCollection`, and `MPMediaPlaylist` arrays are not `Sendable`.
    ///   Safety invariant: every stored property is a `let` assigned once during
    ///   initialization, and MediaPlayer's item types are read-only, so no mutation
    ///   crosses an isolation boundary. Remove the annotation once MediaPlayer marks
    ///   these types `Sendable`.
    public final class PreviewMusicLibrary: MusicLibraryProtocol, @unchecked Sendable {
        private let status: MPMediaLibraryAuthorizationStatus
        private let statusAfterRequest: MPMediaLibraryAuthorizationStatus
        private let fetchedAllMedia: [MPMediaItem]
        private let fetchedMedia: [MPMediaItem]
        private let fetchedSongs: [MPMediaItem]
        private let filteredSongs: [MPMediaItem]
        private let filteredAlbums: [MPMediaItemCollection]
        private let filteredArtists: [MPMediaItemCollection]
        private let filteredPlaylists: [MPMediaPlaylist]

        public init(
            status: MPMediaLibraryAuthorizationStatus,
            statusAfterRequest: MPMediaLibraryAuthorizationStatus,
            fetchedAllMedia: [MPMediaItem],
            fetchedMedia: [MPMediaItem],
            fetchedSongs: [MPMediaItem],
            filteredSongs: [MPMediaItem],
            filteredAlbums: [MPMediaItemCollection],
            filteredArtists: [MPMediaItemCollection] = [],
            filteredPlaylists: [MPMediaPlaylist] = []
        ) {
            self.status = status
            self.statusAfterRequest = statusAfterRequest
            self.fetchedAllMedia = fetchedAllMedia
            self.fetchedMedia = fetchedMedia
            self.fetchedSongs = fetchedSongs
            self.filteredSongs = filteredSongs
            self.filteredAlbums = filteredAlbums
            self.filteredArtists = filteredArtists
            self.filteredPlaylists = filteredPlaylists
        }

        public var authorizationStatus: MPMediaLibraryAuthorizationStatus { status }
        public func requestAuthorization() async throws -> MPMediaLibraryAuthorizationStatus { statusAfterRequest }
        public func fetchAll(_ type: MPMediaType, groupingType: MPMediaGrouping) async throws -> [MPMediaItem] { fetchedAllMedia }
        public func mediaItems(
            ofType type: MPMediaType,
            matching predicate: MediaBridge.MediaItemPredicateInfo,
            _ comparisonType: MPMediaPredicateComparison,
            groupingType: MPMediaGrouping
        ) async throws -> [MPMediaItem] { fetchedMedia }
        public func mediaItemCollections(
            ofType type: MPMediaType,
            matching predicate: MediaItemPredicateInfo,
            _ comparisonType: MPMediaPredicateComparison,
            groupingType: MPMediaGrouping
        ) async throws -> [MPMediaItemCollection] { filteredAlbums }

        public func songs<T>(sortedBy sortingKey: SortKey<MPMediaItem, T>?, order: SortOrder) async throws
            -> [MPMediaItem]
        where T: Comparable { fetchedSongs }

        public func songs(matching predicate: MediaBridge.MediaItemPredicateInfo, comparisonType: MPMediaPredicateComparison) async throws
            -> [MPMediaItem]
        { filteredSongs }

        public func albums(
            matching predicate: MediaItemPredicateInfo,
            _ comparisonType: MPMediaPredicateComparison,
            groupingType: MPMediaGrouping
        ) async throws -> [MPMediaItemCollection]
        { filteredAlbums }

        public func albums<T>(sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?, order: SortOrder) async throws
            -> [MPMediaItemCollection]
        where T: Comparable { filteredAlbums }

        public func artists(
            matching predicate: MediaItemPredicateInfo,
            _ comparisonType: MPMediaPredicateComparison,
            groupingType: MPMediaGrouping
        ) async throws -> [MPMediaItemCollection] { filteredArtists }

        public func artists<T>(sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?, order: SortOrder) async throws
            -> [MPMediaItemCollection]
        where T: Comparable { filteredArtists }

        public func playlists(
            matching predicate: MediaItemPredicateInfo,
            _ comparisonType: MPMediaPredicateComparison
        ) async throws -> [MPMediaPlaylist] { filteredPlaylists }

        public func playlists<T>(sortedBy sortingKey: SortKey<MPMediaPlaylist, T>?, order: SortOrder) async throws
            -> [MPMediaPlaylist]
        where T: Comparable { filteredPlaylists }
    }
#endif
