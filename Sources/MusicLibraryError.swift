import Foundation
import MediaPlayer

/// The one error every ``MusicLibraryProtocol`` call throws.
///
/// Calls use typed throws, so a `catch` block receives a `MusicLibraryError` without casting:
///
/// ```swift
/// do {
///     songs = try await library.fetch(Song.query)
/// } catch .unauthorized(.denied) {
///     showSettingsButton = true
/// } catch {
///     message = error.localizedDescription
/// }
/// ```
public enum MusicLibraryError: Error, LocalizedError, Equatable {
    /// Access to the music library wasn't granted; the associated value is the resulting status.
    case unauthorized(MPMediaLibraryAuthorizationStatus)

    /// MediaPlayer neither found nor created the playlist with this ID.
    case playlistUnavailable(UUID)

    /// The service behind the library can't create or change playlists.
    case writesUnsupported

    /// MediaPlayer, or a custom service or authorization manager, failed with this error.
    case underlying(any Error)

    public var errorDescription: String? {
        switch self {
        case .unauthorized(.denied):
            "You've denied access to your music library. Enable access in Settings to use this feature."
        case .unauthorized(.restricted):
            "Access to your music library is restricted. This may be due to parental controls or device settings."
        case .unauthorized(.notDetermined):
            "Unable to request music library access. Please try again."
        case .unauthorized(let status):
            "Unable to access your music library (\(status)). Please check your device settings."
        case .playlistUnavailable:
            "The playlist couldn't be found or created."
        case .writesUnsupported:
            "This music library can't create or change playlists."
        case .underlying(let error):
            error.localizedDescription
        }
    }

    /// Underlying errors are equal when they share a domain and code.
    public static func == (lhs: MusicLibraryError, rhs: MusicLibraryError) -> Bool {
        switch (lhs, rhs) {
        case let (.unauthorized(l), .unauthorized(r)): l == r
        case let (.playlistUnavailable(l), .playlistUnavailable(r)): l == r
        case (.writesUnsupported, .writesUnsupported): true
        case let (.underlying(l), .underlying(r)):
            (l as NSError).domain == (r as NSError).domain && (l as NSError).code == (r as NSError).code
        default: false
        }
    }

    static func wrapping(_ error: any Error) -> MusicLibraryError {
        error as? MusicLibraryError ?? .underlying(error)
    }
}
