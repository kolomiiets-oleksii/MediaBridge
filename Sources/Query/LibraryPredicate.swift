import Foundation

/// A condition on one property, written with a comparison operator on a key path, such as
/// `\.playCount >= 10` or `\.artist == "Adele"`.
///
/// Pass it to ``LibraryQuery/filter(_:)``. `==` runs inside MediaPlayer's query when the property
/// supports it, like `.equals`; the other operators run in memory.
public struct LibraryPredicate<Root: LibraryElement>: Sendable {
    let apply: @Sendable (LibraryQuery<Root>) -> LibraryQuery<Root>
}

extension LibraryQuery {
    /// Keeps only elements matching `predicate`, such as `\.playCount >= 10`.
    public func filter(_ predicate: LibraryPredicate<Element>) -> Self {
        predicate.apply(self)
    }
}

private func predicate<Root: LibraryElement, Value>(
    _ keyPath: KeyPath<Root, Value> & Sendable,
    _ condition: LibraryCondition<Value>
) -> LibraryPredicate<Root> {
    LibraryPredicate { $0.filter(keyPath, condition) }
}

public func == <Root: LibraryElement, Value: Equatable & Sendable>(lhs: KeyPath<Root, Value> & Sendable, rhs: Value) -> LibraryPredicate<Root> {
    predicate(lhs, .equals(rhs))
}

public func == <Root: LibraryElement, Wrapped: Equatable & Sendable>(lhs: KeyPath<Root, Wrapped?> & Sendable, rhs: Wrapped?) -> LibraryPredicate<Root> {
    predicate(lhs, .equals(rhs))
}

public func != <Root: LibraryElement, Value: Equatable & Sendable>(lhs: KeyPath<Root, Value> & Sendable, rhs: Value) -> LibraryPredicate<Root> {
    predicate(lhs, .notEquals(rhs))
}

public func < <Root: LibraryElement, Value: Comparable & Sendable>(lhs: KeyPath<Root, Value> & Sendable, rhs: Value) -> LibraryPredicate<Root> {
    predicate(lhs, .lessThan(rhs))
}

public func > <Root: LibraryElement, Value: Comparable & Sendable>(lhs: KeyPath<Root, Value> & Sendable, rhs: Value) -> LibraryPredicate<Root> {
    predicate(lhs, .greaterThan(rhs))
}

public func <= <Root: LibraryElement, Value: Comparable & Sendable>(lhs: KeyPath<Root, Value> & Sendable, rhs: Value) -> LibraryPredicate<Root> {
    predicate(lhs, .atMost(rhs))
}

public func >= <Root: LibraryElement, Value: Comparable & Sendable>(lhs: KeyPath<Root, Value> & Sendable, rhs: Value) -> LibraryPredicate<Root> {
    predicate(lhs, .atLeast(rhs))
}

public func < <Root: LibraryElement, Wrapped: Comparable & Sendable>(lhs: KeyPath<Root, Wrapped?> & Sendable, rhs: Wrapped) -> LibraryPredicate<Root> {
    predicate(lhs, .lessThan(rhs))
}

public func > <Root: LibraryElement, Wrapped: Comparable & Sendable>(lhs: KeyPath<Root, Wrapped?> & Sendable, rhs: Wrapped) -> LibraryPredicate<Root> {
    predicate(lhs, .greaterThan(rhs))
}

public func <= <Root: LibraryElement, Wrapped: Comparable & Sendable>(lhs: KeyPath<Root, Wrapped?> & Sendable, rhs: Wrapped) -> LibraryPredicate<Root> {
    predicate(lhs, .atMost(rhs))
}

public func >= <Root: LibraryElement, Wrapped: Comparable & Sendable>(lhs: KeyPath<Root, Wrapped?> & Sendable, rhs: Wrapped) -> LibraryPredicate<Root> {
    predicate(lhs, .atLeast(rhs))
}
