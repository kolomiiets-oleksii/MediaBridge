import Foundation
import MediaPlayer

#if DEBUG
    final class PreviewAuthorizationManager: AuthorizationManagerProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private var current: MPMediaLibraryAuthorizationStatus
        private let afterRequest: MPMediaLibraryAuthorizationStatus

        init(status: MPMediaLibraryAuthorizationStatus, statusAfterRequest: MPMediaLibraryAuthorizationStatus) {
            current = status
            afterRequest = statusAfterRequest
        }

        func status() -> MPMediaLibraryAuthorizationStatus {
            lock.withLock { current }
        }

        func authorize() async throws -> MPMediaLibraryAuthorizationStatus {
            let status = lock.withLock {
                if current != .authorized { current = afterRequest }
                return current
            }
            guard status == .authorized else {
                throw AuthorizationManagerError.unauthorized(status)
            }
            return .authorized
        }
    }
#endif
