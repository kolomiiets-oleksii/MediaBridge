import MediaPlayer

/// A description of one music library query: what to fetch, how to filter it, and how to group it.
///
/// ``MusicLibrary`` turns each of its calls into a request and hands it to its
/// ``MusicLibraryServiceProtocol``, so a service only has to answer two questions:
/// which items match, and which collections match.
///
/// ```swift
/// let rockAlbums = MediaQueryRequest(
///     mediaType: .music,
///     filter: .init(.genre("Rock"), .contains),
///     grouping: .album
/// )
/// ```
public struct MediaQueryRequest: Sendable, Equatable, CustomStringConvertible {
    /// A predicate to filter by, with the comparison to apply.
    public struct Filter: Sendable, Equatable {
        public var predicate: MediaItemPredicateInfo
        public var comparison: MPMediaPredicateComparison

        public init(_ predicate: MediaItemPredicateInfo, _ comparison: MPMediaPredicateComparison = .equalTo) {
            self.predicate = predicate
            self.comparison = comparison
        }
    }

    /// The media type to restrict results to, or `nil` for any type (as playlists need).
    public var mediaType: MPMediaType?
    /// The predicate to filter by, or `nil` for no filtering.
    public var filter: Filter?
    /// How results are grouped into collections.
    public var grouping: MPMediaGrouping

    public init(mediaType: MPMediaType? = nil, filter: Filter? = nil, grouping: MPMediaGrouping) {
        self.mediaType = mediaType
        self.filter = filter
        self.grouping = grouping
    }

    public var description: String {
        var parts: [String] = []
        if let mediaType { parts.append("type \(mediaType.rawValue)") }
        if let filter { parts.append("\(filter.predicate.description) (\(filter.comparison.rawValue))") }
        parts.append("grouped by \(grouping.rawValue)")
        return parts.joined(separator: ", ")
    }
}
