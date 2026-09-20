import Foundation
import MediaPlayer

/// Default implementation of `AuthorizationManagerProtocol`.
///
/// This generic class manages the app's authorization status for accessing the device's music library.
/// The type parameter `T` specifies the underlying media library implementation (typically `MPMediaLibrary`).
/// It uses the provided media library type to handle authorization requests.
///
/// ## Generic Parameter
/// - `T`: The media library type conforming to `MediaLibraryProtocol` (e.g., `MPMediaLibrary`)
///
/// ## Instantiation
/// Use the `.live` factory property to get the default implementation:
/// ```swift
/// let manager: any AuthorizationManagerProtocol = .live
/// try await manager.authorize()  // Request authorization if needed
/// ```
///
/// For custom implementations, conform to ``AuthorizationManagerProtocol`` and inject your implementation.
public final class AuthorizationManager<T: MediaLibraryProtocol>: AuthorizationManagerProtocol, Sendable {
    /// Requests authorization to access the music library.
    ///
    /// Checks if authorization is already granted. If so, returns immediately.
    /// Otherwise, presents the system authorization dialog to the user.
    ///
    /// - Returns: `.authorized` if permission is granted
    /// - Throws: ``AuthorizationManagerError/unauthorized(_:)`` if access is denied
    @discardableResult
    public func authorize() async throws -> MPMediaLibraryAuthorizationStatus {
        guard status() != .authorized else {
            log.debug("Access to music library is already authorized")
            return .authorized
        }
        
        let status = await T.requestAuthorization()
        
        guard status == .authorized else {
            throw AuthorizationManagerError.unauthorized(status)
        }
        
        log.info("Access to music library is authorized")
        return .authorized
    }
    
    /// Returns the current authorization status for music library access.
    ///
    /// Queries the system for the current authorization status.
    /// Does not trigger any user prompts or permission dialogs.
    ///
    /// - Returns: The current ``MediaPlayer/MPMediaLibraryAuthorizationStatus``
    public func status() -> MPMediaLibraryAuthorizationStatus {
        T.authorizationStatus()
    }
}
