import MediaBridge
import MediaPlayer
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

    /// `applicationQueuePlayer` is the one whose queue can be read, for the Up Next list.
    private let player: any MusicPlayerProtocol = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoLibrary") {
            return .preview(queue: DemoSongs.all)
        }
        #endif
        return MPMusicPlayerController.applicationQueuePlayer
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .musicLibrary(library)
                .musicPlayer(player)
        }
    }
}
