import MediaPlayer

/// A test applied to one property in a ``LibraryQuery``, such as `.equals("Adele")` or `.greaterThan(10)`.
///
/// `equals` and `contains` run inside MediaPlayer's query when the property supports it; every
/// other condition, and every condition on a property MediaPlayer can't filter, runs in memory.
public struct LibraryCondition<Value: Sendable>: Sendable {
    let pushdown: (value: any Sendable, comparison: MPMediaPredicateComparison)?
    let identity: String
    let test: @Sendable (Value) -> Bool

    init(
        _ name: String,
        _ operand: some Sendable,
        pushdown: (value: any Sendable, comparison: MPMediaPredicateComparison)?,
        test: @escaping @Sendable (Value) -> Bool
    ) {
        self.pushdown = pushdown
        self.identity = "\(name)(\(String(reflecting: operand)))"
        self.test = test
    }
}

extension LibraryCondition where Value: Equatable {
    public static func equals(_ expected: Value) -> Self {
        Self("equals", expected, pushdown: (expected, .equalTo), test: { $0 == expected })
    }

    public static func notEquals(_ unexpected: Value) -> Self {
        Self("notEquals", unexpected, pushdown: nil, test: { $0 != unexpected })
    }
}

extension LibraryCondition where Value == String? {
    /// Matches when the value contains `substring`, ignoring case.
    public static func contains(_ substring: String) -> Self {
        Self("contains", substring, pushdown: (substring, .contains), test: { $0?.localizedCaseInsensitiveContains(substring) ?? false })
    }
}

extension LibraryCondition where Value == String {
    /// Matches when the value contains `substring`, ignoring case.
    public static func contains(_ substring: String) -> Self {
        Self("contains", substring, pushdown: (substring, .contains), test: { $0.localizedCaseInsensitiveContains(substring) })
    }
}

extension LibraryCondition where Value == String? {
    /// Matches when the value starts with `prefix`, ignoring case and diacritics.
    public static func hasPrefix(_ prefix: String) -> Self {
        Self("hasPrefix", prefix, pushdown: nil, test: { $0.map { Self.starts($0, with: prefix) } ?? false })
    }
}

extension LibraryCondition where Value == String {
    /// Matches when the value starts with `prefix`, ignoring case and diacritics.
    public static func hasPrefix(_ prefix: String) -> Self {
        Self("hasPrefix", prefix, pushdown: nil, test: { Self.starts($0, with: prefix) })
    }
}

extension LibraryCondition {
    fileprivate static func starts(_ value: String, with prefix: String) -> Bool {
        // `range(of:)` finds nothing for an empty string, but every string starts with one.
        prefix.isEmpty || value.range(of: prefix, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil
    }
}

extension LibraryCondition where Value: Hashable {
    /// Matches when the value is one of `values`, such as `.filter(\.artist, .isIn(["Adele", "Sade"]))`.
    ///
    /// Runs in memory: MediaPlayer's query can't filter by several values at once.
    public static func isIn(_ values: some Sequence<Value>) -> Self {
        let set = Set(values)
        // Sorted, so two queries built from equal sets compare equal whatever order a Set iterates in.
        let operand = set.map { String(reflecting: $0) }.sorted()
        return Self("isIn", operand, pushdown: nil, test: { set.contains($0) })
    }
}

extension LibraryCondition where Value: Comparable {
    public static func greaterThan(_ bound: Value) -> Self { Self("greaterThan", bound, pushdown: nil, test: { $0 > bound }) }
    public static func lessThan(_ bound: Value) -> Self { Self("lessThan", bound, pushdown: nil, test: { $0 < bound }) }
    public static func atLeast(_ bound: Value) -> Self { Self("atLeast", bound, pushdown: nil, test: { $0 >= bound }) }
    public static func atMost(_ bound: Value) -> Self { Self("atMost", bound, pushdown: nil, test: { $0 <= bound }) }
}

extension LibraryCondition {
    /// Matches when the value is present and equal to `expected`, or missing when `expected` is `nil`.
    public static func equals<Wrapped: Equatable & Sendable>(_ expected: Wrapped?) -> Self where Value == Wrapped? {
        Self("equals", expected, pushdown: expected.map { ($0, .equalTo) }, test: { $0 == expected })
    }

    /// Matches present values greater than `bound`; missing values never match.
    public static func greaterThan<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self("greaterThan", bound, pushdown: nil, test: { $0.map { $0 > bound } ?? false })
    }

    /// Matches present values less than `bound`; missing values never match.
    public static func lessThan<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self("lessThan", bound, pushdown: nil, test: { $0.map { $0 < bound } ?? false })
    }

    /// Matches present values of at least `bound`; missing values never match.
    public static func atLeast<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self("atLeast", bound, pushdown: nil, test: { $0.map { $0 >= bound } ?? false })
    }

    /// Matches present values of at most `bound`; missing values never match.
    public static func atMost<Wrapped: Comparable & Sendable>(_ bound: Wrapped) -> Self where Value == Wrapped? {
        Self("atMost", bound, pushdown: nil, test: { $0.map { $0 <= bound } ?? false })
    }
}
