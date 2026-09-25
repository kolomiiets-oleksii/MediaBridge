import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Playlist writes")
struct PlaylistWriteTests {

    static let metadata = PlaylistMetadata(name: "Most Skipped", descriptionText: "Songs you skip", authorDisplayName: "Skips")

    @Suite("Given the live service")
    struct LiveService {
        @Test("When creating a playlist, then MediaPlayer receives the UUID and the metadata")
        func creates() async throws {
            let mediaLibrary = StubPlaylistLibrary(result: .success(StubPlaylist(name: "Most Skipped", attributes: [])))
            let service = MusicLibraryService<MPMediaQuery>(playlistLibrary: mediaLibrary)
            let id = UUID()

            let playlist = try await service.playlist(id: id, creating: PlaylistWriteTests.metadata)

            #expect(playlist?.name == "Most Skipped")
            #expect(mediaLibrary.requests.map(\.id) == [id])
            let sent = try #require(mediaLibrary.requests.first?.metadata)
            #expect(sent.name == "Most Skipped")
            #expect(sent.descriptionText == "Songs you skip")
            #expect(sent.authorDisplayName == "Skips")
        }

        @Test("When looking a playlist up, then no metadata is sent and a missing playlist is nil")
        func looksUp() async throws {
            let mediaLibrary = StubPlaylistLibrary(result: .success(nil))
            let service = MusicLibraryService<MPMediaQuery>(playlistLibrary: mediaLibrary)

            let playlist = try await service.playlist(id: UUID(), creating: nil)

            #expect(playlist == nil)
            #expect(mediaLibrary.requests.map(\.metadata) == [nil])
        }

        @Test("When MediaPlayer fails, then its error is rethrown")
        func passesErrorThrough() async {
            let service = MusicLibraryService<MPMediaQuery>(playlistLibrary: StubPlaylistLibrary(result: .failure(StubError.failed)))

            await #expect(throws: StubError.failed) {
                _ = try await service.playlist(id: UUID(), creating: PlaylistWriteTests.metadata)
            }
        }

