import MediaPlayer
import SwiftUI

extension EnvironmentValues {
    /// The player that ``NowPlaying`` and your views control. Defaults to
    /// `MPMusicPlayerController.applicationMusicPlayer`, which plays inside your app without
    /// changing the Music app's queue.
    @Entry public var musicPlayer: any MusicPlayerProtocol = MPMusicPlayerController.applicationMusicPlayer
}

extension View {
    /// Sets the player that ``NowPlaying`` and ``SwiftUICore/EnvironmentValues/musicPlayer`` use in
    /// this view hierarchy.
    ///
    /// ```swift
    /// ContentView()
    ///     .musicPlayer(MPMusicPlayerController.systemMusicPlayer)   // control the Music app
    /// ```
    public func musicPlayer(_ player: any MusicPlayerProtocol) -> some View {
        environment(\.musicPlayer, player)
    }
}
