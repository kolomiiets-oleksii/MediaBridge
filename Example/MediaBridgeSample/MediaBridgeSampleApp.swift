import MediaBridge
import SwiftUI

@main
struct MediaBridgeSampleApp: App {
    private let library: MusicLibrary = ProcessInfo.processInfo.arguments.contains("-demoLibrary")
        ? .preview(songs: DemoSongs.all)
        : MusicLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .musicLibrary(library)
        }
    }
}
