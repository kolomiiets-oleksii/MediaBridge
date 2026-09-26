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
    ///
    /// Replace the default placeholder with ``placeholder(_:)``:
    ///
    /// ```swift
    /// ArtworkImage(song, size: 48, cornerRadius: 4)
    ///     .placeholder { Image("logo").resizable().padding(8) }
    /// ```
    public struct ArtworkImage: View {
        private let id: ObjectIdentifier
        private let render: @MainActor (CGSize) -> UIImage?
        private let size: Double
        let cornerRadius: Double

        /// Creates the artwork view for a song.
        /// - Parameters:
        ///   - song: The song whose artwork to show.
        ///   - size: The width and height, in points.
        ///   - cornerRadius: The radius of the rounded corners. Defaults to an eighth of `size`.
        public init(_ song: Song, size: Double, cornerRadius: Double? = nil) {
            id = ObjectIdentifier(song.mediaItem)
            render = { song.artwork(size: $0) }
            self.size = size
            self.cornerRadius = cornerRadius ?? size / 8
        }

        /// Creates the artwork view for an album.
        /// - Parameters:
        ///   - album: The album whose artwork to show.
        ///   - size: The width and height, in points.
        ///   - cornerRadius: The radius of the rounded corners. Defaults to an eighth of `size`.
        public init(_ album: Album, size: Double, cornerRadius: Double? = nil) {
            id = ObjectIdentifier(album.mediaCollection)
            render = { album.artwork(size: $0) }
            self.size = size
            self.cornerRadius = cornerRadius ?? size / 8
        }

        public var body: some View {
            placeholder { DefaultArtworkPlaceholder() }
        }

        /// Shows `content` while the artwork loads, and when there is none.
        ///
        /// The placeholder is framed and clipped like the artwork.
        public func placeholder<Placeholder: View>(@ViewBuilder _ content: () -> Placeholder) -> some View {
            ArtworkView(id: id, render: render, size: size, cornerRadius: cornerRadius, placeholder: content())
        }
    }

    struct ArtworkView<Placeholder: View>: View {
        let id: ObjectIdentifier
        let render: @MainActor (CGSize) -> UIImage?
        let size: Double
        let cornerRadius: Double
        let placeholder: Placeholder
        @State private var image: UIImage?

        var body: some View {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
            .task(id: id) {
                image = await render(CGSize(width: size, height: size))?.byPreparingForDisplay()
            }
        }
    }

    struct DefaultArtworkPlaceholder: View {
        var body: some View {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "music.note").foregroundStyle(.secondary)
                }
        }
    }
#endif
