import Foundation
import MediaPlayer

/// A description of which library elements to fetch and in what order.
///
/// Build one from a model type's `query` and run it with ``MusicLibraryProtocol/fetch(_:)``:
///
/// ```swift
/// let topLocal = try await library.fetch(
///     Song.query
///         .filter(\.isCloudItem, .equals(false))
///         .filter(\.playCount, .atLeast(10))
///         .sorted(by: \.playCount, .reverse)
///         .then(by: \.title)
///         .limit(25)
/// )
/// ```
///
/// Filters MediaPlayer supports run inside its query; the rest run in memory. Sorting reads each
/// sort key once per element, so it stays linear in property reads on large libraries.
public struct LibraryQuery<Element: LibraryElement>: Sendable, Equatable {
    struct Clause {
        let filter: MediaQueryRequest.Filter?
        let identity: Identity
        let test: @Sendable (Element) -> Bool
    }

    struct Ordering {
        let identity: Identity
        let keys: @Sendable ([Element]) -> (Int, Int) -> ComparisonResult
    }

    struct Identity: Equatable, Sendable {
        let keyPath: any Hashable & Sendable
        let detail: String

        static func == (lhs: Identity, rhs: Identity) -> Bool {
            AnyHashable(lhs.keyPath) == AnyHashable(rhs.keyPath) && lhs.detail == rhs.detail
        }
    }

    private(set) var clauses: [Clause] = []
    private(set) var orderings: [Ordering] = []
    private(set) var maximumCount: Int?
    private var mediaTypeOverride: MediaTypeOverride?

    private struct MediaTypeOverride {
        let mediaType: MPMediaType?
    }

    public init() {}

    /// Keeps only elements whose `keyPath` value satisfies `condition`.
    public func filter<Value>(_ keyPath: KeyPath<Element, Value> & Sendable, _ condition: LibraryCondition<Value>) -> Self {
        var copy = self
        let pushed = condition.pushdown.flatMap { pushdown in
            Element.predicate(for: keyPath, value: pushdown.value).map { MediaQueryRequest.Filter($0, pushdown.comparison) }
        }
        copy.clauses.append(Clause(filter: pushed, identity: Identity(keyPath: keyPath, detail: condition.identity), test: { condition.test($0[keyPath: keyPath]) }))
        return copy
    }

    /// Orders results by `keyPath`, replacing any previous ordering.
    public func sorted<Value: Comparable>(by keyPath: KeyPath<Element, Value> & Sendable, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings = [Self.ordering(keyPath, { $0[keyPath: keyPath] }, order)]
        return copy
    }

    /// Breaks ties in the current ordering by `keyPath`.
    public func then<Value: Comparable>(by keyPath: KeyPath<Element, Value> & Sendable, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings.append(Self.ordering(keyPath, { $0[keyPath: keyPath] }, order))
        return copy
    }

    /// Orders results by an optional `keyPath`, replacing any previous ordering. Missing values
    /// sort first in `.forward` order.
    public func sorted<Value: Comparable>(by keyPath: KeyPath<Element, Value?> & Sendable, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings = [Self.ordering(keyPath, { $0[keyPath: keyPath].nilFirst }, order)]
        return copy
    }

    /// Breaks ties in the current ordering by an optional `keyPath`. Missing values sort first in
    /// `.forward` order.
    public func then<Value: Comparable>(by keyPath: KeyPath<Element, Value?> & Sendable, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings.append(Self.ordering(keyPath, { $0[keyPath: keyPath].nilFirst }, order))
        return copy
    }

    /// Orders results by a flag, replacing any previous ordering. `false` sorts first in
    /// `.forward` order.
    public func sorted(by keyPath: KeyPath<Element, Bool> & Sendable, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings = [Self.ordering(keyPath, { $0[keyPath: keyPath].sortRank }, order)]
        return copy
    }

    /// Breaks ties in the current ordering by a flag. `false` sorts first in `.forward` order.
    public func then(by keyPath: KeyPath<Element, Bool> & Sendable, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings.append(Self.ordering(keyPath, { $0[keyPath: keyPath].sortRank }, order))
        return copy
    }

