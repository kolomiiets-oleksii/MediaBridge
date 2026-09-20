import Foundation
import Testing

@testable import MediaBridge

@Suite("Optional+Comparable")
struct OptionalComparableTests {
    @Test func nilSortsBeforeWrappedValue() {
        let date = Date(timeIntervalSince1970: 0)

        #expect(Date?.none < date)
        #expect(!(date < Date?.none))
    }

    @Test func nilIsNotLessThanNil() {
        #expect(!(Date?.none < Date?.none))
    }

    @Test func orderingIsTotal() {
        let early = Date(timeIntervalSince1970: 0)
        let late = Date(timeIntervalSince1970: 1)
        let values: [Date?] = [late, nil, early, nil]

        let sorted = values.sorted(by: <)

        #expect(sorted[0] == nil)
        #expect(sorted[1] == nil)
        #expect(sorted[2] == early)
        #expect(sorted[3] == late)
    }

    @Test func worksForAnyComparableWrapped() {
        let sorted: [String?] = ["b", nil, "a"].sorted(by: <)

        #expect(sorted == [nil, "a", "b"])
    }
}
