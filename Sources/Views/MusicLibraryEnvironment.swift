import SwiftUI

extension EnvironmentValues {
    /// The library that ``MediaQuery`` and your views read from. Defaults to the device's library.
    @Entry public var musicLibrary: any MusicLibraryProtocol = deviceLibrary
}

extension View {
    /// Sets the library that ``MediaQuery`` and ``SwiftUICore/EnvironmentValues/musicLibrary`` read in
    /// this view hierarchy, such as a preview library.
    ///
    /// ```swift
    /// #Preview {
    ///     SongList()
    ///         .musicLibrary(.preview(songs: previewSongs))
    /// }
    /// ```
    public func musicLibrary(_ library: any MusicLibraryProtocol) -> some View {
        environment(\.musicLibrary, library)
    }
}

private let deviceLibrary = MusicLibrary()
