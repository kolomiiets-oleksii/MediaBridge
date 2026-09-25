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
    private var recorded: [MediaQueryRequest] = []

    init(
        items: [MPMediaItem] = [],
        collections: [MPMediaGrouping: [MPMediaItemCollection]] = [:],
        error: MockError? = nil
    ) {
        self.items = items
        self.collections = collections
        self.error = error
    }

    var requests: [MediaQueryRequest] {
        lock.withLock { recorded }
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
