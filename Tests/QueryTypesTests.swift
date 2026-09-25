import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Query types")
struct QueryTypesTests {

    @Suite("Given access is authorized, when fetching")
    struct Requests {
        let service = MockMusicLibraryService()
        var library: MusicLibrary { MusicLibrary(auth: .mock, service: service) }

        @Test("genres(), then it asks for music collections grouped by genre")
        func genres() async throws {
            _ = try await library.genres()
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .genre)])
        }

        @Test("composers(), then it asks for music collections grouped by composer")
        func composers() async throws {
            _ = try await library.composers()
            #expect(service.requests == [MediaQueryRequest(mediaType: .music, grouping: .composer)])
        }

        @Test("podcasts(), then it asks for podcast collections grouped by podcast title")
        func podcasts() async throws {
            _ = try await library.podcasts()
            #expect(service.requests == [MediaQueryRequest(mediaType: .podcast, grouping: .podcastTitle)])
        }

        @Test("audiobooks(), then it asks for audiobook items grouped by title")
        func audiobooks() async throws {
            _ = try await library.audiobooks()
            #expect(service.requests == [MediaQueryRequest(mediaType: .audioBook, grouping: .title)])
        }

        @Test("a custom request, then it reaches the service unchanged")
        func customRequest() async throws {
            let request = MediaQueryRequest(mediaType: .anyAudio, filter: .init(.genre("Jazz")), grouping: .albumArtist)
            _ = try await library.collections(request)
            _ = try await library.items(request)
            #expect(service.requests == [request, request])
        }
    }

    @Suite("Given the service returns genres")
    struct Sorting {
        @Test("When sorted by item count in reverse, then the biggest genre comes first")
        func sortsByCount() async throws {
            let small = MPMediaItemCollection(items: [StubMediaItem.song("A")])
            let big = MPMediaItemCollection(items: [StubMediaItem.song("B"), StubMediaItem.song("C")])
            let service = MockMusicLibraryService(collections: [.genre: [small, big]])
            let library = MusicLibrary(auth: .mock, service: service)

            let genres = try await library.genres(sortedBy: \MPMediaItemCollection.count, order: .reverse)

            #expect(genres.map(\.count) == [2, 1])
        }
    }

    @Suite("Given access is not authorized")
    struct Unauthorized {
        @Test("When fetching with a custom request, then the service is never queried")
        func guarded() async {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: service)

            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) {
                _ = try await library.collections(MediaQueryRequest(grouping: .genre))
            }
            #expect(service.requests.isEmpty)
        }
    }

    @Suite("Given a conformer written before 0.12")
    struct DefaultImplementations {
        @Test("When asking for unfiltered items, then fetchAll receives the type and grouping")
        func itemsWithoutFilter() async throws {
            let library = RecordingLibrary()
            _ = try await library.items(MediaQueryRequest(mediaType: .podcast, grouping: .album))
            #expect(library.calls == ["fetchAll podcast album"])
        }

        @Test("When asking for filtered items, then mediaItems receives the filter")
        func itemsWithFilter() async throws {
            let library = RecordingLibrary()
            _ = try await library.items(MediaQueryRequest(mediaType: .music, filter: .init(.artist("X"), .contains), grouping: .title))
            #expect(library.calls == ["mediaItems music artist contains title"])
        }

        @Test("When asking for genres, then mediaItemCollections receives a media-type filter")
        func genres() async throws {
            let library = RecordingLibrary()
            _ = try await library.genres()
            #expect(library.calls == ["mediaItemCollections music mediaType equalTo genre"])
        }
    }
}

/// Implements only the pre-0.12 requirements and records how the default implementations call them.
private final class RecordingLibrary: MusicLibraryProtocol, @unchecked Sendable {
    var calls: [String] = []

    private func name(_ type: MPMediaType) -> String {
        switch type {
        case .music: "music"
        case .podcast: "podcast"
        default: "\(type.rawValue)"
        }
    }

    private func name(_ grouping: MPMediaGrouping) -> String {
        switch grouping {
        case .title: "title"
        case .album: "album"
        case .genre: "genre"
        default: "\(grouping.rawValue)"
        }
    }

    private func name(_ predicate: MediaItemPredicateInfo) -> String {
        switch predicate {
        case .artist: "artist"
        case .mediaType: "mediaType"
        default: "other"
        }
    }

    private func name(_ comparison: MPMediaPredicateComparison) -> String {
        comparison == .contains ? "contains" : "equalTo"
    }

    var authorizationStatus: MPMediaLibraryAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> MPMediaLibraryAuthorizationStatus { .authorized }
    func fetchAll(_ type: MPMediaType, groupingType: MPMediaGrouping) async throws -> [MPMediaItem] {
        calls.append("fetchAll \(name(type)) \(name(groupingType))")
        return []
    }
    func mediaItems(ofType type: MPMediaType, matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItem] {
        calls.append("mediaItems \(name(type)) \(name(predicate)) \(name(comparisonType)) \(name(groupingType))")
        return []
    }
    func mediaItemCollections(ofType type: MPMediaType, matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItemCollection] {
        calls.append("mediaItemCollections \(name(type)) \(name(predicate)) \(name(comparisonType)) \(name(groupingType))")
        return []
    }
    func songs<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaItem, T>?, order: SortOrder) async throws -> [MPMediaItem] { [] }
    func songs(matching predicate: MediaItemPredicateInfo, comparisonType: MPMediaPredicateComparison) async throws -> [MPMediaItem] { [] }
    func albums(matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItemCollection] { [] }
    func albums<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?, order: SortOrder) async throws -> [MPMediaItemCollection] { [] }
    func artists(matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison, groupingType: MPMediaGrouping) async throws -> [MPMediaItemCollection] { [] }
    func artists<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaItemCollection, T>?, order: SortOrder) async throws -> [MPMediaItemCollection] { [] }
    func playlists(matching predicate: MediaItemPredicateInfo, _ comparisonType: MPMediaPredicateComparison) async throws -> [MPMediaPlaylist] { [] }
    func playlists<T: Comparable>(sortedBy sortingKey: SortKey<MPMediaPlaylist, T>?, order: SortOrder) async throws -> [MPMediaPlaylist] { [] }
}
