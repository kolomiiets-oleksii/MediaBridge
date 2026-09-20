import MediaPlayer

@testable import MediaBridge

class MockMediaQueryWithFewMedia: MediaQueryProtocol {
    var items: [MPMediaItem]?
    var collections: [MPMediaItemCollection]?
    var groupingType: MPMediaGrouping

    required init(filterPredicates: Set<MPMediaPredicate>? = nil) {
        items = [.mock, .mock]
        collections = [.mock, .mock]
        groupingType = .title
    }
}

class MockMediaQueryWithNoMedia: MediaQueryProtocol {
    var items: [MPMediaItem]?
    var collections: [MPMediaItemCollection]?
    var groupingType: MPMediaGrouping

    required init(filterPredicates: Set<MPMediaPredicate>? = nil) {
        items = []
        collections = []
        groupingType = .title
    }
}

class MockMediaQueryWithNilMedia: MediaQueryProtocol {
    var items: [MPMediaItem]?
    var collections: [MPMediaItemCollection]?
    var groupingType: MPMediaGrouping

    required init(filterPredicates: Set<MPMediaPredicate>? = nil) {
        items = nil
        collections = nil
        groupingType = .title
    }
}

class MockMediaQueryCapturingPredicates: MediaQueryProtocol {
    nonisolated(unsafe) static var lastFilterPredicates: Set<MPMediaPredicate>?

    var items: [MPMediaItem]?
    var collections: [MPMediaItemCollection]?
    var groupingType: MPMediaGrouping

    required init(filterPredicates: Set<MPMediaPredicate>? = nil) {
        Self.lastFilterPredicates = filterPredicates
        items = [.mock]
        collections = [.mock]
        groupingType = .title
    }

    static func propertyPredicate(forProperty property: String) -> MPMediaPropertyPredicate? {
        lastFilterPredicates?
            .compactMap { $0 as? MPMediaPropertyPredicate }
            .first { $0.property == property }
    }
}
