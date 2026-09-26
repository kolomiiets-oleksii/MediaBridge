import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Typed coverage")
struct TypedCoverageTests {

    @Suite("Given a media type other than music")
    struct MediaTypes {
        @Test("When querying songs as audiobooks, then MediaPlayer is asked for audiobooks")
        func audiobooks() async throws {
            let service = MockMusicLibraryService()
            _ = try await MusicLibrary(auth: .mock, service: service).fetch(Song.query.mediaType(.audioBook))
            #expect(service.requests == [MediaQueryRequest(mediaType: .audioBook, grouping: .title)])
        }

        @Test("When the media type is nil, then any media type matches and filters still apply")
        func anyType() async throws {
            let service = MockMusicLibraryService()
            _ = try await MusicLibrary(auth: .mock, service: service)
                .fetch(Song.query.mediaType(nil).filter(\.artist, .equals("Adele")))
            #expect(service.requests == [MediaQueryRequest(filters: [.init(.artist("Adele"))], grouping: .title)])
        }
    }

    @Suite("Given composers and podcasts")
    struct Models {
        @Test("When wrapped as a Composer, then name and ID come from the representative song")
        func composer() {
            let collection = MPMediaItemCollection(items: [
                StubMediaItem([MPMediaItemPropertyComposer: "Bach", MPMediaItemPropertyComposerPersistentID: NSNumber(value: 7)]),
                StubMediaItem([MPMediaItemPropertyComposer: "Bach"]),
            ])

            let composer = Composer(collection)

            #expect(composer.name == "Bach")
            #expect(composer.id == 7)
            #expect(composer.songCount == 2)
        }

        @Test("When wrapped as a Podcast, then title and ID come from the representative episode")
        func podcast() {
            let collection = MPMediaItemCollection(items: [
                StubMediaItem([MPMediaItemPropertyPodcastTitle: "Swift Talk", MPMediaItemPropertyPodcastPersistentID: NSNumber(value: 3)])
            ])

            let podcast = Podcast(collection)

            #expect(podcast.title == "Swift Talk")
            #expect(podcast.id == 3)
            #expect(podcast.episodes.count == 1)
        }

        @Test("When querying composers and podcasts, then each uses its media type, grouping, and filters")
        func queries() async throws {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock, service: service)

            _ = try await library.fetch(Composer.query.filter(\.name, .contains("bach")))
            _ = try await library.fetch(Podcast.query.filter(\.title, .equals("Swift Talk")))

            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, filters: [.init(.composer("bach"), .contains)], grouping: .composer),
                    MediaQueryRequest(mediaType: .podcast, filters: [.init(.podcastTitle("Swift Talk"))], grouping: .podcastTitle),
                ])
        }
    }

    @Suite("Given a query to index A–Z")
    struct Sections {
        @Test("When fetching song sections, then songs are grouped by letter and the query filters and sorts inside each")
        func songs() async throws {
            let service = MockMusicLibraryService(items: [
                StubMediaItem.song("Help!", plays: 1), StubMediaItem.song("Angie", plays: 9), StubMediaItem.song("Hello", plays: 5),
                StubMediaItem.song("Here", plays: 0),
            ])

            let sections = try await MusicLibrary(auth: .mock, service: service)
                .sections(Song.query.filter(\.playCount, .atLeast(1)).sorted(by: \.playCount, .reverse))

            #expect(sections.map(\.title) == ["A", "H"])
            #expect(sections[1].elements.map(\.title) == ["Hello", "Help!"])
        }

        @Test("When a filter empties a section, then the section is dropped")
        func dropsEmpty() async throws {
            let service = MockMusicLibraryService(items: [StubMediaItem.song("Angie", plays: 0), StubMediaItem.song("Hello", plays: 5)])

            let sections = try await MusicLibrary(auth: .mock, service: service).sections(Song.query.filter(\.playCount, .atLeast(1)))

            #expect(sections.map(\.title) == ["H"])
        }

        @Test("When fetching album sections, then albums are grouped by album title")
        func albums() async throws {
            let zebra = MPMediaItemCollection(items: [StubMediaItem([MPMediaItemPropertyAlbumTitle: "Zebra"])])
            let abbey = MPMediaItemCollection(items: [StubMediaItem([MPMediaItemPropertyAlbumTitle: "Abbey Road"])])
            let service = MockMusicLibraryService(collections: [.album: [zebra, abbey]])

            let sections = try await MusicLibrary(auth: .mock, service: service).sections(Album.query)

            #expect(sections.map(\.title) == ["A", "Z"])
            #expect(sections.map { $0.elements.map(\.title) } == [["Abbey Road"], ["Zebra"]])
        }
    }
}
