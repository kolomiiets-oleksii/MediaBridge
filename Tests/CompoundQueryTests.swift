import MediaPlayer
import Testing

@testable import MediaBridge

@Suite("Compound queries")
struct CompoundQueryTests {
    static func library() -> MusicLibrary {
        .preview(songs: LibraryQueryTests.songs())
    }

    static func titles(_ query: LibraryQuery<Song>) async throws -> [String?] {
        try await library().fetch(query).map(\.title)
    }

    // Help! (Beatles, 7), Hello (Adele, 12), Yesterday (Beatles, 12), Angie (Stones, 1)

    @Suite("Given conditions combined with operators")
    struct Operators {
        @Test("When combined with ||, then either may match")
        func or() async throws {
            let titles = try await CompoundQueryTests.titles(.songs.filter(\.artist == "Adele" || \.playCount == 1))
            #expect(Set(titles) == ["Hello", "Angie"])
        }

        @Test("When combined with &&, then both must match")
        func and() async throws {
            let titles = try await CompoundQueryTests.titles(.songs.filter(\.artist == "The Beatles" && \.playCount > 7))
            #expect(titles == ["Yesterday"])
        }

        @Test("When negated with !, then everything else matches")
        func not() async throws {
            let titles = try await CompoundQueryTests.titles(.songs.filter(!(\.artist == "The Beatles")))
            #expect(Set(titles) == ["Hello", "Angie"])
        }

        @Test("When && and || are mixed, then && binds tighter")
        func precedence() async throws {
            let titles = try await CompoundQueryTests.titles(
                .songs.filter(\.artist == "Adele" || \.artist == "The Beatles" && \.playCount > 10))
            #expect(Set(titles) == ["Hello", "Yesterday"])
        }

        @Test("When || is nested in a negation, then it negates the whole thing")
        func nested() async throws {
            let titles = try await CompoundQueryTests.titles(.songs.filter(!(\.artist == "Adele" || \.playCount < 5)))
            #expect(Set(titles) == ["Help!", "Yesterday"])
        }

        @Test("When filtering with a compound condition and others, then they all apply")
        func withOthers() async throws {
            let titles = try await CompoundQueryTests.titles(
                .songs.filter(\.playCount >= 7).filter(\.artist == "Adele" || \.artist == "The Beatles").sorted(by: \.title))
            #expect(titles == ["Hello", "Help!", "Yesterday"])
        }
    }

    @Suite("Given what MediaPlayer can run")
    struct Pushdown {
        @Test("When combined with &&, then each condition still goes into MediaPlayer's query")
        func andPushesDown() {
            let query = LibraryQuery<Song>.songs.filter(\.artist == "Adele" && \.title == "Hello")
            #expect(query.request.filters.count == 2)
        }

        @Test("When combined with ||, then nothing is pushed down")
        func orStaysLocal() {
            let query = LibraryQuery<Song>.songs.filter(\.artist == "Adele" || \.title == "Hello")
            #expect(query.request.filters.isEmpty)
        }

        @Test("When negated, then nothing is pushed down")
        func notStaysLocal() {
            #expect(LibraryQuery<Song>.songs.filter(!(\.artist == "Adele")).request.filters.isEmpty)
        }

        @Test("When || sits beside a pushed-down filter, then that filter still goes to MediaPlayer")
        func besideOthers() {
            let query = LibraryQuery<Song>.songs.filter(\.artist == "Adele").filter(\.playCount == 1 || \.playCount == 2)
            #expect(query.request.filters == [.init(.artist("Adele"))])
        }
    }

    @Suite("Given two queries")
    struct Equality {
        @Test("When built the same way, then they're equal")
        func same() {
            #expect(
                LibraryQuery<Song>.songs.filter(\.artist == "A" || \.playCount > 1)
                    == .songs.filter(\.artist == "A" || \.playCount > 1))
        }

        @Test("When an operand or an operator differs, then they're not equal")
        func different() {
            let base = LibraryQuery<Song>.songs.filter(\.artist == "A" || \.playCount > 1)
            #expect(base != .songs.filter(\.artist == "B" || \.playCount > 1))
            #expect(base != .songs.filter(\.artist == "A" || \.playCount > 2))
            #expect(base != .songs.filter(\.artist == "A" && \.playCount > 1))
            #expect(base != .songs.filter(!(\.artist == "A" || \.playCount > 1)))
        }

        @Test("When the key paths differ but have the same type, then they're not equal")
        func sameTypedKeyPaths() {
            #expect(
                LibraryQuery<Song>.songs.filter(\.artist == "A" || \.playCount > 1)
                    != .songs.filter(\.title == "A" || \.playCount > 1))
            #expect(
                LibraryQuery<Song>.songs.filter(\.playCount > 1 || \.skipCount > 1)
                    != .songs.filter(\.skipCount > 1 || \.playCount > 1))
            #expect(
                LibraryQuery<Song>.songs.filter(!(\.artist == "A"))
                    != .songs.filter(!(\.title == "A")))
        }
    }

    @Suite("Given the string and set conditions")
    struct Conditions {
        @Test("When filtering by prefix, then case and accents don't matter")
        func hasPrefix() async throws {
            let items = [StubMediaItem.track("Élan", "x"), StubMediaItem.track("elbow", "x"), StubMediaItem.track("Hello", "x")]
            let songs = try await MusicLibrary.preview(songs: items).fetch(.songs.filter(\.title, .hasPrefix("el")))
            #expect(Set(songs.map(\.title)) == ["Élan", "elbow"])
        }

        @Test("When a title is missing, then a prefix never matches")
        func hasPrefixMissing() async throws {
            let items = [StubMediaItem([:]), StubMediaItem.track("Hello", "x")]
            let songs = try await MusicLibrary.preview(songs: items).fetch(.songs.filter(\.title, .hasPrefix("")))
            #expect(songs.map(\.title) == ["Hello"])
        }

        @Test("When filtering by membership, then only listed values match")
        func isIn() async throws {
            let titles = try await CompoundQueryTests.titles(.songs.filter(\.artist, .isIn(["Adele", "The Rolling Stones"])))
            #expect(Set(titles) == ["Hello", "Angie"])
        }

        @Test("When filtering by membership of numbers, then it works for any Hashable value")
        func isInNumbers() async throws {
            let titles = try await CompoundQueryTests.titles(.songs.filter(\.playCount, .isIn([1, 7])))
            #expect(Set(titles) == ["Help!", "Angie"])
        }

        @Test("When the same members are listed in another order, then the queries are equal")
        func isInOrder() {
            let names = (0..<20).map { "Artist \($0)" }
            #expect(
                LibraryQuery<Song>.songs.filter(\.artist, .isIn(names))
                    == .songs.filter(\.artist, .isIn(names.reversed())))
            #expect(LibraryQuery<Song>.songs.filter(\.artist, .isIn(["A"])) != .songs.filter(\.artist, .isIn(["B"])))
        }

        @Test("When filtering by membership, then nothing is pushed down")
        func isInLocal() {
            #expect(LibraryQuery<Song>.songs.filter(\.artist, .isIn(["A", "B"])).request.filters.isEmpty)
        }
    }
}
