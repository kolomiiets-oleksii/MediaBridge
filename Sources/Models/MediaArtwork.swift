#if canImport(UIKit)
    import MediaPlayer
    import UIKit

    enum MediaArtwork {
        static func image(of item: MPMediaItem, size: CGSize) -> UIImage? {
            (item.value(forProperty: MPMediaItemPropertyArtwork) as? MPMediaItemArtwork)?.image(at: size)
        }
    }
#endif
