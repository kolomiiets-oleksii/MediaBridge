import Foundation
import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Catalog")
struct CatalogTests {
    @Suite("Given a search request")
    struct Validation {
        @Test("When only a term is given, then the defaults apply and the term is trimmed")
        func defaults() throws {
            let request = try CatalogSearchRequest(term: "  Adele ")
            #expect(request.term == "Adele")
            #expect(request.kinds == [.song, .album, .artist, .playlist])
            #expect(request.limit == 10)
            #expect(request.offset == 0)
            #expect(request.includesTopResults == false)
        }

        @Test("When the term is empty or blank, then the request is invalid")
        func blankTerm() {
            for term in ["", "   ", "\n\t"] {
                #expect(throws: CatalogError.self) { try CatalogSearchRequest(term: term) }
            }
        }

        @Test("When kinds repeat, then the first occurrence of each stays, in order")
        func dedupesKinds() throws {
            let request = try CatalogSearchRequest(term: "x", kinds: [.station, .song, .station, .song])
            #expect(request.kinds == [.station, .song])
        }

        @Test("When kinds is empty, then the request is invalid")
        func emptyKinds() {
            #expect(throws: CatalogError.self) { try CatalogSearchRequest(term: "x", kinds: []) }
        }

        @Test("When a kind only appears in top results, then it can't be searched for")
        func resultOnlyKinds() throws {
            for kind in [CatalogKind.curator, .radioShow, .recordLabel] {
                #expect(kind.isSearchable == false)
                #expect(throws: CatalogError.self) { try CatalogSearchRequest(term: "x", kinds: [kind]) }
            }
            for kind in [CatalogKind.song, .album, .artist, .playlist, .musicVideo, .station] {
                #expect(kind.isSearchable)
            }
        }

        @Test("When the limit is outside 1...25, then the request is invalid")
        func limitBounds() throws {
            #expect(throws: CatalogError.self) { try CatalogSearchRequest(term: "x", limit: 0) }
            #expect(throws: CatalogError.self) { try CatalogSearchRequest(term: "x", limit: 26) }
            #expect(try CatalogSearchRequest(term: "x", limit: 1).limit == 1)
            #expect(try CatalogSearchRequest(term: "x", limit: 25).limit == 25)
        }

        @Test("When the offset is negative, then the request is invalid")
        func offsetBounds() throws {
            #expect(throws: CatalogError.self) { try CatalogSearchRequest(term: "x", offset: -1) }
            #expect(try CatalogSearchRequest(term: "x", offset: 20).offset == 20)
        }

        @Test("When two requests ask for the same thing, then they are equal")
        func equatable() throws {
            #expect(try CatalogSearchRequest(term: " a ") == CatalogSearchRequest(term: "a"))
            #expect(try CatalogSearchRequest(term: "a") != CatalogSearchRequest(term: "a", offset: 10))
        }
    }

    @Suite("Given a catalog")
    struct Searching {
        struct FakeCatalog: CatalogSearching {
            let items: [CatalogItem]
            func search(_ request: CatalogSearchRequest) async throws(CatalogError) -> [CatalogItem] {
                guard request.term != "boom" else { throw .notAuthorized }
                return Array(items.filter { request.kinds.contains($0.kind) }.dropFirst(request.offset).prefix(request.limit))
            }
        }

        let items = [
            CatalogItem(id: "1", kind: .song, title: "Hello", artistName: "Adele"),
            CatalogItem(id: "2", kind: .album, title: "25", artistName: "Adele"),
            CatalogItem(id: "3", kind: .artist, title: "Adele"),
        ]

        @Test("When searching, then a catalog returns items of the requested kinds")
        func searches() async throws {
            let catalog: any CatalogSearching = FakeCatalog(items: items)
            let found = try await catalog.search(CatalogSearchRequest(term: "adele", kinds: [.song, .artist]))
            #expect(found.map(\.title) == ["Hello", "Adele"])
        }

        @Test("When an item has an ID, then it is its store ID")
        func storeID() {
            #expect(items[0].id == "1")
            #expect(items[0].storeID == "1")
            #expect(items[0].artworkURL == nil)
            #expect(items[0].url == nil)
        }

        @Test("When the catalog fails, then the error is typed")
        func failure() async {
            let catalog = FakeCatalog(items: items)
            do {
                _ = try await catalog.search(CatalogSearchRequest(term: "boom"))
                Issue.record("expected an error")
            } catch {
                #expect(error == .notAuthorized)
            }
        }

        @Test("When describing errors, then they say what to do")
        func descriptions() {
            #expect(CatalogError.notAuthorized.errorDescription?.contains("Apple Music") == true)
            #expect(CatalogError.invalidRequest("Limit").errorDescription?.contains("Limit") == true)
            #expect(CatalogError.underlying(URLError(.notConnectedToInternet)) == .underlying(URLError(.notConnectedToInternet)))
            #expect(CatalogError.notAuthorized != .invalidRequest("x"))
        }
    }

    @Suite("Given a player")
    struct Playing {
        @Test("When setting a queue from store IDs, then the player gets a store queue in that order")
        func storeQueue() {
            let player = MockMusicPlayer()
            player.setQueue(withStoreIDs: ["10", "20"])
            let descriptor = player.queued.last as? MPMusicPlayerStoreQueueDescriptor
            #expect(descriptor?.storeIDs == ["10", "20"])
        }

        @Test("When there are no store IDs, then the player is left alone")
        func emptyStoreIDs() {
            let player = MockMusicPlayer()
            player.setQueue(withStoreIDs: [])
            player.playNext(storeIDs: [])
            player.playLater(storeIDs: [])
            #expect(player.queued.isEmpty && player.prepended.isEmpty && player.appended.isEmpty)
        }

        @Test("When playing next or later by store ID, then the matching queue edit is used")
        func nextAndLater() {
            let player = MockMusicPlayer()
            player.playNext(storeIDs: ["1"])
            player.playLater(storeIDs: ["2"])
            #expect((player.prepended.last as? MPMusicPlayerStoreQueueDescriptor)?.storeIDs == ["1"])
            #expect((player.appended.last as? MPMusicPlayerStoreQueueDescriptor)?.storeIDs == ["2"])
        }

        @Test("When queueing catalog items, then only songs, albums and playlists play")
        func queuesPlayableItems() {
            let player = MockMusicPlayer()
            player.setQueue(with: [
                CatalogItem(id: "1", kind: .song, title: "a"),
                CatalogItem(id: "2", kind: .artist, title: "b"),
                CatalogItem(id: "3", kind: .album, title: "c"),
                CatalogItem(id: "4", kind: .playlist, title: "d"),
                CatalogItem(id: "5", kind: .station, title: "e"),
            ])
            let descriptor = player.queued.last as? MPMusicPlayerStoreQueueDescriptor
            #expect(descriptor?.storeIDs == ["1", "3", "4"])
        }
    }
}
