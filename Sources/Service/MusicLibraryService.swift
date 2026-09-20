import MediaPlayer

/// Factory extension for creating a live instance of `MusicLibraryService`.
extension MusicLibraryServiceProtocol where Self == MusicLibraryService<MPMediaQuery>, E == MusicLibraryServiceError {
    /// Returns a live instance of the default `MusicLibraryService` implementation.
    ///
    /// Use this property in production code to get the standard service implementation:
    /// ```swift
    /// let library = MusicLibrary(service: .live)
    /// ```
    ///
    /// For testing, pass mock implementations conforming to ``MusicLibraryServiceProtocol`` instead.
    public static var live: Self { MusicLibraryService() }
}

/// The production implementation of `MusicLibraryServiceProtocol`.
///
/// This class provides the concrete implementation for querying the music library using Apple's `MPMediaQuery` and `MPMediaPredicate` APIs.
/// It is the default service used by `MusicLibrary` for all media item queries.
///
/// ## Instantiation
/// Use the `.live` factory property to get the default implementation:
/// ```swift
/// let library = MusicLibrary(service: .live)
/// ```
///
/// For testing or custom implementations, conform to ``MusicLibraryServiceProtocol`` and inject your implementation.
public final class MusicLibraryService<T: MediaQueryProtocol>: MusicLibraryServiceProtocol, Sendable {
    public typealias E = MusicLibraryServiceError
    public typealias Q = T

    // MARK: - MusicLibraryServiceProtocol Implementation

    /// Fetches media items matching a predicate with default parameters.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetch(_:with:comparisonType:groupingType:)`` with default comparison type (`.equalTo`)
    /// and default grouping type (`.title`). Combines the media type predicate with the user-provided predicate.
    public func fetch(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison = .equalTo,
        groupingType: MPMediaGrouping = .title
    ) async throws -> [MPMediaItem] {
        guard let items = query(type, withFilter: predicate, comparisonType, groupingType).items else {
            throw E.noItemFound(predicate)
        }
        return items
    }

    /// Fetches all media items of a specific type with grouping.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchAll(_:groupingType:)`` that retrieves all items of the specified type
    /// without additional filtering, organized by the specified grouping type.
    public func fetchAll(
        _ type: MPMediaType,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem] {
        guard let items = query(type, groupingType).items else {
            throw E.noItemsFound
        }
        return items
    }

    /// Fetches all media collections of a specific type with grouping.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchAllCollections(_:groupingType:)`` that retrieves all collections of the specified type
    /// without additional filtering, organized by the specified grouping type.
    public func fetchAllCollections(
        _ type: MPMediaType,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection] {
        guard let collections = query(type, groupingType).collections else {
            throw E.noCollectionsFound
        }
        return collections
    }

    /// Fetches media item collection matching a predicate with default parameters.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchCollections(_:with:comparisonType:groupingType:)`` with default comparison type (`.equalTo`)
    /// and default grouping type (`.title`). Combines the media type predicate with the user-provided predicate.
    public func fetchCollections(
        _ type: MPMediaType,
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison = .equalTo,
        groupingType: MPMediaGrouping = .title
    ) async throws -> [MPMediaItemCollection] {
        guard let collections = query(type, withFilter: predicate, comparisonType, groupingType).collections else {
            throw E.noCollectionFound(predicate)
        }
        return collections
    }

    /// Fetches all playlists from the music library.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchAllPlaylists()`` that retrieves all playlists
    /// using `MPMediaQuery` with `.playlist` grouping and casts the results to `[MPMediaPlaylist]`.
    public func fetchAllPlaylists() async throws -> [MPMediaPlaylist] {
        guard let collections = playlistQuery().collections else {
            throw E.noCollectionsFound
        }
        return collections.compactMap { $0 as? MPMediaPlaylist }
    }

    /// Fetches playlists matching a predicate.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchPlaylists(with:comparisonType:)`` that queries
    /// playlists by the provided predicate and casts the results to `[MPMediaPlaylist]`.
    public func fetchPlaylists(
        with predicate: MediaItemPredicateInfo,
        comparisonType: MPMediaPredicateComparison = .equalTo
    ) async throws -> [MPMediaPlaylist] {
        let filter = predicate.predicate(using: comparisonType)
        var query = Q(filterPredicates: [filter])
        query.groupingType = .playlist
        guard let collections = query.collections else {
            throw E.noCollectionFound(predicate)
        }
        return collections.compactMap { $0 as? MPMediaPlaylist }
    }

    // MARK: - Private Helpers

    private func query(
        _ type: MPMediaType,
        _ groupingType: MPMediaGrouping
    ) -> Q {
        let typePredicate = MediaItemPredicateInfo.mediaType(type)
        let typeFilter = typePredicate.predicate()

        return prepareQuery(with: [typeFilter], groupingType: groupingType)
    }

    private func query(
        _ type: MPMediaType,
        withFilter predicate: MediaItemPredicateInfo,
        _ comparisonType: MPMediaPredicateComparison,
        _ groupingType: MPMediaGrouping
    ) -> Q {
        let typePredicate = MediaItemPredicateInfo.mediaType(type)
        // The media type is numeric; only .equalTo is valid for it. The caller's
        // comparison type applies to their predicate alone.
        let typeFilter = typePredicate.predicate()
        let additionalFilter = predicate.predicate(using: comparisonType)

        return prepareQuery(with: [typeFilter, additionalFilter], groupingType: groupingType)
    }

    private func playlistQuery() -> Q {
        var query = Q(filterPredicates: nil)
        query.groupingType = .playlist
        return query
    }

    private func prepareQuery(
        with predicates: Set<MPMediaPredicate>?,
        groupingType: MPMediaGrouping
    ) -> Q {
        var query = Q(filterPredicates: predicates)
        query.groupingType = groupingType
        return query
    }
}
