import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Apple Music product IDs")
struct ProductIDTests {

    @Suite("Given the live service")
    struct LiveService {
        @Test("When adding a product to the library, then MediaPlayer receives the ID and its entities come back")
        func addsToLibrary() async throws {
            let item = StubMediaItem.song("Hello")
            let mediaLibrary = StubWritableLibrary(added: .success([item]))
            let service = MusicLibraryService<MPMediaQuery>(mediaLibrary: mediaLibrary)

            let entities = try await service.addItem(productID: "1440839718")

            #expect(mediaLibrary.productIDs == ["1440839718"])
            #expect(entities.map(ObjectIdentifier.init) == [ObjectIdentifier(item)])
        }

        @Test("When MediaPlayer fails to add a product, then its error is rethrown")
        func libraryFailure() async {
            let service = MusicLibraryService<MPMediaQuery>(mediaLibrary: StubWritableLibrary(added: .failure(StubError.failed)))

            await #expect(throws: StubError.failed) { _ = try await service.addItem(productID: "1") }
        }

        @Test("When adding a product to a playlist, then the playlist receives the ID")
        func addsToPlaylist() async throws {
            let playlist = StubPlaylist(name: "Most Skipped", attributes: [])

            try await MusicLibraryService<MPMediaQuery>().add(productID: "1440839718", to: playlist)

            #expect(playlist.productIDs == ["1440839718"])
        }
    }

    @Suite("Given access is authorized")
    struct Library {
        @Test("When adding a song by product ID, then the added song comes back")
        func song() async throws {
            let service = MockMusicLibraryService(catalog: ["1": [StubMediaItem.song("Hello")]])

            let songs = try await MusicLibrary(auth: .mock, service: service).add(productID: "1")

            #expect(songs.map(\.title) == ["Hello"])
            #expect(service.productIDAdditions == [.init(productID: "1", playlist: nil)])
        }

        @Test("When adding an album by product ID, then its songs come back in album order")
        func album() async throws {
            let album = MPMediaItemCollection(items: [StubMediaItem.song("One"), StubMediaItem.song("Two")])
            let service = MockMusicLibraryService(catalog: ["2": [album]])

            let songs = try await MusicLibrary(auth: .mock, service: service).add(productID: "2")

            #expect(songs.map(\.title) == ["One", "Two"])
        }

        @Test("When adding a product ID to a playlist, then the service adds it to that playlist")
        func toPlaylist() async throws {
            let service = MockMusicLibraryService()
            let target = StubPlaylist(name: "Most Skipped", attributes: [])

            try await MusicLibrary(auth: .mock, service: service).add(productID: "1", to: Playlist(target))

            #expect(service.productIDAdditions == [.init(productID: "1", playlist: ObjectIdentifier(target))])
        }
    }

    @Suite("Given access is denied")
    struct Unauthorized {
        @Test("When adding by product ID, then it throws and the service is never called")
        func guarded() async {
            let service = MockMusicLibraryService()
            let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: service)

            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) { _ = try await library.add(productID: "1") }
            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) {
                try await library.add(productID: "1", to: Playlist(StubPlaylist(name: "X", attributes: [])))
            }
            #expect(service.productIDAdditions.isEmpty)
        }
    }

    @Suite("Given a service written before 0.15")
    struct ReadOnlyService {
        @Test("When adding by product ID, then it throws writesUnsupported")
        func unsupported() async {
            let library = MusicLibrary(auth: .mock, service: ProductIDFixtureService())

            await #expect(throws: MusicLibraryError.writesUnsupported) { _ = try await library.add(productID: "1") }
            await #expect(throws: MusicLibraryError.writesUnsupported) {
                try await library.add(productID: "1", to: Playlist(StubPlaylist(name: "X", attributes: [])))
            }
        }
    }

    @Suite("Given a preview library")
    struct Preview {
        @Test("When adding a product ID one of its songs has, then that song is added to the playlist")
        func resolvesStoreID() async throws {
            let hello = StubMediaItem([MPMediaItemPropertyTitle: "Hello", MPMediaItemPropertyPlaybackStoreID: "1440839718"])
            let library = MusicLibrary.preview(songs: [StubMediaItem.song("Other"), hello])
            let playlist = try await library.playlist(id: UUID(), orCreate: PlaylistMetadata(name: "Picks"))

            let added = try await library.add(productID: "1440839718")
            try await library.add(productID: "1440839718", to: playlist)

            #expect(added.map(\.title) == ["Hello"])
            #expect(playlist.songs.map(\.title) == ["Hello"])
        }

        @Test("When adding an unknown product ID, then nothing is added")
        func unknown() async throws {
            #expect(try await MusicLibrary.preview(songs: [StubMediaItem.song("A")]).add(productID: "404").isEmpty)
        }
    }

    @Suite("Given a library song")
    struct StoreID {
        @Test("When it came from Apple Music, then playbackStoreID is its catalog ID")
        func storeID() {
            #expect(Song(StubMediaItem([MPMediaItemPropertyPlaybackStoreID: "1440839718"])).playbackStoreID == "1440839718")
            #expect(Song(StubMediaItem([:])).playbackStoreID == nil)
        }
    }
}

private struct ProductIDFixtureService: MusicLibraryServiceProtocol {
    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] { [] }
    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] { [] }
}
