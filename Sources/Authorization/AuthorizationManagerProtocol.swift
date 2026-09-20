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
///
/// The protocol uses an associated type `T` that conforms to `MediaLibraryProtocol` to abstract the underlying
/// media library implementation, allowing for easy testing and dependency injection.
public protocol AuthorizationManagerProtocol: Sendable {
    associatedtype T: MediaLibraryProtocol

    /// Requests authorization to access the music library.
    ///
    /// If authorization is already granted, returns immediately with `.authorized`.
    /// If not authorized, shows the system authorization dialog to the user.
    /// Safe to call multiple times.
    ///
    /// - Returns: The authorization status after the request completes
    /// - Throws: `AuthorizationManagerError.unauthorized` if the user denies access
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

extension AuthorizationManagerProtocol {
    public typealias T = MPMediaLibrary
}

extension AuthorizationManagerProtocol where Self == AuthorizationManager<T> {
    public static var live: Self { AuthorizationManager() }
}
