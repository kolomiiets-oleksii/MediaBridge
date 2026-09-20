import MediaPlayer

/// Protocol for abstracting the underlying media library implementation.
///
/// This protocol defines the interface for requesting and checking authorization status
/// with the system's media library. It allows `AuthorizationManager` to be testable
/// by enabling dependency injection of different media library implementations.
///
/// ## Conforming Types
/// - `MPMediaLibrary`: Apple's default implementation
/// - Mock implementations for testing
public protocol MediaLibraryProtocol {
    /// Requests authorization to access the music library.
    ///
    /// Shows the system authorization dialog to the user if not yet authorized.
    ///
    /// - Returns: The authorization status after the request
    static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus

    /// Returns the current authorization status without requesting new permissions.
    ///
    /// Non-blocking call that does not trigger any dialogs.
    ///
    /// - Returns: The current authorization status
    static func authorizationStatus() -> MPMediaLibraryAuthorizationStatus
}

/// Extension making `MPMediaLibrary` conform to `MediaLibraryProtocol`.
///
/// This allows `AuthorizationManager` to work with Apple's native media library
/// while maintaining the ability to use mock implementations for testing.
extension MPMediaLibrary: MediaLibraryProtocol { }
