import Foundation
import Testing

@testable import MediaBridge

@Suite("Flag sorting")
struct FlagSortingTests {
    private struct Item {
        let name: String
        let flag: Bool
    }

    private let items = [
        Item(name: "a", flag: true),
        Item(name: "b", flag: false),
        Item(name: "c", flag: true),
        Item(name: "d", flag: false),
    ]

    @Test func forwardPutsFalseFirst() {
        let sorted = items.sortedByFlagFalseFirst(\Item.flag, order: .forward)

        #expect(sorted.map(\.flag) == [false, false, true, true])
    }

    @Test func reversePutsTrueFirst() {
        let sorted = items.sortedByFlagFalseFirst(\Item.flag, order: .reverse)

        #expect(sorted.map(\.flag) == [true, true, false, false])
    }

    @Test func nilKeyLeavesOrderUntouched() {
        let sorted = items.sortedByFlagFalseFirst(nil, order: .forward)

        #expect(sorted.map(\.name) == ["a", "b", "c", "d"])
    }
}
