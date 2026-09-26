import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Predicates")
struct PredicateTests {

    struct Case: @unchecked Sendable, CustomTestStringConvertible {
        let predicate: MediaItemPredicateInfo
        let property: String
        let value: NSObject
        var testDescription: String { property }
    }

    static let newCases: [Case] = [
        Case(predicate: .isCloudItem(true), property: MPMediaItemPropertyIsCloudItem, value: NSNumber(value: true)),
        Case(predicate: .hasProtectedAsset(false), property: MPMediaItemPropertyHasProtectedAsset, value: NSNumber(value: false)),
        Case(predicate: .isCompilation(true), property: MPMediaItemPropertyIsCompilation, value: NSNumber(value: true)),
        Case(predicate: .playCount(3), property: MPMediaItemPropertyPlayCount, value: NSNumber(value: 3)),
        Case(predicate: .podcastTitle("Daily"), property: MPMediaItemPropertyPodcastTitle, value: "Daily" as NSString),
        Case(predicate: .podcastID(7), property: MPMediaItemPropertyPodcastPersistentID, value: NSNumber(value: UInt64(7))),
        Case(
            predicate: .playlistAttributes(.smart), property: MPMediaPlaylistPropertyPlaylistAttributes,
            value: NSNumber(value: MPMediaPlaylistAttribute.smart.rawValue)),
        Case(predicate: .playlistCloudID("pl.123"), property: MPMediaPlaylistPropertyCloudGlobalID, value: "pl.123" as NSString),
    ]

    @Suite("Given a new filter case")
    struct Building {
        @Test("When it builds a MediaPlayer predicate, then the property and value match", arguments: PredicateTests.newCases)
        func builds(_ testCase: Case) throws {
            let predicate = try #require(testCase.predicate.predicate(using: .equalTo) as? MPMediaPropertyPredicate)
            #expect(predicate.property == testCase.property)
            #expect((predicate.value as? NSObject) == testCase.value)
        }
    }

    @Suite("Given items evaluated in memory")
    struct Matching {
        let local = StubMediaItem([MPMediaItemPropertyTitle: "Local", MPMediaItemPropertyIsCloudItem: false])
        let cloud = StubMediaItem([MPMediaItemPropertyTitle: "Cloud", MPMediaItemPropertyIsCloudItem: true])

        @Test("When filtering by isCloudItem(false), then only local items match")
        func boolFilter() {
            #expect(MediaItemPredicateInfo.isCloudItem(false).matches(local, using: .equalTo))
            #expect(!MediaItemPredicateInfo.isCloudItem(false).matches(cloud, using: .equalTo))
        }

        @Test("When a preview filters by play count, then only exact counts match")
        func previewPlayCount() async throws {
            let library: MusicLibrary = .preview(songs: [
                StubMediaItem.song("Once", plays: 1), StubMediaItem.song("Thrice", plays: 3),
            ])
            let songs = try await library.fetch(Song.query.filter(\.playCount, .equals(3)))
            #expect(songs.map(\.title) == ["Thrice"])
        }
    }

    @Suite("Given access is authorized, when fetching compilations")
    struct Compilations {
        @Test("Then it asks for music albums filtered to compilations")
        func request() async throws {
            let service = MockMusicLibraryService()
            _ = try await MusicLibrary(auth: .mock, service: service).fetch(Album.query.filter(\.isCompilation, .equals(true)))
            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filter: .init(.isCompilation(true)), grouping: .album)
                ])
        }
    }
}
