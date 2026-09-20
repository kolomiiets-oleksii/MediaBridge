import MediaPlayer

/// Factory extension for creating a live instance of `MusicLibraryService`.
extension MusicLibraryServiceProtocol where Self == MusicLibraryService<MPMediaQuery> {
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
        emptyLoggingResults(
            query(type, withFilter: predicate, comparisonType, groupingType).items,
            of: predicate.description
        )
    }

    /// Fetches all media items of a specific type with grouping.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchAll(_:groupingType:)`` that retrieves all items of the specified type
    /// without additional filtering, organized by the specified grouping type.
    public func fetchAll(
        _ type: MPMediaType,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItem] {
        emptyLoggingResults(query(type, groupingType).items, of: "all items grouped by \(groupingType.rawValue)")
    }

    /// Fetches all media collections of a specific type with grouping.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchAllCollections(_:groupingType:)`` that retrieves all collections of the specified type
    /// without additional filtering, organized by the specified grouping type.
    public func fetchAllCollections(
        _ type: MPMediaType,
        groupingType: MPMediaGrouping
    ) async throws -> [MPMediaItemCollection] {
        emptyLoggingResults(query(type, groupingType).collections, of: "all collections grouped by \(groupingType.rawValue)")
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
        emptyLoggingResults(
            query(type, withFilter: predicate, comparisonType, groupingType).collections,
            of: predicate.description
        )
    }

    /// Fetches all playlists from the music library.
    ///
    /// Implementation of ``MusicLibraryServiceProtocol/fetchAllPlaylists()`` that retrieves all playlists
    /// using `MPMediaQuery` with `.playlist` grouping and casts the results to `[MPMediaPlaylist]`.
    public func fetchAllPlaylists() async throws -> [MPMediaPlaylist] {
        playlistsDiscardingOtherCollections(in: playlistQuery(), of: "all playlists")
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

        return playlistsDiscardingOtherCollections(in: query, of: predicate.description)
    }

    // MARK: - Private Helpers

    private func emptyLoggingResults<Element>(
        _ results: [Element]?,
        of description: @escaping @autoclosure () -> String
    ) -> [Element] {
        guard let results else {
            log.info("Query for \(description()) returned nil")
            return []
        }

        if results.isEmpty {
            log.info("Query for \(description()) matched nothing")
        }

        return results
    }

    private func playlistsDiscardingOtherCollections(
        in query: Q,
        of description: @escaping @autoclosure () -> String
    ) -> [MPMediaPlaylist] {
        let collections = emptyLoggingResults(query.collections, of: description())
        let playlists = collections.compactMap { $0 as? MPMediaPlaylist }

        if playlists.count != collections.count {
            log.debug("Discarded \(collections.count - playlists.count) non-playlist collections for \(description())")
        }

        return playlists
    }

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
