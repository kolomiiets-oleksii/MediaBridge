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

final class QueryCaptures: @unchecked Sendable {
    var filterPredicates: Set<MPMediaPredicate>?
    var groupingType: MPMediaGrouping?

    func propertyPredicate(forProperty property: String) -> MPMediaPropertyPredicate? {
        filterPredicates?
            .compactMap { $0 as? MPMediaPropertyPredicate }
            .first { $0.property == property }
    }
}

final class MockMediaQueryCapturingPredicates: MediaQueryProtocol {
    @TaskLocal static var captures = QueryCaptures()

    var items: [MPMediaItem]?
    var collections: [MPMediaItemCollection]?
    var groupingType: MPMediaGrouping {
        didSet { Self.captures.groupingType = groupingType }
    }

    required init(filterPredicates: Set<MPMediaPredicate>? = nil) {
        Self.captures.filterPredicates = filterPredicates
        items = [.mock]
        collections = [.mock]
        groupingType = .title
    }
}
