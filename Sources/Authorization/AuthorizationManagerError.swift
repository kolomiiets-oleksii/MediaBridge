import Foundation
import MediaPlayer

/// Errors that can occur during music library authorization.
///
/// These errors are thrown when authorization requests fail or are denied.
/// All cases conform to `LocalizedError` for user-friendly error messages.
public enum AuthorizationManagerError: Error, LocalizedError {
    /// The user denied access to the music library or authorization failed.
    ///
    /// The associated value contains the authorization status description
    /// for debugging purposes (e.g., "denied", "restricted", "notDetermined").
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     try await authManager.authorize()
    /// } catch AuthorizationManagerError.unauthorized(let status) {
    ///     print("Authorization failed with status: \(status)")
    /// }
    /// ```
    case unauthorized(MPMediaLibraryAuthorizationStatus)

    /// A human-readable description of the error suitable for displaying to users.
    ///
    /// Returns a localized error message that can be shown in the UI, explaining why access was denied.
    public var errorDescription: String? {
        switch self {
        case .unauthorized(let status):
            buildUserFriendlyMessage(for: status)
        }
    }

    private func buildUserFriendlyMessage(for status: MPMediaLibraryAuthorizationStatus) -> String {
        switch status {
        case .denied:
            "You've denied access to your music library. Enable access in Settings to use this feature."
        case .restricted:
            "Access to your music library is restricted. This may be due to parental controls or device settings."
        case .notDetermined:
            "Unable to request music library access. Please try again."
        default:
            "Unable to access your music library (\(status)). Please check your device settings."
        }
    }
}

extension AuthorizationManagerError: Equatable {
    public static func == (lhs: AuthorizationManagerError, rhs: AuthorizationManagerError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized(let l), .unauthorized(let r)): l == r
        }
    }
}
