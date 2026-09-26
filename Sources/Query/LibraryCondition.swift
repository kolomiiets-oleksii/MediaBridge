import MediaPlayer

/// A test applied to one property in a ``LibraryQuery``, such as `.equals("Adele")` or `.greaterThan(10)`.
///
/// `equals` and `contains` run inside MediaPlayer's query when the property supports it; every
/// other condition, and every condition on a property MediaPlayer can't filter, runs in memory.
public struct LibraryCondition<Value: Sendable>: Sendable {
    let pushdown: (value: any Sendable, comparison: MPMediaPredicateComparison)?
    let test: @Sendable (Value) -> Bool
}

extension LibraryCondition where Value: Equatable {
    public static func equals(_ expected: Value) -> Self {
        Self(pushdown: (expected, .equalTo), test: { $0 == expected })
    }

    public static func notEquals(_ unexpected: Value) -> Self {
        Self(pushdown: nil, test: { $0 != unexpected })
    }
}

extension LibraryCondition where Value == String? {
    /// Matches when the value contains `substring`, ignoring case.
    public static func contains(_ substring: String) -> Self {
        Self(pushdown: (substring, .contains), test: { $0?.localizedCaseInsensitiveContains(substring) ?? false })
    }
}

extension LibraryCondition where Value == String {
    /// Matches when the value contains `substring`, ignoring case.
    public static func contains(_ substring: String) -> Self {
        Self(pushdown: (substring, .contains), test: { $0.localizedCaseInsensitiveContains(substring) })
    }
}

extension LibraryCondition where Value: Comparable {
    public static func greaterThan(_ bound: Value) -> Self { Self(pushdown: nil, test: { $0 > bound }) }
    public static func lessThan(_ bound: Value) -> Self { Self(pushdown: nil, test: { $0 < bound }) }
    public static func atLeast(_ bound: Value) -> Self { Self(pushdown: nil, test: { $0 >= bound }) }
    public static func atMost(_ bound: Value) -> Self { Self(pushdown: nil, test: { $0 <= bound }) }
}

extension LibraryCondition {
    /// Matches when the value is present and equal to `expected`, or missing when `expected` is `nil`.
    public static func equals<Wrapped: Equatable & Sendable>(_ expected: Wrapped?) -> Self where Value == Wrapped? {
        Self(pushdown: expected.map { ($0, .equalTo) }, test: { $0 == expected })
    }

    /// Matches present values greater than `bound`; missing values never match.
    public static func greaterThan<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self(pushdown: nil, test: { $0.map { $0 > bound } ?? false })
    }

    /// Matches present values less than `bound`; missing values never match.
    public static func lessThan<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self(pushdown: nil, test: { $0.map { $0 < bound } ?? false })
    }

    /// Matches present values of at least `bound`; missing values never match.
    public static func atLeast<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self(pushdown: nil, test: { $0.map { $0 >= bound } ?? false })
    }

    /// Matches present values of at most `bound`; missing values never match.
    public static func atMost<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self(pushdown: nil, test: { $0.map { $0 <= bound } ?? false })
    }
}
