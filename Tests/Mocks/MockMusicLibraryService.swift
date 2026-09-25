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
    private var recordedProductIDs: [ProductIDAddition] = []
    private let catalog: [String: [MPMediaEntity]]

    struct ProductIDAddition: Equatable {
        let productID: String
        let playlist: ObjectIdentifier?
    }

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
        catalog: [String: [MPMediaEntity]] = [:],
        error: MockError? = nil
    ) {
        self.catalog = catalog
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

    var productIDAdditions: [ProductIDAddition] {
        lock.withLock { recordedProductIDs }
    }

    func addItem(productID: String) async throws -> [MPMediaEntity] {
        lock.withLock { recordedProductIDs.append(ProductIDAddition(productID: productID, playlist: nil)) }
        if let error { throw error }
        return catalog[productID] ?? []
    }

    func add(productID: String, to playlist: MPMediaPlaylist) async throws {
        lock.withLock { recordedProductIDs.append(ProductIDAddition(productID: productID, playlist: ObjectIdentifier(playlist))) }
        if let error { throw error }
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
