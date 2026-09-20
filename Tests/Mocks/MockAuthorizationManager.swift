import MediaPlayer

@testable import MediaBridge

final class MockAuthorizationManager: AuthorizationManagerProtocol {
    init(isAuthorized: Bool, authStatus: MPMediaLibraryAuthorizationStatus, authError: MockAuthError?) {
        self.isAuthorized = isAuthorized
        self.authStatus = authStatus
        self.authError = authError
    }

    let isAuthorized: Bool
    let authError: MockAuthError?
    func authorize() async throws -> MPMediaLibraryAuthorizationStatus {
        guard let authError else { return isAuthorized ? .authorized : .denied }
        throw authError
    }

    let authStatus: MPMediaLibraryAuthorizationStatus
    func status() -> MPMediaLibraryAuthorizationStatus { authStatus }

    enum MockAuthError: Error {
        case mockError
    }
}

extension AuthorizationManagerProtocol where Self == MockAuthorizationManager {
    static var mock: Self { .mock() }
    static func mock(
        isAuthorized: Bool = true,
        authError: MockAuthorizationManager.MockAuthError? = nil,
        authStatus: MPMediaLibraryAuthorizationStatus = .authorized
    ) -> Self {
        MockAuthorizationManager(isAuthorized: isAuthorized, authStatus: authStatus, authError: authError)
    }
}
