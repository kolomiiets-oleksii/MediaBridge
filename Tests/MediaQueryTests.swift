import MediaPlayer
import Testing
import UIKit

@testable import MediaBridge

@Suite("MediaQuery")
struct MediaQueryTests {

    @Suite("Given the entry points")
    struct EntryPoints {
        let service = MockMusicLibraryService()
        var library: MusicLibrary { MusicLibrary(auth: .mock, service: service) }

        @Test("When fetching each entry point, then it asks MediaPlayer for its type and grouping")
        func requests() async throws {
            _ = try await library.fetch(.songs)
            _ = try await library.fetch(.albums)
            _ = try await library.fetch(.artists)
            _ = try await library.fetch(.genres)
            _ = try await library.fetch(.composers)
            _ = try await library.fetch(.playlists)
            _ = try await library.fetch(.podcasts)
            _ = try await library.fetch(.podcastEpisodes)
            _ = try await library.fetch(.audiobooks)
            _ = try await library.fetch(.compilations)

            #expect(
                service.requests == [
                    MediaQueryRequest(mediaType: .music, grouping: .title),
                    MediaQueryRequest(mediaType: .music, grouping: .album),
                    MediaQueryRequest(mediaType: .music, grouping: .artist),
                    MediaQueryRequest(mediaType: .music, grouping: .genre),
                    MediaQueryRequest(mediaType: .music, grouping: .composer),
                    MediaQueryRequest(grouping: .playlist),
                    MediaQueryRequest(mediaType: .podcast, grouping: .podcastTitle),
                    MediaQueryRequest(mediaType: .podcast, grouping: .title),
                    MediaQueryRequest(mediaType: .audioBook, grouping: .title),
                    MediaQueryRequest(mediaType: .music, filter: .init(.isCompilation(true)), grouping: .album),
                ])
        }
    }

    @Suite("Given two queries")
    struct Equality {
        @Test("When they're built the same way, then they're equal")
        func same() {
            #expect(LibraryQuery.songs.filter(\.artist == "Adele").sorted(by: \.title) == .songs.filter(\.artist == "Adele").sorted(by: \.title))
        }

        @Test("When a key path, value, condition, order, limit, or media type differs, then they're not equal")
        func different() {
            let base = LibraryQuery.songs.filter(\.playCount >= 5).sorted(by: \.title).limit(10)
            #expect(base != .songs.filter(\.rating >= 5).sorted(by: \.title).limit(10))
            #expect(base != .songs.filter(\.playCount >= 6).sorted(by: \.title).limit(10))
            #expect(base != .songs.filter(\.playCount > 5).sorted(by: \.title).limit(10))
            #expect(base != .songs.filter(\.playCount >= 5).sorted(by: \.title, .reverse).limit(10))
            #expect(base != .songs.filter(\.playCount >= 5).sorted(by: \.title).limit(20))
            #expect(base != .songs.filter(\.playCount >= 5).sorted(by: \.title).limit(10).mediaType(nil))
        }
    }

    @Suite("Given a loader")
    @MainActor
    struct Loading {
        @Test("When first updated, then it fetches the query")
        func loads() async throws {
            let loader = MediaQueryLoader<Song>()
            let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService(items: [StubMediaItem.song("A")]))

            loader.update(query: .songs, library: library)
            await loader.settle()

            #expect(loader.elements.map(\.title) == ["A"])
            #expect(!loader.isLoading)
        }

        @Test("When updated again with an equal query, then it doesn't fetch again")
        func dedupes() async throws {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock, service: service)
            let loader = MediaQueryLoader<Song>()

            loader.update(query: .songs.sorted(by: \.title), library: library)
            await loader.settle()
            loader.update(query: .songs.sorted(by: \.title), library: library)
            await loader.settle()

            #expect(service.requests.count == 1)
        }

        @Test("When the query changes, then it fetches the new one")
        func refetches() async throws {
            let service = MockMusicLibraryService(items: [StubMediaItem.song("B", plays: 1), StubMediaItem.song("A", plays: 2)])
            let library = MusicLibrary(auth: .mock, service: service)
            let loader = MediaQueryLoader<Song>()

            loader.update(query: .songs.sorted(by: \.title), library: library)
            await loader.settle()
            loader.update(query: .songs.sorted(by: \.title, .reverse), library: library)
            await loader.settle()

            #expect(service.requests.count == 2)
            #expect(loader.elements.map(\.title) == ["B", "A"])
        }

        @Test("When the library changes, then it fetches again")
        func reloadsOnChange() async throws {
            let (stream, continuation) = AsyncStream<Date>.makeStream()
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock, service: service, changes: MockLibraryChanges(stream: stream))
            let loader = MediaQueryLoader<Song>()

            loader.update(query: .songs, library: library)
            await loader.settle()
            continuation.yield(Date())
            while service.requests.count < 2 { await Task.yield() }
            await loader.settle()

            #expect(service.requests.count == 2)
        }

        @Test("When the library changes, then the rows stay and loading doesn't flash")
        func quietRefetch() async throws {
            let changes = CountingChanges()
            let service = MockMusicLibraryService(items: [StubMediaItem.song("A")])
            let library = MusicLibrary(auth: .mock, service: service, changes: changes)
            let loader = MediaQueryLoader<Song>()
            loader.update(query: .songs, library: library)
            await loader.settle()

            changes.fire()
            while service.requests.count < 2 {
                #expect(!loader.isLoading)
                #expect(loader.elements.map(\.title) == ["A"])
                await Task.yield()
            }
            await Task.yield()

            #expect(!loader.isLoading)
            #expect(loader.elements.map(\.title) == ["A"])
        }

        @Test("When access was denied and the app returns with access granted, then it fetches again")
        func recoversOnForeground() async throws {
            let notifications = NotificationCenter()
            let auth = SwitchableAuthorization(.denied)
            let service = MockMusicLibraryService(items: [StubMediaItem.song("A")])
            let library = MusicLibrary(auth: auth, service: service, changes: CountingChanges())
            let loader = MediaQueryLoader<Song>(notifications: notifications)
            loader.update(query: .songs, library: library)
            await loader.settle()
            #expect(loader.error == .unauthorized(.denied))

            auth.set(.authorized)
            notifications.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            while loader.elements.isEmpty { await Task.yield() }

            #expect(loader.elements.map(\.title) == ["A"])
            #expect(loader.error == nil)
        }

        @Test("When the app returns and access is still denied, then it doesn't fetch again")
        func staysDenied() async throws {
            let notifications = NotificationCenter()
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: SwitchableAuthorization(.denied), service: service, changes: CountingChanges())
            let loader = MediaQueryLoader<Song>(notifications: notifications)
            loader.update(query: .songs, library: library)
            await loader.settle()

            notifications.post(name: UIApplication.willEnterForegroundNotification, object: nil)
            for _ in 0..<20 { await Task.yield() }

            #expect(service.requests.isEmpty)
        }

        @Test("When fetching fails, then the error is kept and the previous elements stay")
        func failure() async throws {
            let loader = MediaQueryLoader<Song>()

            loader.update(query: .songs, library: MusicLibrary.accessDenied)
            await loader.settle()

            #expect(loader.error == .unauthorized(.denied))
            #expect(loader.elements.isEmpty)
        }

        @Test("When reloaded after a failure, then the error clears on success")
        func reload() async throws {
            let loader = MediaQueryLoader<Song>()
            loader.update(query: .songs, library: MusicLibrary.accessDenied)
            await loader.settle()

            loader.update(query: .songs, library: MusicLibrary.preview(songs: [StubMediaItem.song("A")]))
            await loader.settle()

            #expect(loader.error == nil)
            #expect(loader.elements.map(\.title) == ["A"])
        }
    }
}
