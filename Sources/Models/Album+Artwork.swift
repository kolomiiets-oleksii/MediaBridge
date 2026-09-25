#if canImport(UIKit)
    import MediaPlayer
    import UIKit

    extension Album {
        /// Renders the album's artwork at `size` points, or returns `nil` when it has none.
        public func artwork(size: CGSize) -> UIImage? {
            mediaCollection.representativeItem.flatMap { MediaArtwork.image(of: $0, size: size) }
        }
    }
#endif
