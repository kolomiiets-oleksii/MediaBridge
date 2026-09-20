import Foundation
import MediaPlayer

extension Array {
    func sortedByFlagFalseFirst(_ key: FlagKey<Element>?, order: SortOrder) -> [Element] {
        guard let key else { return self }

        return sorted { lhs, rhs in
            let lhs = lhs[keyPath: key]
            let rhs = rhs[keyPath: key]

            return order == .forward ? (!lhs && rhs) : (lhs && !rhs)
        }
    }
}

// MARK: - Boolean sorting

extension MusicLibraryProtocol {
    /// Fetches all songs sorted by a boolean key path, such as `\MPMediaItem.isExplicitItem`.
    ///
    /// In `.forward` order, `false` comes first.
    ///
    /// - Parameters:
    ///   - sortingKey: The boolean key path to sort by, or `nil` to leave the order untouched
    ///   - order: The sort order
    /// - Returns: Array of songs sorted by the key path
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    public func songs(
        sortedBy sortingKey: FlagKey<MPMediaItem>?,
        order: SortOrder
    ) async throws -> [MPMediaItem] {
        try await songs().sortedByFlagFalseFirst(sortingKey, order: order)
    }

    /// Fetches all albums sorted by a boolean key path.
    ///
    /// In `.forward` order, `false` comes first.
    ///
    /// - Parameters:
    ///   - sortingKey: The boolean key path to sort by, or `nil` to leave the order untouched
    ///   - order: The sort order
    /// - Returns: Array of albums sorted by the key path
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    public func albums(
        sortedBy sortingKey: FlagKey<MPMediaItemCollection>?,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await albums().sortedByFlagFalseFirst(sortingKey, order: order)
    }

    /// Fetches all artists sorted by a boolean key path.
    ///
    /// In `.forward` order, `false` comes first.
    ///
    /// - Parameters:
    ///   - sortingKey: The boolean key path to sort by, or `nil` to leave the order untouched
    ///   - order: The sort order
    /// - Returns: Array of artists sorted by the key path
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    public func artists(
        sortedBy sortingKey: FlagKey<MPMediaItemCollection>?,
        order: SortOrder
    ) async throws -> [MPMediaItemCollection] {
        try await artists().sortedByFlagFalseFirst(sortingKey, order: order)
    }

    /// Fetches all playlists sorted by a boolean key path.
    ///
    /// In `.forward` order, `false` comes first.
    ///
    /// - Parameters:
    ///   - sortingKey: The boolean key path to sort by, or `nil` to leave the order untouched
    ///   - order: The sort order
    /// - Returns: Array of playlists sorted by the key path
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if music library access is not authorized
    public func playlists(
        sortedBy sortingKey: FlagKey<MPMediaPlaylist>?,
        order: SortOrder
    ) async throws -> [MPMediaPlaylist] {
        try await playlists().sortedByFlagFalseFirst(sortingKey, order: order)
    }
}
