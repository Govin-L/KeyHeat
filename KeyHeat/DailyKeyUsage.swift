import Foundation
import SwiftData

@Model
final class DailyKeyUsage {
    @Attribute(.unique) var dayKey: String
    var countsData: Data
    var totalCount: Int

    init(dayKey: String, countsData: Data, totalCount: Int) {
        self.dayKey = dayKey
        self.countsData = countsData
        self.totalCount = totalCount
    }
}

struct KeyCount: Identifiable, Equatable, Sendable {
    var id: KeyID { key }
    let key: KeyID
    let count: Int
}

struct DailyTotal: Identifiable, Equatable, Sendable {
    var id: Date { date }
    let date: Date
    let count: Int
}

struct UsageSnapshot: Equatable, Sendable {
    let counts: [KeyID: Int]
    let dailyTotals: [DailyTotal]
    let totalCount: Int
    let activeKeyCount: Int
    let topKeys: [KeyCount]

    static let empty = UsageSnapshot(
        counts: [:],
        dailyTotals: [],
        totalCount: 0,
        activeKeyCount: 0,
        topKeys: []
    )
}
