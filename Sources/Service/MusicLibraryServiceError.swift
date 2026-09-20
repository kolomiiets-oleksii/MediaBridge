//
//  MusicLibraryServiceError.swift
//  MediaBridge
//
//  Created by Oleksii Kolomiiets on 2/7/26.
//

import Foundation

/// Errors that can occur during music library service operations.
///
/// As of 0.9.3 the service reports "nothing matched" as an empty array rather than an error,
/// so none of these cases are thrown any more. They remain for source compatibility with
/// existing `catch` clauses and will be removed in a future release.
public enum MusicLibraryServiceError: Error, LocalizedError, Equatable {

    /// No media items were found when fetching all items of a specific type.
    @available(*, deprecated, message: "Queries with no results now return an empty array")
    case noItemsFound

    /// No media collections were found when fetching all collections of a specific type.
    @available(*, deprecated, message: "Queries with no results now return an empty array")
    case noCollectionsFound

    /// No media collections were found matching the specified predicate.
    ///
    /// **Associated Value:** The `MediaItemPredicateInfo` that was used to filter the query.
    @available(*, deprecated, message: "Queries with no results now return an empty array")
    case noCollectionFound(MediaItemPredicateInfo)

    /// No media items were found matching the specified predicate.
    ///
    /// **Associated Value:** The `MediaItemPredicateInfo` that was used to filter the query.
    @available(*, deprecated, message: "Queries with no results now return an empty array")
    case noItemFound(MediaItemPredicateInfo)

    // MARK: - LocalizedError Conformance

    /// A human-readable error description suitable for displaying to users.
    @available(*, deprecated, message: "Queries with no results now return an empty array")
    public var errorDescription: String? {
        switch self {
        case .noItemsFound:
            "No media items found in your library. Try adding music to your library and try again."
        case .noCollectionsFound:
            "No media collections found in your library. Try adding music to your library and try again."
        case .noCollectionFound(let predicate):
            "Couldn't find any collections matching \(predicate.description). Check your filters and try again."
        case .noItemFound(let predicate):
            "Couldn't find any media items matching \(predicate.description). Check your filters and try again."
        }
    }

    // MARK: - Equatable Conformance

    @available(*, deprecated, message: "Queries with no results now return an empty array")
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.noItemsFound, .noItemsFound): true
        case (.noCollectionsFound, .noCollectionsFound): true
        case (.noItemFound(let l), .noItemFound(let r)): l.description == r.description
        case (.noCollectionFound(let l), .noCollectionFound(let r)): l.description == r.description
        default: false
        }
    }
}
