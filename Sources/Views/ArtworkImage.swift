#if canImport(UIKit)
    import MediaPlayer
    import SwiftUI

    /// A square artwork view that loads when it appears and shows a placeholder until then, or
    /// when the song or album has no artwork.
    ///
    /// The image is decoded off the main thread, and VoiceOver skips the view, since the title
    /// beside it carries the meaning.
    ///
    /// ```swift
    /// List(songs) { song in
    ///     HStack {
    ///         ArtworkImage(song, size: 44)
    ///         Text(song.title ?? "")
    ///     }
    /// }
    /// ```
    public struct ArtworkImage: View {
        private let id: ObjectIdentifier
        private let render: @MainActor (CGSize) -> UIImage?
        private let size: Double
        @State private var image: UIImage?

        public init(_ song: Song, size: Double) {
            id = ObjectIdentifier(song.mediaItem)
            render = { song.artwork(size: $0) }
            self.size = size
        }

        public init(_ album: Album, size: Double) {
            id = ObjectIdentifier(album.mediaCollection)
            render = { album.artwork(size: $0) }
            self.size = size
        }

        public var body: some View {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note").foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size / 8, style: .continuous))
            .accessibilityHidden(true)
            .task(id: id) {
                image = await render(CGSize(width: size, height: size))?.byPreparingForDisplay()
            }
        }
    }
#endif
