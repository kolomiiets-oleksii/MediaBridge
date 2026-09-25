import Foundation
import MediaBridge
import MediaPlayer

final class MockMusicLibraryService: MusicLibraryServiceProtocol, @unchecked Sendable {
    enum MockError: Error {
        case failed
    }

    private let lock = NSLock()
    private let items: [MPMediaItem]
    private let collections: [MPMediaGrouping: [MPMediaItemCollection]]
    private let error: MockError?
    private let playlist: MPMediaPlaylist?
    private var recorded: [MediaQueryRequest] = []
    private var recordedLookups: [PlaylistLookup] = []
    private var recordedAdditions: [Addition] = []

    struct PlaylistLookup: Equatable {
        let id: UUID
        let metadata: PlaylistMetadata?
    }

    struct Addition: Equatable {
        let items: [ObjectIdentifier]
        let playlist: ObjectIdentifier
    }

    init(
        items: [MPMediaItem] = [],
        collections: [MPMediaGrouping: [MPMediaItemCollection]] = [:],
        playlist: MPMediaPlaylist? = nil,
        error: MockError? = nil
    ) {
        self.items = items
        self.collections = collections
        self.playlist = playlist
        self.error = error
    }

    var requests: [MediaQueryRequest] {
        lock.withLock { recorded }
    }

    var playlistLookups: [PlaylistLookup] {
        lock.withLock { recordedLookups }
    }

    var additions: [Addition] {
        lock.withLock { recordedAdditions }
    }

    func playlist(id: UUID, creating metadata: PlaylistMetadata?) async throws -> MPMediaPlaylist? {
        lock.withLock { recordedLookups.append(PlaylistLookup(id: id, metadata: metadata)) }
        if let error { throw error }
        return playlist
    }

    func add(_ items: [MPMediaItem], to playlist: MPMediaPlaylist) async throws {
        lock.withLock {
            recordedAdditions.append(Addition(items: items.map(ObjectIdentifier.init), playlist: ObjectIdentifier(playlist)))
        }
        if let error { throw error }
    }

    func items(_ request: MediaQueryRequest) async throws -> [MPMediaItem] {
        try record(request)
        return items
    }

    func collections(_ request: MediaQueryRequest) async throws -> [MPMediaItemCollection] {
        try record(request)
        return collections[request.grouping] ?? []
    }

    private func record(_ request: MediaQueryRequest) throws {
        lock.withLock { recorded.append(request) }
        if let error { throw error }
    }
}

extension MusicLibraryServiceProtocol where Self == MockMusicLibraryService {
    static var mock: MockMusicLibraryService { MockMusicLibraryService() }
}

extension MPMediaItem: @unchecked @retroactive Sendable {}
extension MPMediaItem {
    static var mock: MPMediaItem { MPMediaItem() }
}

extension MPMediaItemCollection: @unchecked @retroactive Sendable {}
extension MPMediaItemCollection {
    static var mock: MPMediaItemCollection { MPMediaItemCollection(items: []) }
}