        @Test("When adding items, then the playlist receives them in order")
        func adds() async throws {
            let playlist = StubPlaylist(name: "Most Skipped", attributes: [])
            let items = [StubMediaItem.song("A"), StubMediaItem.song("B")]

            try await MusicLibraryService<MPMediaQuery>().add(items, to: playlist)

            #expect(playlist.added.map(ObjectIdentifier.init) == items.map(ObjectIdentifier.init))
        }
    }

    @Suite("Given access is authorized")
    struct Library {
        @Test("When getting or creating a playlist, then the service creates it with the metadata")
        func orCreate() async throws {
            let service = MockMusicLibraryService(playlist: StubPlaylist(name: "Most Skipped", attributes: []))
            let id = UUID()

            let playlist = try await MusicLibrary(auth: .mock, service: service)
                .playlist(id: id, orCreate: PlaylistWriteTests.metadata)

            #expect(playlist.name == "Most Skipped")
            #expect(service.playlistLookups == [.init(id: id, metadata: PlaylistWriteTests.metadata)])
        }

        @Test("When MediaPlayer creates nothing, then it throws playlistUnavailable")
        func orCreateUnavailable() async {
            let id = UUID()
            let library = MusicLibrary(auth: .mock, service: MockMusicLibraryService())

            await #expect(throws: MusicLibraryError.playlistUnavailable(id)) {
                _ = try await library.playlist(id: id, orCreate: PlaylistWriteTests.metadata)
            }
        }

        @Test("When looking up a playlist that doesn't exist, then it returns nil without creating one")
        func lookUp() async throws {
            let service = MockMusicLibraryService()
            let id = UUID()

            let playlist = try await MusicLibrary(auth: .mock, service: service).playlist(id: id)

            #expect(playlist == nil)
            #expect(service.playlistLookups == [.init(id: id, metadata: nil)])
        }

        @Test("When adding songs, then the service adds their media items to the playlist")
        func add() async throws {
            let service = MockMusicLibraryService()
            let target = StubPlaylist(name: "Most Skipped", attributes: [])
            let items = [StubMediaItem.song("A"), StubMediaItem.song("B")]

            try await MusicLibrary(auth: .mock, service: service).add(items.map(Song.init), to: Playlist(target))

            #expect(service.additions.count == 1)
            #expect(service.additions.first?.items == items.map(ObjectIdentifier.init))
            #expect(service.additions.first?.playlist == ObjectIdentifier(target))
        }

        @Test("When adding no songs, then the service isn't called")
        func addNothing() async throws {
            let service = MockMusicLibraryService()

            try await MusicLibrary(auth: .mock, service: service).add([], to: Playlist(StubPlaylist(name: "X", attributes: [])))

            #expect(service.additions.isEmpty)
        }
    }

    @Suite("Given access is denied")
    struct Unauthorized {
        @Test("When writing, then it throws and the service is never called")
        func guarded() async {
            let service = MockMusicLibraryService(playlist: StubPlaylist(name: "X", attributes: []))
            let library = MusicLibrary(auth: .mock(isAuthorized: false, authStatus: .denied), service: service)

            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) {
                _ = try await library.playlist(id: UUID(), orCreate: PlaylistWriteTests.metadata)
            }
            await #expect(throws: AuthorizationManagerError.unauthorized(.denied)) {
                try await library.add([Song(StubMediaItem.song("A"))], to: Playlist(StubPlaylist(name: "X", attributes: [])))
            }
            #expect(service.playlistLookups.isEmpty)
            #expect(service.additions.isEmpty)
        }
    }

    @Suite("Given a service written before 0.14")
    struct ReadOnlyService {
        @Test("When writing, then it throws writesUnsupported")
        func unsupported() async {
            let library = MusicLibrary(auth: .mock, service: ReadOnlyFixtureService())

            await #expect(throws: MusicLibraryError.writesUnsupported) {
                _ = try await library.playlist(id: UUID(), orCreate: PlaylistWriteTests.metadata)
            }
            await #expect(throws: MusicLibraryError.writesUnsupported) {
                try await library.add([Song(StubMediaItem.song("A"))], to: Playlist(StubPlaylist(name: "X", attributes: [])))
            }
        }
    }

    @Suite("Given a preview library")
    struct Preview {
        @Test("When a playlist is created and songs added, then queries see it with its songs")
        func inMemory() async throws {
            let songs = [StubMediaItem.song("A"), StubMediaItem.song("B")]
            let library = MusicLibrary.preview(songs: songs)
            let id = UUID()

            let created = try await library.playlist(id: id, orCreate: PlaylistWriteTests.metadata)
            try await library.add(songs.map(Song.init), to: created)
            let again = try await library.playlist(id: id, orCreate: PlaylistMetadata(name: "Ignored"))
            let fetched = try await library.fetch(Playlist.query)

            #expect(again.name == "Most Skipped")
            #expect(again.descriptionText == "Songs you skip")
            #expect(fetched.map(\.name) == ["Most Skipped"])
            #expect(fetched.first?.songs.map(\.title) == ["A", "B"])
        }

        @Test("When looking up an unknown playlist, then it is nil")
        func unknown() async throws {
            #expect(try await MusicLibrary.preview().playlist(id: UUID()) == nil)
        }
    }
}

enum StubError: Error {
    case failed
}

private struct ReadOnlyFixtureService: MusicLibraryServiceProtocol {
    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] { [] }
    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] { [] }
}

final class StubPlaylistLibrary: PlaylistLibrary, @unchecked Sendable {
    struct Request {
        let id: UUID
        let metadata: MPMediaPlaylistCreationMetadata?
    }

    private let result: Result<MPMediaPlaylist?, Error>
    private let lock = NSLock()
    private var recorded: [Request] = []

    init(result: Result<MPMediaPlaylist?, Error>) {
        self.result = result
    }

    var requests: [Request] { lock.withLock { recorded } }

    func getPlaylist(
        with uuid: UUID,
        creationMetadata: MPMediaPlaylistCreationMetadata?,
        completionHandler: @escaping @Sendable (MPMediaPlaylist?, Error?) -> Void
    ) {
        lock.withLock { recorded.append(Request(id: uuid, metadata: creationMetadata)) }
        switch result {
        case .success(let playlist): completionHandler(playlist, nil)
        case .failure(let error): completionHandler(nil, error)
        }
    }
}
