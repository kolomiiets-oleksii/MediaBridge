import MediaPlayer

/// A test applied to one property in a ``LibraryQuery``, such as `.equals("Adele")` or `.greaterThan(10)`.
///
/// `equals` and `contains` run inside MediaPlayer's query when the property supports it; every
/// other condition, and every condition on a property MediaPlayer can't filter, runs in memory.
public struct LibraryCondition<Value>: @unchecked Sendable {
    let pushdown: (value: Any, comparison: MPMediaPredicateComparison)?
    let test: (Value) -> Bool
}

extension LibraryCondition where Value: Equatable {
    public static func equals(_ expected: Value) -> Self {
        Self(pushdown: unwrapped(expected).map { ($0, .equalTo) }, test: { $0 == expected })
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

private protocol OptionalValue {
    var wrappedAny: Any? { get }
}

extension Optional: OptionalValue {
    fileprivate var wrappedAny: Any? { map { $0 } }
}

private func unwrapped(_ value: Any) -> Any? {
    (value as? OptionalValue).map(\.wrappedAny) ?? value
}
