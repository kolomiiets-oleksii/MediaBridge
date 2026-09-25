#if canImport(UIKit)
    import MediaPlayer
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
#endif
