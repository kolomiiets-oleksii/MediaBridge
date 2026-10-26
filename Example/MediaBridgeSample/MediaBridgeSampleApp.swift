import MediaBridge
import SwiftUI

@main
struct MediaBridgeSampleApp: App {
    private let library: MusicLibrary = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoLibrary") {
            return .preview(songs: DemoSongs.all)
        }
        #endif
        return MusicLibrary()
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .musicLibrary(library)
        }
    }
}
