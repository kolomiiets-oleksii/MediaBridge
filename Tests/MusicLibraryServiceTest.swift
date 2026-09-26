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

    @Test("Given a request built with one filter, when reading filters, then it holds that filter")
    func singleFilter() {
        let request = MediaQueryRequest(mediaType: .music, filter: .init(.genre("Jazz")), grouping: .title)
        #expect(request.filters == [.init(.genre("Jazz"))])
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
}
