import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("MusicLibraryService")
struct MusicLibraryServiceTest {

    @Suite("Given a request, when the service builds its query")
    struct QueryBuilding {
        @Test("with a media type and a filter, then the type uses equalTo and the filter keeps its comparison")
        func typeAndFilter() async throws {
            let captures = try await captured(
                MediaQueryRequest(mediaType: .music, filter: .init(.artist("Taylor Swift"), .contains), grouping: .album))

            #expect(captures.propertyPredicate(forProperty: MPMediaItemPropertyMediaType)?.comparisonType == .equalTo)
            #expect(captures.propertyPredicate(forProperty: MPMediaItemPropertyArtist)?.comparisonType == .contains)
            #expect(captures.groupingType == .album)
        }

        @Test("with only a media type, then only the type predicate is set")
        func typeOnly() async throws {
            let captures = try await captured(MediaQueryRequest(mediaType: .music, grouping: .title))

            #expect(captures.filterPredicates?.count == 1)
            #expect(captures.propertyPredicate(forProperty: MPMediaItemPropertyMediaType) != nil)
        }

        @Test("with no media type and no filter, then the query is unfiltered")
        func unfiltered() async throws {
            let captures = try await captured(MediaQueryRequest(grouping: .playlist))

            #expect(captures.filterPredicates == nil)
            #expect(captures.groupingType == .playlist)
        }

        @Test("with a filter but no media type, then only the filter predicate is set")
        func filterOnly() async throws {
            let captures = try await captured(
                MediaQueryRequest(filter: .init(.playlistName("Chill"), .contains), grouping: .playlist), collections: true)

            #expect(captures.filterPredicates?.count == 1)
            #expect(captures.propertyPredicate(forProperty: MPMediaPlaylistPropertyName)?.comparisonType == .contains)
        }

        private func captured(_ request: MediaQueryRequest, collections: Bool = false) async throws -> QueryCaptures {
            let captures = QueryCaptures()
            let service = MusicLibraryService<MockMediaQueryCapturingPredicates>()
            try await MockMediaQueryCapturingPredicates.$captures.withValue(captures) {
                if collections {
                    _ = try await service.collections(request)
                } else {
                    _ = try await service.items(request)
                }
            }
            return captures
        }
    }

    @Suite("Given the query returns")
    struct QueryResults {
        let request = MediaQueryRequest(mediaType: .music, grouping: .album)

        @Test("results, when fetching items or collections, then they are returned")
        func results() async throws {
            let service = MusicLibraryService<MockMediaQueryWithFewMedia>()
            #expect(try await service.items(request).count == 2)
            #expect(try await service.collections(request).count == 2)
        }

        @Test("nothing, when fetching items or collections, then the result is empty")
        func empty() async throws {
            let service = MusicLibraryService<MockMediaQueryWithNoMedia>()
            #expect(try await service.items(request).isEmpty)
            #expect(try await service.collections(request).isEmpty)
        }

        @Test("nil, when fetching items or collections, then the result is empty instead of an error")
        func nilResults() async throws {
            let service = MusicLibraryService<MockMediaQueryWithNilMedia>()
            #expect(try await service.items(request).isEmpty)
            #expect(try await service.collections(request).isEmpty)
        }
    }
}

@Suite("MediaQueryRequest with several filters")
struct MultiFilterTests {
    let jazzByMiles = MediaQueryRequest(
        mediaType: .music,
        filters: [.init(.genre("Jazz")), .init(.artist("Miles"), .contains)],
        grouping: .title
    )

    @Test("Given two filters, when the live service builds its query, then both predicates join the type predicate")
    func buildsAll() async throws {
        let captures = QueryCaptures()
        try await MockMediaQueryCapturingPredicates.$captures.withValue(captures) {
            _ = try await MusicLibraryService<MockMediaQueryCapturingPredicates>().items(jazzByMiles)
        }
        #expect(captures.filterPredicates?.count == 3)
        #expect(captures.propertyPredicate(forProperty: MPMediaItemPropertyArtist)?.comparisonType == .contains)
        #expect(captures.propertyPredicate(forProperty: MPMediaItemPropertyGenre) != nil)
    }

    @Test("Given a request built with one filter, when reading filter, then it is that filter")
    func singleFilterCompatibility() {
        let request = MediaQueryRequest(mediaType: .music, filter: .init(.genre("Jazz")), grouping: .title)
        #expect(request.filters == [.init(.genre("Jazz"))])
        #expect(request.filter == .init(.genre("Jazz")))
    }

    @Test("Given two filters, when a preview answers, then items must match both")
    func previewMatchesAll() async throws {
        let library: MusicLibrary = .preview(songs: [
            StubMediaItem([MPMediaItemPropertyTitle: "So What", MPMediaItemPropertyGenre: "Jazz", MPMediaItemPropertyArtist: "Miles Davis"]),
            StubMediaItem([MPMediaItemPropertyTitle: "Take Five", MPMediaItemPropertyGenre: "Jazz", MPMediaItemPropertyArtist: "Dave Brubeck"]),
        ])
        let items = try await library.items(jazzByMiles)
        #expect(items.map(\.title) == ["So What"])
    }

    @Test("Given a pre-0.12 conformer, when asked for two filters, then the first runs in its query and the rest in memory")
    func legacyConformer() async throws {
        let library = SingleFilterLibrary(items: [
            StubMediaItem([MPMediaItemPropertyGenre: "Jazz", MPMediaItemPropertyArtist: "Miles Davis"]),
            StubMediaItem([MPMediaItemPropertyGenre: "Jazz", MPMediaItemPropertyArtist: "Dave Brubeck"]),
        ])
        let items = try await library.items(jazzByMiles)
        #expect(items.count == 1)
        #expect(library.receivedPredicate == .genre("Jazz"))
    }
}

private final class SingleFilterLibrary: MusicLibraryProtocol, @unchecked Sendable {
    let stored: [MPMediaItem]
    var receivedPredicate: MediaItemPredicateInfo?
    init(items: [MPMediaItem]) { stored = items }

    var authorizationStatus: MPMediaLibraryAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> MPMediaLibraryAuthorizationStatus { .authorized }
    func fetchAll(_ type: MPMediaType, groupingType: MPMediaGrouping) async throws -> [MPMediaItem] { stored }
    func mediaItems(ofType type: MPMediaType, matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItem] {
        receivedPredicate = predicate
        return stored
    }
    func mediaItemCollections(ofType type: MPMediaType, matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItemCollection] { [] }
    func songs<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaItem, T>?, order: SortOrder) async throws -> [MPMediaItem] { [] }
    func songs(matching predicate: MediaItemPredicateInfo, comparisonType: MPMediaPredicateComparison) async throws -> [MPMediaItem] { [] }
    func albums(matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItemCollection] { [] }
    func albums<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?, order: SortOrder) async throws -> [MPMediaItemCollection] { [] }
    func artists(matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItemCollection] { [] }
    func artists<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?, order: SortOrder) async throws -> [MPMediaItemCollection] { [] }
    func playlists(matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison) async throws -> [MPMediaPlaylist] { [] }
    func playlists<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaPlaylist, T>?, order: SortOrder) async throws -> [MPMediaPlaylist] { [] }
}
