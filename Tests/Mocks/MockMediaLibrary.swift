import MediaBridge
import MediaPlayer

final class MockMediaLibraryNotDetermined: MediaLibraryProtocol {
    static func authorizationStatus() -> MPMediaLibraryAuthorizationStatus { .notDetermined }
    static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus { .notDetermined }
}

final class MockMediaLibraryAuthorized: MediaLibraryProtocol {
    static func authorizationStatus() -> MPMediaLibraryAuthorizationStatus { .authorized }
    static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus { .authorized }
}

final class MockMediaLibraryDenied_Denied: MediaLibraryProtocol {
    static func authorizationStatus() -> MPMediaLibraryAuthorizationStatus { .denied }
    static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus { .denied }
}

final class MockMediaLibraryDenied_Authorized: MediaLibraryProtocol {
    static func authorizationStatus() -> MPMediaLibraryAuthorizationStatus { .denied }
    static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus { .authorized }
}

final class MockMediaLibraryRestricted: MediaLibraryProtocol {
    static func authorizationStatus() -> MPMediaLibraryAuthorizationStatus { .restricted }
    static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus { .restricted }
}
