#if canImport(UIKit)
    import MediaPlayer
    import SwiftUI

    /// A square artwork view that loads when it appears and shows a placeholder until then, or
    /// when the song or album has no artwork.
    ///
    /// MediaPlayer renders the image and it is decoded off the main thread, then kept in an
    /// in-memory cache, so scrolling back to a row or reloading the list doesn't render it again.
    /// VoiceOver skips the view, since the title beside it carries the meaning.
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
        private let key: @Sendable () -> ArtworkKey
        private let render: @Sendable (CGSize) -> UIImage?
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
            key = { ArtworkKey(kind: .song, id: song.id) }
            render = { song.artwork(size: $0) }
            size = fixedSize
            self.cornerRadius = cornerRadius
        }

        private init(_ album: Album, fixedSize: Double?, cornerRadius: Double?) {
            key = { ArtworkKey(kind: .album, id: album.id) }
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
            ArtworkView(key: key, render: render, size: size, fixedCornerRadius: cornerRadius, placeholder: content())
        }
    }

    /// Which artwork to show. The persistent ID, not the object: a refetch returns new
    /// `MPMediaItem` instances for the same songs, and the artwork must not reload for that.
    struct ArtworkKey: Hashable, Sendable {
        enum Kind: Sendable { case song, album }
        let kind: Kind
        let id: UInt64
    }

    struct ArtworkRequest: Hashable, Sendable {
        let id: ArtworkKey
        let side: Double

        static func flexibleSide(for width: Double) -> Double {
            (width / 64).rounded(.up) * 64
        }
    }

    struct ArtworkView<Placeholder: View>: View {
        let key: @Sendable () -> ArtworkKey
        let render: @Sendable (CGSize) -> UIImage?
        let size: Double?
        let fixedCornerRadius: Double?
        let placeholder: Placeholder

        func cornerRadius(side: Double) -> Double {
            fixedCornerRadius ?? side / 8
        }

        var body: some View {
            // Read here, not when the view is built, so only visible rows touch MediaPlayer.
            let id = key()
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
        let id: ArtworkKey
        let render: @Sendable (CGSize) -> UIImage?
        let side: Double
        let renderSide: Double
        let cornerRadius: Double
        let placeholder: Placeholder
        @State private var image: UIImage?

        init(
            id: ArtworkKey, render: @escaping @Sendable (CGSize) -> UIImage?, side: Double, renderSide: Double,
            cornerRadius: Double, placeholder: Placeholder
        ) {
            self.id = id
            self.render = render
            self.side = side
            self.renderSide = renderSide
            self.cornerRadius = cornerRadius
            self.placeholder = placeholder
            // A row scrolled back into view starts with its artwork instead of the placeholder.
            _image = State(initialValue: ArtworkCache.shared.image(for: ArtworkRequest(id: id, side: renderSide)))
        }

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
                let request = ArtworkRequest(id: id, side: renderSide)
                if let cached = ArtworkCache.shared.image(for: request) {
                    image = cached
                    return
                }
                let rendered = await ArtworkCache.shared.render(request, with: render)
                guard !Task.isCancelled else { return }
                image = rendered
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
