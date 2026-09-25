import Foundation
import MediaPlayer

extension MusicLibraryProtocol {
    // MARK: - Genres

    /// Fetches music genres, each a collection of its songs.
    ///
    /// ## Example
    /// ```swift
    /// let genres = try await library.genres(sortedBy: \MPMediaItemCollection.count, order: .reverse)
    /// let names = genres.compactMap { $0.representativeItem?.genre }
    /// ```
    public func genres() async throws -> [MPMediaItemCollection] {
        try await collections(MediaQueryRequest(mediaType: .music, grouping: .genre))
    }

    /// Fetches music genres sorted by a key path.
    public func genres<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await genres().sorted(using: KeyPathComparator(sortingKey, order: order))
    }

    // MARK: - Composers

    /// Fetches music composers, each a collection of their songs.
    public func composers() async throws -> [MPMediaItemCollection] {
        try await collections(MediaQueryRequest(mediaType: .music, grouping: .composer))
    }

    /// Fetches music composers sorted by a key path.
    public func composers<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await composers().sorted(using: KeyPathComparator(sortingKey, order: order))
    }

    // MARK: - Podcasts

    /// Fetches podcasts, each a collection of its episodes.
    public func podcasts() async throws -> [MPMediaItemCollection] {
        try await collections(MediaQueryRequest(mediaType: .podcast, grouping: .podcastTitle))
    }

    /// Fetches podcasts sorted by a key path.
    public func podcasts<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await podcasts().sorted(using: KeyPathComparator(sortingKey, order: order))
    }

    // MARK: - Audiobooks

    /// Fetches audiobook items.
    public func audiobooks() async throws -> [MPMediaItem] {
        try await items(MediaQueryRequest(mediaType: .audioBook, grouping: .title))
    }

    /// Fetches audiobook items sorted by a key path.
    public func audiobooks<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItem, T>,
        order: SortOrder
    ) async throws -> [MPMediaItem] {
        try await audiobooks().sorted(using: KeyPathComparator(sortingKey, order: order))
    }
}

extension MusicLibraryProtocol {
    // MARK: - Compilations

    /// Fetches compilation albums, such as soundtracks and various-artists records.
    public func compilations() async throws -> [MPMediaItemCollection] {
        try await collections(MediaQueryRequest(mediaType: .music, filter: .init(.isCompilation(true)), grouping: .album))
    }

    /// Fetches compilation albums sorted by a key path.
    public func compilations<T: Comparable>(
        sortedBy sortingKey: SortKey<MPMediaItemCollection, T>,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await compilations().sorted(using: KeyPathComparator(sortingKey, order: order))
    }
}
