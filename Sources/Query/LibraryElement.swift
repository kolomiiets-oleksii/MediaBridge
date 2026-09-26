import MediaPlayer

/// A model type that ``LibraryQuery`` can fetch, such as ``Song``.
///
/// MediaBridge's model types conform; you don't need to conform your own types.
public protocol LibraryElement: Sendable {
    /// The request that fetches every element of this type, before any filters.
    static var baseRequest: MediaQueryRequest { get }

    /// Runs `request` against `library` and wraps the results.
    static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [Self]

    /// Runs `request` against `library` split into index sections, and wraps the results.
    static func fetchSections(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [MediaSection<Self>]

    /// The MediaPlayer predicate for `keyPath` equal to (or containing) `value`, or `nil` when
    /// MediaPlayer can't filter by that property and the condition must run in memory.
    static func predicate(for keyPath: AnyKeyPath, value: Any) -> MediaItemPredicateInfo?
}

extension LibraryElement where Self: CollectionElement {
    public static func fetch(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [Self] {
        try await library.collections(request).map(Self.init)
    }

    public static func fetchSections(_ request: MediaQueryRequest, from library: some MusicLibraryProtocol) async throws(MusicLibraryError) -> [MediaSection<Self>] {
        try await library.collectionSections(request).map { MediaSection(title: $0.title, elements: $0.elements.map(Self.init)) }
    }
}

/// A model that wraps one `MPMediaItemCollection`, such as ``Album`` or ``Artist``.
public protocol CollectionElement: LibraryElement {
    init(_ mediaCollection: MPMediaItemCollection)
}

extension LibraryElement {
    /// A query for every element of this type, to refine with `filter`, `sorted`, and `limit`.
    public static var query: LibraryQuery<Self> { LibraryQuery() }
}
