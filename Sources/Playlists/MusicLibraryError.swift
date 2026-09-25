import Foundation

/// Errors thrown by playlist writes.
public enum MusicLibraryError: Error, LocalizedError, Equatable {
    /// MediaPlayer neither found nor created the playlist with this ID.
    case playlistUnavailable(UUID)

    /// The library or its service was written before playlist writes existed and doesn't
    /// implement them.
    case writesUnsupported

    public var errorDescription: String? {
        switch self {
        case .playlistUnavailable:
            "The playlist couldn't be found or created."
        case .writesUnsupported:
            "This music library can't create or change playlists."
        }
    }
}
