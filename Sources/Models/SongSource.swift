import Foundation

/// Where a song in the library came from, as far as MediaPlayer can tell.
///
/// MediaPlayer has no "source" property, so ``Song/source`` infers it from two that it does have:
///
/// | `playbackStoreID` | `hasProtectedAsset` | Source |
/// |---|---|---|
/// | missing, `""` or `"0"` | any | ``ownFile`` |
/// | catalog ID | `true` | ``appleMusic`` |
/// | catalog ID | `false` or missing | ``purchased`` |
///
/// It's a heuristic and can be wrong:
/// - A file the user added that iCloud Music Library or iTunes Match *matched* to the catalog gets
///   a store ID and an unprotected asset, so it reads as ``purchased``.
/// - A file that is still uploading or failed to match can lack a store ID even though the same
///   song exists in the catalog, so it reads as ``ownFile`` until the library syncs.
///
/// MediaPlayer can't filter on the store ID, so `.filter(\.source == .ownFile)` runs in memory
/// after the fetch.
public enum SongSource: Sendable, Hashable, CaseIterable {
    /// Streamed or downloaded from an Apple Music subscription (DRM-protected).
    case appleMusic
    /// Bought from the iTunes Store, or a user's file matched to the catalog.
    case purchased
    /// A file the user added themselves, such as an MP3 synced from a Mac, with no catalog ID.
    case ownFile
}

extension Song {
    /// Where the song came from: see ``SongSource`` for the rules and where they can be wrong.
    ///
    /// Reads `playbackStoreID`, and `hasProtectedAsset` only when there is a store ID.
    public var source: SongSource {
        guard let storeID = playbackStoreID, !storeID.isEmpty, storeID != "0" else { return .ownFile }
        return hasProtectedAsset ? .appleMusic : .purchased
    }
}
