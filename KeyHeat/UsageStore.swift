import Foundation
import SwiftData

enum UsagePeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    var id: Self { self }

    func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        switch self {
        case .day:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return DateInterval(start: start, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)!
        case .month:
            return calendar.dateInterval(of: .month, for: date)!
        }
    }
}

@MainActor
final class UsageStore {
    private let context: ModelContext
    private let calendar: Calendar
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var activeDayKey: String?
    private var activeRecord: DailyKeyUsage?
    private var activeCounts: [KeyID: Int] = [:]
    private var saveTask: Task<Void, Never>?

    private(set) var lastError: Error?

    init(container: ModelContainer, calendar sourceCalendar: Calendar = .autoupdatingCurrent) {
        context = ModelContext(container)

        var normalizedCalendar = Calendar(identifier: .gregorian)
        normalizedCalendar.locale = Locale(identifier: "en_US_POSIX")
        normalizedCalendar.timeZone = sourceCalendar.timeZone
        normalizedCalendar.firstWeekday = sourceCalendar.firstWeekday
        normalizedCalendar.minimumDaysInFirstWeek = sourceCalendar.minimumDaysInFirstWeek
        calendar = normalizedCalendar
    }

    func increment(key: KeyID, at date: Date) throws {
        let keyForDate = dayKey(for: date)
        if activeDayKey != keyForDate {
            try flush()
            try loadActiveDay(keyForDate)
        }

        activeCounts[key, default: 0] += 1
        scheduleSave()
    }

    func snapshot(period: UsagePeriod, anchor: Date) throws -> UsageSnapshot {
        let interval = period.interval(containing: anchor, calendar: calendar)
        let days = days(in: interval)
        let relevantKeys = Set(days.map(\.key))
        let records = try context.fetch(FetchDescriptor<DailyKeyUsage>())
        let recordsByDay = Dictionary(
            uniqueKeysWithValues: records
                .filter { relevantKeys.contains($0.dayKey) }
                .map { ($0.dayKey, $0) }
        )

        var aggregate: [KeyID: Int] = [:]
        var dailyTotals: [DailyTotal] = []

        for day in days {
            let counts: [KeyID: Int]
            if day.key == activeDayKey {
                counts = activeCounts
            } else if let record = recordsByDay[day.key] {
                counts = try decodeCounts(record.countsData)
            } else {
                counts = [:]
            }

            let total = counts.values.reduce(0, +)
            dailyTotals.append(DailyTotal(date: day.date, count: total))
            for (key, count) in counts {
                aggregate[key, default: 0] += count
            }
        }

        let topKeys = aggregate
            .map { KeyCount(key: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.key.rawValue < $1.key.rawValue }
                return $0.count > $1.count
            }
            .prefix(5)

        return UsageSnapshot(
            counts: aggregate,
            dailyTotals: dailyTotals,
            totalCount: dailyTotals.reduce(0) { $0 + $1.count },
            activeKeyCount: aggregate.values.filter { $0 > 0 }.count,
            topKeys: Array(topKeys)
        )
    }

    func flush() throws {
        saveTask?.cancel()
        saveTask = nil
        try persistActiveDay()
    }

    func clearAll() throws {
        saveTask?.cancel()
        saveTask = nil

        let records = try context.fetch(FetchDescriptor<DailyKeyUsage>())
        records.forEach(context.delete)
        try context.save()

        activeDayKey = nil
        activeRecord = nil
        activeCounts = [:]
        lastError = nil
    }

    private func loadActiveDay(_ key: String) throws {
        let descriptor = FetchDescriptor<DailyKeyUsage>(
            predicate: #Predicate { $0.dayKey == key }
        )

        if let record = try context.fetch(descriptor).first {
            activeRecord = record
            activeCounts = try decodeCounts(record.countsData)
        } else {
            let record = DailyKeyUsage(
                dayKey: key,
                countsData: try encodeCounts([:]),
                totalCount: 0
            )
            context.insert(record)
            activeRecord = record
            activeCounts = [:]
        }
        activeDayKey = key
    }

    private func persistActiveDay() throws {
        guard let record = activeRecord else { return }
        record.countsData = try encodeCounts(activeCounts)
        record.totalCount = activeCounts.values.reduce(0, +)
        try context.save()
        lastError = nil
    }

    private func scheduleSave() {
        guard saveTask == nil else { return }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            do {
                try self.persistActiveDay()
                self.saveTask = nil
            } catch {
                self.lastError = error
                self.saveTask = nil
            }
        }
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    private func days(in interval: DateInterval) -> [(date: Date, key: String)] {
        var result: [(date: Date, key: String)] = []
        var date = calendar.startOfDay(for: interval.start)

        while date < interval.end {
            result.append((date, dayKey(for: date)))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return result
    }

    private func encodeCounts(_ counts: [KeyID: Int]) throws -> Data {
        let rawCounts = Dictionary(uniqueKeysWithValues: counts.map { ($0.key.rawValue, $0.value) })
        return try encoder.encode(rawCounts)
    }

    private func decodeCounts(_ data: Data) throws -> [KeyID: Int] {
        let rawCounts = try decoder.decode([String: Int].self, from: data)
        return Dictionary(
            uniqueKeysWithValues: rawCounts.compactMap { rawKey, count in
                guard let key = KeyID(rawValue: rawKey) else { return nil }
                return (key, count)
            }
        )
    }
}
