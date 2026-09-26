import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("MusicLibraryError")
struct MusicLibraryErrorTests {

    @Suite("Given a failure")
    struct Descriptions {
        @Test("When access is denied, then the message points to Settings")
        func denied() {
            #expect(
                MusicLibraryError.unauthorized(.denied).errorDescription
                    == "You've denied access to your music library. Enable access in Settings to use this feature.")
        }

        @Test("When MediaPlayer fails, then its own message is shown")
        func underlying() {
            let error = NSError(domain: "MPErrorDomain", code: 5, userInfo: [NSLocalizedDescriptionKey: "The operation couldn't be completed."])
            #expect(MusicLibraryError.underlying(error).errorDescription == "The operation couldn't be completed.")
        }

        @Test("When two underlying errors have the same domain and code, then they're equal")
        func equality() {
            #expect(MusicLibraryError.underlying(NSError(domain: "A", code: 1)) == .underlying(NSError(domain: "A", code: 1)))
            #expect(MusicLibraryError.underlying(NSError(domain: "A", code: 1)) != .underlying(NSError(domain: "A", code: 2)))
            #expect(MusicLibraryError.unauthorized(.denied) != .unauthorized(.restricted))
        }
    }

    @Suite("Given a typed call site")
    struct Typed {
        @Test("When catching, then the error is a MusicLibraryError without casting")
        func typedCatch() async {
            let library: any MusicLibraryProtocol = MusicLibrary.accessDenied
            do {
                _ = try await library.fetch(Song.query)
                Issue.record("Expected a throw")
            } catch {
                switch error {
                case .unauthorized(let status): #expect(status == .denied)
                default: Issue.record("Unexpected \(error)")
                }
            }
        }
    }
}
