import MediaPlayer
import UIKit

enum DemoSongs {
    static let all: [MPMediaItem] = [
        DemoSong(1, "Yesterday", "The Beatles", skips: 2, hue: 0.08),
        DemoSong(2, "Hello", "Adele", skips: 14, hue: 0.58),
        DemoSong(3, "Angie", "The Rolling Stones", skips: 7, hue: 0.95),
        DemoSong(4, "Help!", "The Beatles", skips: 0, hue: 0.14),
        DemoSong(5, "Rolling in the Deep", "Adele", skips: 21, hue: 0.62),
        DemoSong(6, "Paint It Black", "The Rolling Stones", skips: 3, hue: 0.0),
        DemoSong(7, "Here Comes the Sun", "The Beatles", skips: 1),
    ]
}

private final class DemoSong: MPMediaItem, @unchecked Sendable {
    private let values: [String: Any]

    init(_ id: UInt64, _ title: String, _ artist: String, skips: Int, hue: Double? = nil) {
        var values: [String: Any] = [
            MPMediaItemPropertyPersistentID: NSNumber(value: id),
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertySkipCount: NSNumber(value: skips),
        ]
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
