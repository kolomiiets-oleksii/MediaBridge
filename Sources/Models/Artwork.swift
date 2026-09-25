#if canImport(UIKit)
    import MediaPlayer
    import SwiftUI
    import UIKit

    extension Song {
        /// Renders the song's artwork at `size` points, or returns `nil` when it has none.
        ///
        /// Nothing is stored: each call asks MediaPlayer, which serves and caches the image itself.
        /// Call it when the artwork is about to appear, or use ``ArtworkImage``.
        public func artwork(size: CGSize) -> UIImage? {
            MediaArtwork.image(of: mediaItem, size: size)
        }
    }

    extension Album {
        /// Renders the album's artwork at `size` points, or returns `nil` when it has none.
        public func artwork(size: CGSize) -> UIImage? {
            mediaCollection.representativeItem.flatMap { MediaArtwork.image(of: $0, size: size) }
        }
    }

    enum MediaArtwork {
        static func image(of item: MPMediaItem, size: CGSize) -> UIImage? {
            (item.value(forProperty: MPMediaItemPropertyArtwork) as? MPMediaItemArtwork)?.image(at: size)
        }
    }

    /// A square artwork view that loads when it appears and shows a placeholder until then, or
    /// when the song or album has no artwork.
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
        private let id: MPMediaEntityPersistentID
        private let render: @MainActor (CGSize) -> UIImage?
        private let size: CGFloat
        @State private var image: UIImage?

        public init(_ song: Song, size: CGFloat) {
            id = song.id
            render = { song.artwork(size: $0) }
            self.size = size
        }

        public init(_ album: Album, size: CGFloat) {
            id = album.id
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
                        .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size / 8, style: .continuous))
            .task(id: id) {
                image = render(CGSize(width: size, height: size))
            }
        }
    }
#endif
