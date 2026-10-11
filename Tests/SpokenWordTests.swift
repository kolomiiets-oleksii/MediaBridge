import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Episodes and audiobooks")
struct SpokenWordTests {
    static func episode(
        _ title: String = "Ep", podcast: String = "Radiolab", id: UInt64 = 1, duration: Double = 1_000, bookmark: Double = 0, plays: Int = 0
    ) -> StubMediaItem {
        StubMediaItem([
            MPMediaItemPropertyPersistentID: NSNumber(value: id),
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPodcastTitle: podcast,
            MPMediaItemPropertyPodcastPersistentID: NSNumber(value: 77),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: duration),
            MPMediaItemPropertyBookmarkTime: NSNumber(value: bookmark),
            MPMediaItemPropertyPlayCount: NSNumber(value: plays),
        ])
    }

    @Suite("Given an episode")
    struct Episodes {
        @Test("When properties are read, then they come from the media item")
        func properties() {
            let episode = Episode(SpokenWordTests.episode("Pilot", id: 9, duration: 600, bookmark: 120, plays: 2))
            #expect(episode.id == 9)
            #expect(episode.title == "Pilot")
            #expect(episode.podcastTitle == "Radiolab")
            #expect(episode.podcastID == 77)
            #expect(episode.duration == 600)
            #expect(episode.bookmarkTime == 120)
            #expect(episode.playCount == 2)
        }

        @Test("When wrapped, then no property is read")
        func lazy() {
            let item = SpokenWordTests.episode()
            _ = Episode(item)
            #expect(item.reads.isEmpty)
        }

        @Test("When compared, then episodes with the same ID are equal")
        func equality() {
            #expect(Episode(SpokenWordTests.episode(id: 1)) == Episode(SpokenWordTests.episode("Other", id: 1)))
            #expect(Episode(SpokenWordTests.episode(id: 1)) != Episode(SpokenWordTests.episode(id: 2)))
        }

        @Test("When converted to a song, then it wraps the same item")
        func song() {
            let item = SpokenWordTests.episode()
            #expect(Episode(item).song.mediaItem === item)
        }

        @Test("When a property is missing, then it reads as empty")
        func missing() {
            let episode = Episode(StubMediaItem([:]))
            #expect(episode.title == nil)
            #expect(episode.bookmarkTime == 0)
            #expect(episode.releaseDate == nil)
        }
    }

    @Suite("Given an audiobook")
    struct Books {
        @Test("When properties are read, then the author is the artist")
        func properties() {
            let book = Audiobook(
                StubMediaItem([
                    MPMediaItemPropertyPersistentID: NSNumber(value: 5),
                    MPMediaItemPropertyTitle: "Dune",
                    MPMediaItemPropertyArtist: "Frank Herbert",
                    MPMediaItemPropertyBookmarkTime: NSNumber(value: 3_600),
                    MPMediaItemPropertyPlaybackDuration: NSNumber(value: 72_000),
                ]))
            #expect(book.id == 5)
            #expect(book.title == "Dune")
            #expect(book.author == "Frank Herbert")
            #expect(book.bookmarkTime == 3_600)
            #expect(book.progress == 0.05)
        }
    }

    @Suite("Given an item that remembers where it stopped")
    struct Resuming {
        func episode(duration: Double, bookmark: Double, plays: Int = 0) -> Episode {
            Episode(SpokenWordTests.episode(duration: duration, bookmark: bookmark, plays: plays))
        }

        @Test("When stopped partway, then it's in progress and the progress is the fraction")
        func partway() {
            let item = episode(duration: 1_000, bookmark: 250)
            #expect(item.progress == 0.25)
            #expect(item.isInProgress)
        }

        @Test("When never started, then it isn't in progress")
        func notStarted() {
            let item = episode(duration: 1_000, bookmark: 0)
            #expect(item.progress == 0)
            #expect(!item.isInProgress)
        }

        @Test("When the bookmark is at the end, then it's finished, not in progress")
        func finished() {
            let item = episode(duration: 1_000, bookmark: 1_000)
            #expect(item.progress == 1)
            #expect(!item.isInProgress)
        }

        @Test("When the bookmark is past the end, then progress stops at 1")
        func pastEnd() {
            #expect(episode(duration: 1_000, bookmark: 1_500).progress == 1)
        }

        @Test("When the length is unknown, then there's no progress but a bookmark still means in progress")
        func unknownLength() {
            let item = episode(duration: 0, bookmark: 30)
            #expect(item.progress == nil)
            #expect(item.isInProgress)
        }

        @Test("When played at least once, then it's played")
        func played() {
            #expect(!episode(duration: 1, bookmark: 0, plays: 0).isPlayed)
            #expect(episode(duration: 1, bookmark: 0, plays: 1).isPlayed)
        }

        @Test("When a song has a bookmark, then it resumes like any other item")
        func songs() {
            let song = Song(SpokenWordTests.episode(duration: 200, bookmark: 50))
            #expect(song.progress == 0.25)
        }
    }

    @Suite("Given the new song properties")
    struct SongProperties {
        @Test("When read, then they come from the media item")
        func read() {
            let song = Song(
                StubMediaItem([
                    MPMediaItemPropertyMediaType: NSNumber(value: MPMediaType.podcast.rawValue),
                    MPMediaItemPropertyAlbumTrackNumber: NSNumber(value: 3),
                    MPMediaItemPropertyAlbumTrackCount: NSNumber(value: 12),
                    MPMediaItemPropertyDiscNumber: NSNumber(value: 1),
                    MPMediaItemPropertyDiscCount: NSNumber(value: 2),
                    MPMediaItemPropertyLyrics: "la la",
                    MPMediaItemPropertyComments: "note",
                    MPMediaItemPropertyBeatsPerMinute: NSNumber(value: 128),
                    MPMediaItemPropertyBookmarkTime: NSNumber(value: 42.5),
                    MPMediaItemPropertyPodcastTitle: "Show",
                    MPMediaItemPropertyPodcastPersistentID: NSNumber(value: 8),
                    MPMediaItemPropertyAssetURL: URL(string: "ipod-library://item/item.mp3?id=1")!,
                ]))
            #expect(song.mediaType == .podcast)
            #expect(song.trackNumber == 3)
            #expect(song.trackCount == 12)
            #expect(song.discNumber == 1)
            #expect(song.discCount == 2)
            #expect(song.lyrics == "la la")
            #expect(song.comments == "note")
            #expect(song.beatsPerMinute == 128)
            #expect(song.bookmarkTime == 42.5)
            #expect(song.podcastTitle == "Show")
            #expect(song.podcastID == 8)
            #expect(song.assetURL?.scheme == "ipod-library")
        }

        @Test("When they're missing, then numbers are 0 and text is nil")
        func missing() {
            let song = Song(StubMediaItem([:]))
            #expect(song.trackNumber == 0)
            #expect(song.bookmarkTime == 0)
            #expect(song.lyrics == nil)
            #expect(song.assetURL == nil)
            #expect(song.mediaType.rawValue == 0)
        }
    }

    @Suite("Given queries")
    struct Queries {
        let service = MockMusicLibraryService()
        var library: MusicLibrary { MusicLibrary(auth: .mock, service: service) }

        @Test("When fetching episodes and books, then each asks for its media type")
        func requests() async throws {
            _ = try await library.fetch(.episodes)
            _ = try await library.fetch(.books)

            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .podcast, grouping: .title),
                    MediaQueryRequest(mediaType: .audioBook, grouping: .title),
                ])
        }

        @Test("When filtering episodes by podcast, then MediaPlayer runs the filter")
        func podcastFilter() {
            #expect(LibraryQuery<Episode>.episodes.filter(\.podcastTitle == "Radiolab").request.filters == [.init(.podcastTitle("Radiolab"))])
            #expect(LibraryQuery<Episode>.episodes.filter(\.podcastID == 77).request.filters == [.init(.podcastID(77))])
        }

        @Test("When filtering books by author, then MediaPlayer runs an artist filter")
        func authorFilter() {
            #expect(LibraryQuery<Audiobook>.books.filter(\.author == "Frank Herbert").request.filters == [.init(.artist("Frank Herbert"))])
        }

        @Test("When filtering songs by the new properties, then they're pushed down too")
        func songFilters() {
            #expect(LibraryQuery<Song>.songs.filter(\.podcastTitle == "Show").request.filters == [.init(.podcastTitle("Show"))])
            #expect(LibraryQuery<Song>.songs.filter(\.mediaType == .podcast).request.filters == [.init(.mediaType(.podcast))])
        }

        @Test("When episodes are sorted and limited, then the newest come first")
        func newestFirst() async throws {
            let old = StubMediaItem([MPMediaItemPropertyTitle: "Old", MPMediaItemPropertyReleaseDate: Date(timeIntervalSince1970: 100)])
            let new = StubMediaItem([MPMediaItemPropertyTitle: "New", MPMediaItemPropertyReleaseDate: Date(timeIntervalSince1970: 900)])
            let episodes = try await MusicLibrary.preview(songs: [old, new]).fetch(.episodes.sorted(by: \.releaseDate, .reverse).limit(1))
            #expect(episodes.map(\.title) == ["New"])
        }

        @Test("When a podcast lists its episodes, then they can be read as Episodes")
        func podcastEpisodes() {
            let items = [SpokenWordTests.episode("A", id: 1, bookmark: 10), SpokenWordTests.episode("B", id: 2)]
            let podcast = Podcast(MPMediaItemCollection(items: items))
            #expect(podcast.allEpisodes.map(\.title) == ["A", "B"])
            #expect(podcast.allEpisodes.first?.bookmarkTime == 10)
            #expect(podcast.episodes.map(\.title) == ["A", "B"])
        }
    }
}
