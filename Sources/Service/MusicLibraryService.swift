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
    private let playlistLibrary: @Sendable () -> any PlaylistLibrary

    /// Creates a service that builds its queries with `T`.
    public init() {
        playlistLibrary = { MPMediaLibrary.default() }
    }

    init(playlistLibrary: some PlaylistLibrary & Sendable) {
        self.playlistLibrary = { playlistLibrary }
    }

    public func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] {
        emptyLoggingResults(query(for: request).items, of: request)
    }

    public func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] {
        emptyLoggingResults(query(for: request).collections, of: request)
    }

    public func itemSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItem>] {
        let query = query(for: request)
        let items = emptyLoggingResults(query.items, of: request)
        guard let sections = query.itemSectionRanges else {
            return MediaSection.alphabetical(items, grouping: request.grouping)
        }
        return split(items, into: sections)
    }

    public func collectionSections(_ request: MediaQueryRequest) async throws -> [MediaSection<MPMediaItemCollection>] {
        let query = query(for: request)
        let collections = emptyLoggingResults(query.collections, of: request)
        guard let sections = query.collectionSectionRanges else {
            return MediaSection.alphabetical(collections, grouping: request.grouping)
        }
        return split(collections, into: sections)
    }

    public func playlist(id: UUID, creating metadata: PlaylistMetadata?) async throws -> MPMediaPlaylist? {
        let library = playlistLibrary()
        let playlist = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UncheckedPlaylist, Error>) in
            library.getPlaylist(with: id, creationMetadata: metadata?.creationMetadata) { playlist, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: UncheckedPlaylist(playlist: playlist))
                }
            }
        }
        return playlist.playlist
    }

    public func add(_ items: [MPMediaItem], to playlist: MPMediaPlaylist) async throws {
        try await playlist.add(items)
    }

    private func split<Element>(
        _ elements: [Element],
        into sections: [(title: String, range: Range<Int>)]
    ) -> [MediaSection<Element>] {
        sections.compactMap { section in
            let range = section.range.clamped(to: elements.indices)
            guard !range.isEmpty else { return nil }
            return MediaSection(title: section.title, elements: Array(elements[range]))
        }
    }

    private func query(for request: MediaQueryRequest) -> T {
        var predicates: Set<MPMediaPredicate> = []
        if let mediaType = request.mediaType {
            predicates.insert(MediaItemPredicateInfo.mediaType(mediaType).predicate())
        }
        for filter in request.filters {
            predicates.insert(filter.predicate.predicate(using: filter.comparison))
        }
        var query = T(filterPredicates: predicates.isEmpty ? nil : predicates)
        query.groupingType = request.grouping
        return query
    }

    private func emptyLoggingResults<Element>(_ results: [Element]?, of request: MediaQueryRequest) -> [Element] {
        guard let results else {
            log.info("Query for \(request.description) returned nil")
            return []
        }
        if results.isEmpty {
            log.info("Query for \(request.description) matched nothing")
        }
        return results
    }
}

private struct UncheckedPlaylist: @unchecked Sendable {
    let playlist: MPMediaPlaylist?
}
