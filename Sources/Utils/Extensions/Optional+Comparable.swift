import Foundation

/// Orders optionals so `nil` sorts before every wrapped value.
///
/// Required by sorting on optional key paths such as `\MPMediaItem.releaseDate`
/// or `\MPMediaPlaylist.name`. The ordering is total: exactly one of `a < b`,
/// `b < a`, or `a == b` holds for any pair, which is what `sorted(using:)`
/// relies on to produce a stable result.
extension Optional: @retroactive Comparable where Wrapped: Comparable {
    public static func < (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): false
        case (nil, _): true
        case (_, nil): false
        case let (lhs?, rhs?): lhs < rhs
        }
    }
}
