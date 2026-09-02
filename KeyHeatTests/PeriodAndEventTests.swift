import CoreGraphics
import SwiftData
import XCTest
@testable import KeyHeat

final class PeriodAndEventTests: XCTestCase {
    func testKeyDownIgnoresAutoRepeat() {
        var state = ModifierPressState()

        XCTAssertEqual(
            KeyboardEventFilter.physicalKeyCode(
                type: .keyDown,
                keyCode: 0,
                isRepeat: false,
                modifierIsDown: false,
                modifierState: &state
            ),
            0
        )
        XCTAssertNil(
            KeyboardEventFilter.physicalKeyCode(
                type: .keyDown,
                keyCode: 0,
                isRepeat: true,
                modifierIsDown: false,
                modifierState: &state
            )
        )
    }

    func testModifierCountsOnlyPressTransition() {
        var state = ModifierPressState()

        XCTAssertEqual(filterModifier(code: 56, isDown: true, state: &state), 56)
        XCTAssertNil(filterModifier(code: 56, isDown: true, state: &state))
        XCTAssertNil(filterModifier(code: 56, isDown: false, state: &state))
        XCTAssertEqual(filterModifier(code: 56, isDown: true, state: &state), 56)
    }

    func testCapsLockCountsEveryFlagsChange() {
        var state = ModifierPressState()

        XCTAssertEqual(filterModifier(code: 57, isDown: true, state: &state), 57)
        XCTAssertEqual(filterModifier(code: 57, isDown: false, state: &state), 57)
    }

    func testWeekAndMonthIntervalsUseCalendarBoundaries() {
        let calendar = makeCalendar()
        let friday = makeDate(year: 2026, month: 7, day: 17, calendar: calendar)

        let week = UsagePeriod.week.interval(containing: friday, calendar: calendar)
        let month = UsagePeriod.month.interval(containing: friday, calendar: calendar)

        XCTAssertEqual(calendar.component(.weekday, from: week.start), 2)
        XCTAssertEqual(calendar.component(.day, from: week.start), 13)
        XCTAssertEqual(calendar.component(.day, from: month.start), 1)
        XCTAssertEqual(calendar.component(.month, from: month.start), 7)
        XCTAssertEqual(calendar.dateComponents([.day], from: month.start, to: month.end).day, 31)
    }

    @MainActor
    func testFutureNavigationIsBlocked() throws {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 7, day: 17, calendar: calendar)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyKeyUsage.self, configurations: configuration)
        let model = AppModel(container: container, calendar: calendar, now: { now })

        XCTAssertFalse(model.canMoveForward)
        model.moveBackward()
        XCTAssertTrue(model.canMoveForward)
        model.moveForward()
        XCTAssertFalse(model.canMoveForward)
        XCTAssertEqual(calendar.startOfDay(for: model.anchorDate), calendar.startOfDay(for: now))
    }

    @MainActor
    func testMonthNavigationCrossesYearBoundary() throws {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyKeyUsage.self, configurations: configuration)
        let model = AppModel(container: container, calendar: calendar, now: { now })

        model.period = .month
        model.moveBackward()

        XCTAssertEqual(calendar.component(.year, from: model.anchorDate), 2025)
        XCTAssertEqual(calendar.component(.month, from: model.anchorDate), 12)
        XCTAssertTrue(model.canMoveForward)

        model.moveForward()

        XCTAssertEqual(calendar.component(.year, from: model.anchorDate), 2026)
        XCTAssertEqual(calendar.component(.month, from: model.anchorDate), 1)
        XCTAssertFalse(model.canMoveForward)
    }

    @MainActor
    func testMenuBarVisibilityDefaultsToVisibleAndPersists() throws {
        let suiteName = "KeyHeatTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyKeyUsage.self, configurations: configuration)
        let model = AppModel(container: container, defaults: defaults)

        XCTAssertTrue(model.showsMenuBarIcon)

        model.showsMenuBarIcon = false

        let reloadedModel = AppModel(container: container, defaults: defaults)
        XCTAssertFalse(reloadedModel.showsMenuBarIcon)
    }

    private func filterModifier(
        code: CGKeyCode,
        isDown: Bool,
        state: inout ModifierPressState
    ) -> CGKeyCode? {
        KeyboardEventFilter.physicalKeyCode(
            type: .flagsChanged,
            keyCode: code,
            isRepeat: false,
            modifierIsDown: isDown,
            modifierState: &state
        )
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
