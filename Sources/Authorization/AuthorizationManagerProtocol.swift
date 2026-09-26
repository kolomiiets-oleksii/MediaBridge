//
//  AuthorizationManagerProtocol.swift
//  MediaBridge
//
//  Created by Oleksii Kolomiiets on 2/7/26.
//

import Foundation
import MediaPlayer

/// Protocol for managing access to the device's music library.
///
/// Conforming types handle requesting and checking authorization status for accessing the user's music library.
/// All authorization requests should go through this protocol to enable testing with mock implementations.
public protocol AuthorizationManagerProtocol: Sendable {
    /// Requests authorization to access the music library.
    ///
    /// Returns immediately if access is already granted. Otherwise shows the system prompt,
    /// if the user hasn't decided yet. Safe to call multiple times.
    ///
    /// - Returns: `.authorized`; any other outcome throws
    /// - Throws: ``MusicLibraryError/unauthorized(_:)`` if access is denied or restricted
    ///
    /// ## Example
    /// ```swift
    /// let manager = AuthorizationManager<MPMediaLibrary>()
    /// do {
    ///     let status = try await manager.authorize()
    ///     print("Authorization status: \(status)")
    /// } catch {
    ///     print("Authorization denied: \(error)")
    /// }
    /// ```
    @discardableResult
    func authorize() async throws -> MPMediaLibraryAuthorizationStatus

    /// Checks the current authorization status without requesting new permissions.
    ///
    /// Non-blocking call that returns the user's current authorization status.
    /// Does not trigger the authorization dialog.
    ///
    /// - Returns: The current `MPMediaLibraryAuthorizationStatus`
    ///
    /// ## Example
    /// ```swift
    /// let manager = AuthorizationManager<MPMediaLibrary>()
    /// let status = manager.status()
    /// if case .authorized = status {
    ///     // User has granted access
    /// } else {
    ///     // Not authorized, request permission
    /// }
    /// ```
    func status() -> MPMediaLibraryAuthorizationStatus
}

extension AuthorizationManagerProtocol where Self == AuthorizationManager<MPMediaLibrary> {
    public static var live: Self { AuthorizationManager() }
}
