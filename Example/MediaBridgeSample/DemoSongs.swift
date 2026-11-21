import MediaPlayer
import UIKit

enum DemoSongs {
    // Store IDs are placeholders, not real Apple Music catalog IDs.
    static let all: [MPMediaItem] = [
        DemoSong(1, "Yesterday", "The Beatles", skips: 2, hue: 0.08, storeID: "1000000001"),
        DemoSong(2, "Hello", "Adele", skips: 14, hue: 0.58, storeID: "1000000002"),
        DemoSong(3, "Angie", "The Rolling Stones", skips: 7, hue: 0.95, storeID: "1000000003"),
        DemoSong(4, "Help!", "The Beatles", skips: 0, hue: 0.14, storeID: "1000000004"),
        DemoSong(5, "Rolling in the Deep", "Adele", skips: 21, hue: 0.62, storeID: "1000000005"),
        DemoSong(6, "Paint It Black", "The Rolling Stones", skips: 3, hue: 0.0, storeID: "1000000006"),
        DemoSong(7, "Here Comes the Sun", "The Beatles", skips: 1, storeID: "1000000007"),
        // A file the user added themselves: no catalog ID, no artwork, a local asset URL.
        DemoSong(8, "Garage Demo", "Me", skips: 5),
    ]
}

private final class DemoSong: MPMediaItem, @unchecked Sendable {
    private let values: [String: Any]

    init(_ id: UInt64, _ title: String, _ artist: String, skips: Int, hue: Double? = nil, storeID: String? = nil) {
        var values: [String: Any] = [
            MPMediaItemPropertyPersistentID: NSNumber(value: id),
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertySkipCount: NSNumber(value: skips),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: 180),
        ]
        if let storeID {
            values[MPMediaItemPropertyPlaybackStoreID] = storeID
            values[MPMediaItemPropertyHasProtectedAsset] = NSNumber(value: true)
        } else {
            values[MPMediaItemPropertyAssetURL] = URL(string: "ipod-library://item/item.mp3?id=\(id)")
        }
        if let hue {
            values[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) { size in
                UIGraphicsImageRenderer(size: size).image { context in
                    UIColor(hue: hue, saturation: 0.6, brightness: 0.85, alpha: 1).setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                }
            }
        }
        self.values = values
        super.init()
    }

    required init?(coder: NSCoder) { nil }

    override func value(forProperty property: String) -> Any? { values[property] }
}
