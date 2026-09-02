import CoreGraphics
import XCTest
@testable import KeyHeat

final class KeyLayoutTests: XCTestCase {
    func testLayoutContainsExpectedTrackableKeys() {
        let definitions = KeyLayout.rows.flatMap { $0 }
        let tracked = definitions.filter { $0.id != nil && $0.keyCode != nil }
        let untracked = definitions.filter { $0.style == .untracked }

        XCTAssertEqual(KeyID.allCases.count, 77)
        XCTAssertEqual(tracked.count, 77)
        XCTAssertEqual(untracked.count, 1)
        XCTAssertEqual(untracked.first?.label, "Touch ID")
    }

    func testEveryKeyCodeAndKeyIDIsUnique() {
        let definitions = KeyLayout.rows.flatMap { $0 }
        let codes = definitions.compactMap(\.keyCode)
        let ids = definitions.compactMap(\.id)

        XCTAssertEqual(Set(codes).count, codes.count)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(KeyLayout.keyByCode.count, 77)
        XCTAssertEqual(KeyLayout.definitionByID.count, 77)
    }

    func testLeftAndRightModifiersRemainDistinct() {
        XCTAssertEqual(KeyLayout.keyByCode[55], .leftCommand)
        XCTAssertEqual(KeyLayout.keyByCode[54], .rightCommand)
        XCTAssertEqual(KeyLayout.keyByCode[56], .leftShift)
        XCTAssertEqual(KeyLayout.keyByCode[60], .rightShift)
        XCTAssertEqual(KeyLayout.keyByCode[58], .leftOption)
        XCTAssertEqual(KeyLayout.keyByCode[61], .rightOption)
    }
}
