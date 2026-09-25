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
public struct LibraryQuery<Element: LibraryElement>: @unchecked Sendable {
    struct Clause {
        let filter: MediaQueryRequest.Filter?
        let test: (Element) -> Bool
    }

    struct Ordering {
        let keys: ([Element]) -> (Int, Int) -> ComparisonResult
    }

    private(set) var clauses: [Clause] = []
    private(set) var orderings: [Ordering] = []
    private(set) var maximumCount: Int?

    public init() {}

    /// Keeps only elements whose `keyPath` value satisfies `condition`.
    public func filter<Value>(_ keyPath: KeyPath<Element, Value>, _ condition: LibraryCondition<Value>) -> Self {
        var copy = self
        let pushed = condition.pushdown.flatMap { pushdown in
            Element.predicate(for: keyPath, value: pushdown.value).map { MediaQueryRequest.Filter($0, pushdown.comparison) }
        }
        copy.clauses.append(Clause(filter: pushed, test: { condition.test($0[keyPath: keyPath]) }))
        return copy
    }

    /// Orders results by `keyPath`, replacing any previous ordering.
    public func sorted<Value: Comparable>(by keyPath: KeyPath<Element, Value>, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings = [Self.ordering(keyPath, order)]
        return copy
    }

    /// Breaks ties in the current ordering by `keyPath`.
    public func then<Value: Comparable>(by keyPath: KeyPath<Element, Value>, _ order: SortOrder = .forward) -> Self {
        var copy = self
        copy.orderings.append(Self.ordering(keyPath, order))
        return copy
    }

    /// Returns at most `count` elements, after filtering and sorting.
    public func limit(_ count: Int) -> Self {
        var copy = self
        copy.maximumCount = count
        return copy
    }

    var request: MediaQueryRequest {
        var request = Element.baseRequest
        request.filters += clauses.compactMap(\.filter)
        return request
    }

    func refine(_ fetched: [Element]) -> [Element] {
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
        if let maximumCount {
            elements = Array(elements.prefix(maximumCount))
        }
        return elements
    }

    private static func ordering<Value: Comparable>(_ keyPath: KeyPath<Element, Value>, _ order: SortOrder) -> Ordering {
        Ordering { elements in
            let keys = elements.map { $0[keyPath: keyPath] }
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
    public func fetch<Element: LibraryElement>(_ query: LibraryQuery<Element>) async throws -> [Element] {
        query.refine(try await Element.fetch(query.request, from: self))
    }
}
