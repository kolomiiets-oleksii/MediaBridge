import Foundation

/// What went wrong with a catalog search. Every ``CatalogSearching`` call throws this one type.
public enum CatalogError: Error, LocalizedError, Equatable {
    /// The request can't be run; the associated value says why.
    case invalidRequest(String)
    /// The person hasn't allowed this app to use Apple Music.
    case notAuthorized
    /// MusicKit, or a custom catalog, failed with this error.
    case underlying(any Error)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let reason):
            reason
        case .notAuthorized:
            "Apple Music access isn't allowed. Allow it in Settings > Privacy & Security > Media & Apple Music."
        case .underlying(let error):
            error.localizedDescription
        }
    }

    /// Underlying errors are equal when they share a domain and code.
    public static func == (lhs: CatalogError, rhs: CatalogError) -> Bool {
        switch (lhs, rhs) {
        case let (.invalidRequest(l), .invalidRequest(r)): l == r
        case (.notAuthorized, .notAuthorized): true
        case let (.underlying(l), .underlying(r)):
            (l as NSError).domain == (r as NSError).domain && (l as NSError).code == (r as NSError).code
        default: false
        }
    }
}

/// A validated Apple Music catalog search.
///
/// Building one checks the term, kinds, limit and offset, so a ``CatalogSearching`` implementation
/// only ever sees a request it can run.
public struct CatalogSearchRequest: Sendable, Equatable {
    /// The kinds searched when none are given.
    public static let defaultKinds: [CatalogKind] = [.song, .album, .artist, .playlist]
    /// The limit used when none is given.
    public static let defaultLimit = 10
    /// The largest limit a request accepts.
    public static let maximumLimit = 25

    /// The search term, without surrounding whitespace.
    public let term: String
    /// The kinds to search, without repeats, in the order given.
    public let kinds: [CatalogKind]
    /// The most results per kind, from 1 to ``maximumLimit``.
    public let limit: Int
    /// How many results to skip.
    public let offset: Int
    /// Whether to also return Apple Music's top results, a relevance-ordered mix of kinds. Needs iOS 16.
    public let includesTopResults: Bool

    /// - Parameters:
    ///   - kinds: The kinds to search, or `nil` for ``defaultKinds``. Only searchable kinds are allowed.
    ///   - limit: The most results per kind, 1 through ``maximumLimit``.
    ///   - offset: How many results to skip, 0 or more.
    /// - Throws: ``CatalogError/invalidRequest(_:)`` when an argument is out of range.
    public init(
        term: String,
        kinds: [CatalogKind]? = nil,
        limit: Int = CatalogSearchRequest.defaultLimit,
        offset: Int = 0,
        includesTopResults: Bool = false
    ) throws(CatalogError) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .invalidRequest("Search term is required.") }

        var resolved: [CatalogKind] = []
        if let kinds {
            guard !kinds.isEmpty else {
                throw .invalidRequest("Kinds must not be empty. Omit them to search songs, albums, artists and playlists.")
            }
            if let bad = kinds.first(where: { !$0.isSearchable }) {
                throw .invalidRequest("\(bad.rawValue) can't be searched for; it only appears in top results.")
            }
            for kind in kinds where !resolved.contains(kind) { resolved.append(kind) }
        } else {
            resolved = Self.defaultKinds
        }

        guard (1...Self.maximumLimit).contains(limit) else {
            throw .invalidRequest("Limit must be between 1 and \(Self.maximumLimit).")
        }
        guard offset >= 0 else { throw .invalidRequest("Offset must not be negative.") }

        self.term = trimmed
        self.kinds = resolved
        self.limit = limit
        self.offset = offset
        self.includesTopResults = includesTopResults
    }
}

/// Searches the Apple Music catalog.
///
/// ``MusicKitCatalog`` is the live implementation. Conform your own type to test code that
/// searches, since MusicKit's results can't be built by hand.
public protocol CatalogSearching: Sendable {
    /// Returns the matching items: top results first when asked for, then each kind in the
    /// order of ``CatalogSearchRequest/kinds``. An item appears once.
    func search(_ request: CatalogSearchRequest) async throws(CatalogError) -> [CatalogItem]
}