    /// Returns at most `count` elements, after filtering and sorting.
    public func limit(_ count: Int) -> Self {
        var copy = self
        copy.maximumCount = count
        return copy
    }

    /// Fetches `mediaType` instead of the element's default, such as audiobooks or podcast
    /// episodes as ``Song``s. Pass `nil` to match every media type.
    public func mediaType(_ mediaType: MPMediaType?) -> Self {
        var copy = self
        copy.mediaTypeOverride = MediaTypeOverride(mediaType: mediaType)
        return copy
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.clauses.map(\.identity) == rhs.clauses.map(\.identity)
            && lhs.orderings.map(\.identity) == rhs.orderings.map(\.identity)
            && lhs.maximumCount == rhs.maximumCount
            && lhs.mediaTypeOverride?.mediaType == rhs.mediaTypeOverride?.mediaType
            && (lhs.mediaTypeOverride == nil) == (rhs.mediaTypeOverride == nil)
    }

    var request: MediaQueryRequest {
        var request = Element.baseRequest
        if let mediaTypeOverride {
            request.mediaType = mediaTypeOverride.mediaType
        }
        request.filters += clauses.compactMap(\.filter)
        return request
    }

    func refine(_ fetched: [Element], applyingLimit: Bool = true) -> [Element] {
        let localTests = clauses.filter { $0.filter == nil }.map(\.test)
        var elements = localTests.isEmpty ? fetched : fetched.filter { element in localTests.allSatisfy { $0(element) } }
        if !orderings.isEmpty {
            let comparators = orderings.map { $0.keys(elements) }
            let order = elements.indices.sorted { lhs, rhs in
                for compare in comparators {
                    switch compare(lhs, rhs) {
                    case .orderedAscending: return true
                    case .orderedDescending: return false
                    case .orderedSame: continue
                    }
                }
                return lhs < rhs
            }
            elements = order.map { elements[$0] }
        }
        if applyingLimit, let maximumCount {
            elements = Array(elements.prefix(maximumCount))
        }
        return elements
    }

    private static func ordering<Value: Comparable>(
        _ keyPath: some Hashable & Sendable,
        _ key: @escaping @Sendable (Element) -> Value,
        _ order: SortOrder
    ) -> Ordering {
        Ordering(identity: Identity(keyPath: keyPath, detail: "\(order)")) { elements in
            let keys = elements.map(key)
            return { lhs, rhs in
                let (a, b) = order == .forward ? (keys[lhs], keys[rhs]) : (keys[rhs], keys[lhs])
                if a < b { return .orderedAscending }
                if b < a { return .orderedDescending }
                return .orderedSame
            }
        }
    }
}

extension MusicLibraryProtocol {
    /// Runs a ``LibraryQuery``, requesting authorization first if needed.
    public func fetch<Element: LibraryElement>(_ query: LibraryQuery<Element>) async throws(MusicLibraryError) -> [Element] {
        query.refine(try await Element.fetch(query.request, from: self))
    }

    /// Runs a ``LibraryQuery`` split into A–Z index sections, as in the Music app's lists.
    ///
    /// The query's filters and ordering apply inside each section, and sections the filters empty
    /// are dropped. `limit` is ignored.
    public func sections<Element: LibraryElement>(_ query: LibraryQuery<Element>) async throws(MusicLibraryError) -> [MediaSection<Element>] {
        try await Element.fetchSections(query.request, from: self).compactMap { section in
            let elements = query.refine(section.elements, applyingLimit: false)
            return elements.isEmpty ? nil : MediaSection(title: section.title, elements: elements)
        }
    }
}

struct NilFirst<Wrapped: Comparable>: Comparable {
    let value: Wrapped?

    static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs.value, rhs.value) {
        case (nil, nil): false
        case (nil, _): true
        case (_, nil): false
        case let (lhs?, rhs?): lhs < rhs
        }
    }
}

extension Optional where Wrapped: Comparable {
    var nilFirst: NilFirst<Wrapped> { NilFirst(value: self) }
}

extension Bool {
    var sortRank: Int { self ? 1 : 0 }
}
