import Foundation
import MediaPlayer

/// An abstraction over `MPMediaQuery` for flexible query handling and testing.
///
/// This protocol provides a lightweight abstraction over Apple's `MPMediaQuery` class, enabling dependency injection and simplified testing.
/// It allows you to use real `MPMediaQuery` instances in production while substituting mock implementations in tests.
///
/// ## Usage
///
/// Conform your query implementation to this protocol:
///
/// ```swift
/// class MockMediaQuery: MediaQueryProtocol {
///     var items: [MPMediaItem]? { /* mock data */ }
///     var groupingType: MPMediaGrouping = .default
///
///     required init(filterPredicates: Set<MPMediaPredicate>?) {
///         // Initialize with predicates
///     }
/// }
/// ```
///
/// Then use it with services that accept any `MediaQueryProtocol`:
///
/// ```swift
/// let service = MusicLibraryService<MockMediaQuery>()
/// ```
public protocol MediaQueryProtocol {
    /// The media items matching the query criteria.
    ///
    /// Returns an array of `MPMediaItem` objects that match the query predicates,
    /// or `nil` if the query has not been executed or returned no results.
    var items: [MPMediaItem]? { get }

    /// The media items collection matching the query criteria.
    ///
    /// Returns an array of `MPMediaItemCollection` objects that match the query predicates,
    /// or `nil` if the query has not been executed or returned no results.
    var collections: [MPMediaItemCollection]? { get }

    /// The grouping type used to organize query results.
    ///
    /// Controls how the media items are grouped in the results. Can be modified
    /// to change the organization of items returned by the query.
    var groupingType: MPMediaGrouping { get set }

    /// Initializes a query with optional filter predicates.
    ///
    /// - Parameters:
    ///   - filterPredicates: A set of `MPMediaPredicate` objects that define the filtering criteria for the query.
    ///                      Pass `nil` to fetch all available media items without filtering.
    init(filterPredicates: Set<MPMediaPredicate>?)

    /// Index section titles and the ranges of ``items`` they cover, or `nil` when the query doesn't
    /// provide them.
    var itemSectionRanges: [(title: String, range: Range<Int>)]? { get }

    /// Index section titles and the ranges of ``collections`` they cover, or `nil` when the query
    /// doesn't provide them.
    var collectionSectionRanges: [(title: String, range: Range<Int>)]? { get }
}

extension MediaQueryProtocol {
    public var itemSectionRanges: [(title: String, range: Range<Int>)]? { nil }
    public var collectionSectionRanges: [(title: String, range: Range<Int>)]? { nil }
}

extension MPMediaQuery: MediaQueryProtocol {
    public var itemSectionRanges: [(title: String, range: Range<Int>)]? {
        itemSections?.compactMap { section in Range(section.range).map { (section.title, $0) } }
    }

    public var collectionSectionRanges: [(title: String, range: Range<Int>)]? {
        collectionSections?.compactMap { section in Range(section.range).map { (section.title, $0) } }
    }
}
