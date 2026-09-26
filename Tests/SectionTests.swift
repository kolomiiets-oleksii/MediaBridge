import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Sections")
struct SectionTests {

    @Suite("Given elements grouped in memory")
    struct Alphabetical {
        @Test("When titles start with letters, digits and accents, then sections are A–Z with # last")
        func groupsByLetter() {
            let titles = ["beta", "42 Days", "Alpha", "Ábaco", "Zulu", "!Bang"]

            let sections = MediaSection.alphabetical(titles, title: { $0 })

            #expect(sections.map(\.title) == ["A", "B", "Z", "#"])
            #expect(sections[0].elements == ["Alpha", "Ábaco"])
            #expect(sections[3].elements == ["42 Days", "!Bang"])
        }

        @Test("When a title is missing, then the element goes under #")
        func missingTitle() {
            let sections = MediaSection.alphabetical([nil, "Alpha"] as [String?], title: { $0 })
            #expect(sections.map(\.title) == ["A", "#"])
        }
    }

    @Suite("Given the live service")
    struct Service {
        @Test("When MediaPlayer reports sections, then each covers its range of results")
        func usesQuerySections() async throws {
            let service = MusicLibraryService<MockMediaQueryWithSections>()

            let sections = try await service.itemSections(MediaQueryRequest(mediaType: .music, grouping: .title))

            #expect(sections.map(\.title) == ["A", "B"])
            #expect(sections.map(\.elements.count) == [1, 2])
        }

        @Test("When MediaPlayer reports no sections, then items are grouped by letter")
        func fallsBack() async throws {
            let service = MusicLibraryService<MockMediaQueryWithTitledItems>()

            let sections = try await service.itemSections(MediaQueryRequest(mediaType: .music, grouping: .title))

            #expect(sections.map(\.title) == ["A", "B"])
        }
    }

    @Suite("Given a MusicLibrary")
    struct Library {
        @Test("When fetching song sections, then songs are grouped by title letter")
        func songSections() async throws {
            let service = MockMusicLibraryService(items: [
                StubMediaItem.song("Help!"), StubMediaItem.song("Angie"), StubMediaItem.song("Hello"),
            ])
            let library = MusicLibrary(auth: .mock, service: service)

            let sections = try await library.sections(Song.query)

            #expect(sections.map(\.title) == ["A", "H"])
            #expect(sections[1].elements.map(\.title) == ["Help!", "Hello"])
        }

        @Test("When fetching album sections, then albums are grouped by album title letter")
        func albumSections() async throws {
            let zebra = MPMediaItemCollection(items: [StubMediaItem([MPMediaItemPropertyAlbumTitle: "Zebra"])])
            let abbey = MPMediaItemCollection(items: [StubMediaItem([MPMediaItemPropertyAlbumTitle: "Abbey Road"])])
            let service = MockMusicLibraryService(collections: [.album: [zebra, abbey]])
            let library = MusicLibrary(auth: .mock, service: service)

            let sections = try await library.sections(Album.query)

            #expect(sections.map(\.title) == ["A", "Z"])
        }

        @Test("When access is denied, then sections throw and the service is never queried")
        func unauthorized() async {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: service)

            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) { _ = try await library.sections(Song.query) }
            #expect(service.requests.isEmpty)
        }
    }
}

final class MockMediaQueryWithSections: MediaQueryProtocol {
    var items: [MPMediaItem]? = [StubMediaItem.song("Angie"), StubMediaItem.song("Beta"), StubMediaItem.song("Bravo")]
    var collections: [MPMediaItemCollection]? = []
    var groupingType: MPMediaGrouping = .title
    var itemSectionRanges: [(title: String, range: Range<Int>)]? = [("A", 0..<1), ("B", 1..<3)]

    required init(filterPredicates: Set<MPMediaPredicate>?) {}
}

final class MockMediaQueryWithTitledItems: MediaQueryProtocol {
    var items: [MPMediaItem]? = [StubMediaItem.song("Beta"), StubMediaItem.song("Angie")]
    var collections: [MPMediaItemCollection]? = []
    var groupingType: MPMediaGrouping = .title

    required init(filterPredicates: Set<MPMediaPredicate>?) {}
}
