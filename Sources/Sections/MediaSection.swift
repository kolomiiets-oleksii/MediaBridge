import Foundation
import MediaPlayer

/// A titled run of query results, such as all songs starting with "A", for building an index
/// like the Music app's A–Z sidebar.
public struct MediaSection<Element> {
    /// The section's index title, usually a letter, or `#` for everything else.
    public let title: String
    /// The results in this section, in query order.
    public let elements: [Element]

    public init(title: String, elements: [Element]) {
        self.title = title
        self.elements = elements
    }
}

extension MediaSection: Sendable where Element: Sendable {}
extension MediaSection: Equatable where Element: Equatable {}

extension MediaSection {
    static var otherTitle: String { "#" }

    /// Groups elements by the first letter of their title, folding case and diacritics. Letter
    /// sections are sorted alphabetically, followed by `#` for titles that don't start with a letter.
    static func alphabetical(_ elements: [Element], title: (Element) -> String?) -> [MediaSection] {
        var order: [String] = []
        var groups: [String: [Element]] = [:]
        for element in elements {
            let key = indexTitle(for: title(element))
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(element)
        }
        let sortedKeys = order.sorted { lhs, rhs in
            if lhs == otherTitle { return false }
            if rhs == otherTitle { return true }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
        return sortedKeys.map { MediaSection(title: $0, elements: groups[$0] ?? []) }
    }

    private static func indexTitle(for title: String?) -> String {
        guard let first = title?.first, first.isLetter else { return otherTitle }
        return String(first).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).uppercased()
    }
}

extension MediaSection where Element == MPMediaItem {
    static func alphabetical(_ items: [MPMediaItem], grouping: MPMediaGrouping) -> [MediaSection] {
        let property = MPMediaItem.titleProperty(forGroupingType: grouping)
        return alphabetical(items) { $0.value(forProperty: property) as? String }
    }
}

extension MediaSection where Element == MPMediaItemCollection {
    static func alphabetical(_ collections: [MPMediaItemCollection], grouping: MPMediaGrouping) -> [MediaSection] {
        let property = MPMediaItem.titleProperty(forGroupingType: grouping)
        return alphabetical(collections) { collection in
            (collection as? MPMediaPlaylist)?.name
                ?? collection.representativeItem?.value(forProperty: property) as? String
        }
    }
}
