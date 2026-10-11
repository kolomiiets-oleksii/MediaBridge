import Foundation

// `a && b` keeps both conditions in the query, so each can still run inside MediaPlayer's query.
// `||` and `!` can't be handed to MediaPlayer, so the whole condition runs in memory.

extension LibraryPredicate {
    fileprivate var clauses: [LibraryQuery<Root>.Clause] { apply(LibraryQuery<Root>()).clauses }
}

private func passes<Root: LibraryElement>(_ clauses: [LibraryQuery<Root>.Clause]) -> @Sendable (Root) -> Bool {
    { element in clauses.allSatisfy { $0.test(element) } }
}

// A compound condition's identity is made of its operands' identities, not of text printed from
// them: a key path prints as just its type on older runtimes, which would make
// `\.artist == "A" || …` and `\.title == "A" || …` look alike.
private struct Compound<Root: LibraryElement>: Hashable, Sendable {
    let name: String
    let operands: [[LibraryQuery<Root>.Identity]]

    init(_ name: String, _ operands: [LibraryQuery<Root>.Clause]...) {
        self.name = name
        self.operands = operands.map { $0.map(\.identity) }
    }
}

/// Matches elements that match both conditions. Each condition keeps running inside MediaPlayer's
/// query when it can, same as two `filter` calls.
public func && <Root: LibraryElement>(lhs: LibraryPredicate<Root>, rhs: LibraryPredicate<Root>) -> LibraryPredicate<Root> {
    LibraryPredicate { rhs.apply(lhs.apply($0)) }
}

/// Matches elements that match either condition.
///
/// MediaPlayer's query can't express "or", so a query with `||` fetches everything the rest of the
/// query allows and tests this condition in memory.
public func || <Root: LibraryElement>(lhs: LibraryPredicate<Root>, rhs: LibraryPredicate<Root>) -> LibraryPredicate<Root> {
    let left = lhs.clauses
    let right = rhs.clauses
    let leftPasses = passes(left)
    let rightPasses = passes(right)
    return LibraryPredicate { query in
        query.appending(
            .init(
                filter: nil,
                identity: .init(keyPath: Compound("||", left, right), detail: ""),
                test: { leftPasses($0) || rightPasses($0) }))
    }
}

/// Matches elements that don't match `predicate`. Runs in memory.
public prefix func ! <Root: LibraryElement>(predicate: LibraryPredicate<Root>) -> LibraryPredicate<Root> {
    let clauses = predicate.clauses
    let passes = passes(clauses)
    return LibraryPredicate { query in
        query.appending(
            .init(
                filter: nil,
                identity: .init(keyPath: Compound("!", clauses), detail: ""),
                test: { !passes($0) }))
    }
}
