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
    /// Leave out the size to fill the width the layout offers, such as a grid cell:
    ///
    /// ```swift
    /// LazyVGrid(columns: [GridItem(), GridItem()]) {
    ///     ForEach(albums) { album in
    ///         ArtworkImage(album, cornerRadius: 8)
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
        let size: Double?
        private let cornerRadius: Double?

        /// Creates the artwork view for a song.
        /// - Parameters:
        ///   - song: The song whose artwork to show.
        ///   - size: The width and height, in points.
        ///   - cornerRadius: The radius of the rounded corners. Defaults to an eighth of `size`.
        public init(_ song: Song, size: Double, cornerRadius: Double? = nil) {
            self.init(song, fixedSize: size, cornerRadius: cornerRadius)
        }

        /// Creates the artwork view for an album.
        /// - Parameters:
        ///   - album: The album whose artwork to show.
        ///   - size: The width and height, in points.
        ///   - cornerRadius: The radius of the rounded corners. Defaults to an eighth of `size`.
        public init(_ album: Album, size: Double, cornerRadius: Double? = nil) {
            self.init(album, fixedSize: size, cornerRadius: cornerRadius)
        }

        /// Creates the artwork view for a song, as wide as the layout offers and as tall as it is
        /// wide. The artwork renders at the laid-out width rounded up to a multiple of 64 points,
        /// and again only when the width crosses to another multiple.
        /// - Parameters:
        ///   - song: The song whose artwork to show.
        ///   - cornerRadius: The radius of the rounded corners. Defaults to an eighth of the width.
        public init(_ song: Song, cornerRadius: Double? = nil) {
            self.init(song, fixedSize: nil, cornerRadius: cornerRadius)
        }

        /// Creates the artwork view for an album, as wide as the layout offers and as tall as it is
        /// wide. The artwork renders at the laid-out width rounded up to a multiple of 64 points,
        /// and again only when the width crosses to another multiple.
        /// - Parameters:
        ///   - album: The album whose artwork to show.
        ///   - cornerRadius: The radius of the rounded corners. Defaults to an eighth of the width.
        public init(_ album: Album, cornerRadius: Double? = nil) {
            self.init(album, fixedSize: nil, cornerRadius: cornerRadius)
        }

        private init(_ song: Song, fixedSize: Double?, cornerRadius: Double?) {
            id = ObjectIdentifier(song.mediaItem)
            render = { song.artwork(size: $0) }
            size = fixedSize
            self.cornerRadius = cornerRadius
        }

        private init(_ album: Album, fixedSize: Double?, cornerRadius: Double?) {
            id = ObjectIdentifier(album.mediaCollection)
            render = { album.artwork(size: $0) }
            size = fixedSize
            self.cornerRadius = cornerRadius
        }

        func cornerRadius(side: Double) -> Double {
            cornerRadius ?? side / 8
        }

        public var body: some View {
            placeholder { DefaultArtworkPlaceholder() }
        }

        /// Shows `content` while the artwork loads, and when there is none.
        ///
        /// The placeholder is framed and clipped like the artwork.
        public func placeholder<Placeholder: View>(@ViewBuilder _ content: () -> Placeholder) -> some View {
            ArtworkView(id: id, render: render, size: size, fixedCornerRadius: cornerRadius, placeholder: content())
        }
    }

    struct ArtworkRequest: Equatable {
        let id: ObjectIdentifier
        let side: Double

        static func flexibleSide(for width: Double) -> Double {
            (width / 64).rounded(.up) * 64
        }
    }

    struct ArtworkView<Placeholder: View>: View {
        let id: ObjectIdentifier
        let render: @MainActor (CGSize) -> UIImage?
        let size: Double?
        let fixedCornerRadius: Double?
        let placeholder: Placeholder

        func cornerRadius(side: Double) -> Double {
            fixedCornerRadius ?? side / 8
        }

        var body: some View {
            if let size {
                ArtworkSquare(
                    id: id, render: render, side: size, renderSide: size,
                    cornerRadius: cornerRadius(side: size), placeholder: placeholder)
            } else {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        GeometryReader { proxy in
                            let side = proxy.size.width
                            ArtworkSquare(
                                id: id, render: render, side: side, renderSide: ArtworkRequest.flexibleSide(for: side),
                                cornerRadius: cornerRadius(side: side), placeholder: placeholder)
                        }
                    }
            }
        }
    }

    struct ArtworkSquare<Placeholder: View>: View {
        let id: ObjectIdentifier
        let render: @MainActor (CGSize) -> UIImage?
        let side: Double
        let renderSide: Double
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
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
            .task(id: ArtworkRequest(id: id, side: renderSide)) {
                guard renderSide > 0 else { return }
                image = await render(CGSize(width: renderSide, height: renderSide))?.byPreparingForDisplay()
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
