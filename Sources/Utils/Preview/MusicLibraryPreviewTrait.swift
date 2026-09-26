#if DEBUG
    import MediaPlayer
    import SwiftUI

    @available(iOS 18.0, visionOS 2.0, *)
    struct MusicLibraryPreviewModifier: PreviewModifier {
        let library: any MusicLibraryProtocol

        func body(content: Content, context: Void) -> some View {
            content.musicLibrary(library)
        }
    }

    @available(iOS 18.0, visionOS 2.0, *)
    extension PreviewTrait where T == Preview.ViewTraits {
        /// Runs the preview against `library`, such as `.accessDenied`.
        ///
        /// ```swift
        /// #Preview(traits: .musicLibrary(.accessDenied)) {
        ///     SongList()
        /// }
        /// ```
        public static func musicLibrary(_ library: any MusicLibraryProtocol) -> Self {
            .modifier(MusicLibraryPreviewModifier(library: library))
        }

        /// Runs the preview against a preview library with these songs and collections.
        ///
        /// ```swift
        /// #Preview(traits: .musicLibrary(songs: previewSongs)) {
        ///     SongList()
        /// }
        /// ```
        public static func musicLibrary(
            songs: [MPMediaItem] = [],
            albums: [MPMediaItemCollection] = [],
            artists: [MPMediaItemCollection] = [],
            playlists: [MPMediaPlaylist] = []
        ) -> Self {
            musicLibrary(MusicLibrary.preview(songs: songs, albums: albums, artists: artists, playlists: playlists))
        }
    }
#endif
