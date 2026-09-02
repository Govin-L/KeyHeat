import SwiftData
import XCTest
@testable import KeyHeat

final class UsageStoreTests: XCTestCase {
    @MainActor
    func testDailyAggregationAndPersistence() throws {
        let container = try makeContainer()
        let calendar = makeCalendar()
        let store = UsageStore(container: container, calendar: calendar)
        let date = makeDate(year: 2026, month: 7, day: 17, hour: 10, calendar: calendar)

        try store.increment(key: .a, at: date)
        try store.increment(key: .a, at: date)
        try store.increment(key: .space, at: date)

        let live = try store.snapshot(period: .day, anchor: date)
        XCTAssertEqual(live.counts[.a], 2)
        XCTAssertEqual(live.counts[.space], 1)
        XCTAssertEqual(live.totalCount, 3)
        XCTAssertEqual(live.activeKeyCount, 2)
        XCTAssertEqual(live.topKeys.first, KeyCount(key: .a, count: 2))

        try store.flush()
        let reloadedStore = UsageStore(container: container, calendar: calendar)
        let reloaded = try reloadedStore.snapshot(period: .day, anchor: date)
        XCTAssertEqual(reloaded, live)
    }

    @MainActor
    func testWeekSnapshotIncludesZeroDaysAndCrossDayCounts() throws {
        let container = try makeContainer()
        let calendar = makeCalendar()
        let store = UsageStore(container: container, calendar: calendar)
        let monday = makeDate(year: 2026, month: 7, day: 13, hour: 9, calendar: calendar)
        let friday = makeDate(year: 2026, month: 7, day: 17, hour: 18, calendar: calendar)

        try store.increment(key: .w, at: monday)
        try store.increment(key: .w, at: friday)
        try store.increment(key: .return, at: friday)

        let snapshot = try store.snapshot(period: .week, anchor: friday)
        XCTAssertEqual(snapshot.dailyTotals.count, 7)
        XCTAssertEqual(snapshot.dailyTotals.map(\.count), [1, 0, 0, 0, 2, 0, 0])
        XCTAssertEqual(snapshot.counts[.w], 2)
        XCTAssertEqual(snapshot.counts[.return], 1)
        XCTAssertEqual(snapshot.totalCount, 3)
    }

    @MainActor
    func testClearAllRemovesPersistedAndPendingCounts() throws {
        let container = try makeContainer()
        let calendar = makeCalendar()
        let store = UsageStore(container: container, calendar: calendar)
        let date = makeDate(year: 2026, month: 7, day: 17, hour: 12, calendar: calendar)

        try store.increment(key: .delete, at: date)
        try store.flush()
        try store.increment(key: .space, at: date)
        try store.clearAll()

        let snapshot = try store.snapshot(period: .month, anchor: date)
        XCTAssertEqual(snapshot.totalCount, 0)
        XCTAssertTrue(snapshot.counts.isEmpty)
        XCTAssertTrue(snapshot.topKeys.isEmpty)
        XCTAssertEqual(snapshot.dailyTotals.count, 31)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: DailyKeyUsage.self, configurations: configuration)
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
