import Foundation

/// The elements of a query that share one value, with totals over them.
///
/// ```swift
/// let artists = try await library.grouped(.songs, by: \.artist)
///     .sorted { $0.sum(of: \.playCount) > $1.sum(of: \.playCount) }
/// ```
public struct LibraryGroup<Key: Hashable & Sendable, Element: Sendable>: Sendable {
    /// The value the elements share.
    public let key: Key
    /// The elements, in query order.
    public let elements: [Element]

    public var count: Int { elements.count }

    /// The total of `value` over the elements, such as `sum(of: \.playCount)`.
    public func sum<Number: AdditiveArithmetic>(of value: (Element) -> Number) -> Number {
        elements.reduce(.zero) { $0 + value($1) }
    }

    /// The largest `value` among the elements, or `nil` for an empty group.
    public func maximum<Value: Comparable>(of value: (Element) -> Value) -> Value? {
        elements.map(value).max()
    }

    /// The smallest `value` among the elements, or `nil` for an empty group.
    public func minimum<Value: Comparable>(of value: (Element) -> Value) -> Value? {
        elements.map(value).min()
    }

    /// The mean of `value` over the elements, or `nil` for an empty group.
    public func average(of value: (Element) -> Double) -> Double? {
        elements.isEmpty ? nil : sum(of: value) / Double(elements.count)
    }

    static func groups(of elements: [Element], by key: (Element) -> Key) -> [Self] {
        var order: [Key] = []
        var members: [Key: [Element]] = [:]
        for element in elements {
            let k = key(element)
            if members[k] == nil { order.append(k) }
            members[k, default: []].append(element)
        }
        return order.map { Self(key: $0, elements: members[$0] ?? []) }
    }
}

extension LibraryGroup: Equatable where Element: Equatable {}

extension MusicLibraryProtocol {
    /// Runs a ``LibraryQuery`` and groups the results by the value of `keyPath`, in the order each
    /// value first appears. Sort the query to order the groups, or sort the returned array by a
    /// total.
    ///
    /// ```swift
    /// let genres = try await library.grouped(.songs, by: \.genre)
    ///     .sorted { $0.sum(of: \.playCount) > $1.sum(of: \.playCount) }
    /// for genre in genres.prefix(5) {
    ///     print(genre.key ?? "Unknown", genre.count, genre.sum(of: \.playCount))
    /// }
    /// ```
    ///
    /// Everything runs in memory over the fetched elements; `limit` applies before grouping.
    public func grouped<Element: LibraryElement, Key: Hashable & Sendable>(
        _ query: LibraryQuery<Element>,
        by keyPath: KeyPath<Element, Key> & Sendable
    ) async throws(MusicLibraryError) -> [LibraryGroup<Key, Element>] {
        LibraryGroup.groups(of: try await fetch(query)) { $0[keyPath: keyPath] }
    }

    /// Runs a ``LibraryQuery`` split into sections by a value other than the first letter of the
    /// title, such as the month songs were added.
    ///
    /// `title` turns the value into a section title; return `nil` to put an element in the `#`
    /// section, which comes last. Sections appear in the order their titles first show up in the
    /// results, so sort the query by the same key.
    ///
    /// ```swift
    /// let byMonth = try await library.sections(
    ///     .songs.sorted(by: \.dateAdded, .reverse),
    ///     by: \.dateAdded,
    ///     title: { $0?.formatted(.dateTime.year().month(.wide)) })
    /// ```
    public func sections<Element: LibraryElement, Value: Sendable>(
        _ query: LibraryQuery<Element>,
        by keyPath: KeyPath<Element, Value> & Sendable,
        title: @escaping @Sendable (Value) -> String?
    ) async throws(MusicLibraryError) -> [MediaSection<Element>] {
        let fetched = try await fetch(query)
        let groups = LibraryGroup.groups(of: fetched) { title($0[keyPath: keyPath]) ?? MediaSection<Element>.otherTitle }
        let named = groups.filter { $0.key != MediaSection<Element>.otherTitle }
        let other = groups.filter { $0.key == MediaSection<Element>.otherTitle }
        return (named + other).map { MediaSection(title: $0.key, elements: $0.elements) }
    }
}
