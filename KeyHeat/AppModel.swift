import AppKit
import Foundation
import ServiceManagement
import SwiftData

@MainActor
final class AppModel: ObservableObject {
    @Published var period: UsagePeriod = .day {
        didSet { reloadSnapshot() }
    }
    @Published private(set) var anchorDate: Date
    @Published private(set) var snapshot: UsageSnapshot = .empty
    @Published private(set) var monitorStatus: KeyboardMonitor.Status = .stopped
    @Published private(set) var launchAtLoginEnabled = false
    @Published var showsMenuBarIcon: Bool {
        didSet {
            defaults.set(showsMenuBarIcon, forKey: Self.showsMenuBarIconKey)
        }
    }
    @Published var errorMessage: String?

    let monitor: KeyboardMonitor
    private let store: UsageStore
    private let calendar: Calendar
    private let now: () -> Date
    private let defaults: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private var permissionPollingTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private var hasStarted = false

    private static let inputMonitoringSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    )!
    private static let showsMenuBarIconKey = "showsMenuBarIcon"

    init(
        container: ModelContainer,
        calendar sourceCalendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard
    ) {
        var normalizedCalendar = Calendar(identifier: .gregorian)
        normalizedCalendar.locale = Locale.autoupdatingCurrent
        normalizedCalendar.timeZone = sourceCalendar.timeZone
        normalizedCalendar.firstWeekday = sourceCalendar.firstWeekday
        normalizedCalendar.minimumDaysInFirstWeek = sourceCalendar.minimumDaysInFirstWeek

        calendar = normalizedCalendar
        self.now = now
        self.defaults = defaults
        showsMenuBarIcon = defaults.object(forKey: Self.showsMenuBarIconKey) == nil
            ? true
            : defaults.bool(forKey: Self.showsMenuBarIconKey)
        anchorDate = now()
        store = UsageStore(container: container, calendar: normalizedCalendar)
        monitor = KeyboardMonitor()

        monitor.onPhysicalKeyDown = { [weak self] code in
            self?.record(keyCode: code)
        }
        monitor.onStatusChange = { [weak self] status in
            self?.monitorStatus = status
        }

        refreshLaunchAtLoginStatus()
        installLifecycleObservers()
        reloadSnapshot()
    }

    var canMoveForward: Bool {
        guard let next = movedDate(by: 1) else { return false }
        let nextStart = period.interval(containing: next, calendar: calendar).start
        return nextStart <= calendar.startOfDay(for: now())
    }

    var periodTitle: String {
        let interval = period.interval(containing: anchorDate, calendar: calendar)
        switch period {
        case .day:
            return interval.start.formatted(.dateTime.month(.wide).day())
        case .week:
            let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end)!
            return "\(interval.start.formatted(.dateTime.month().day())) – \(lastDay.formatted(.dateTime.month().day()))"
        case .month:
            return interval.start.formatted(.dateTime.year().month(.wide))
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        monitor.start()
        if monitorStatus == .permissionRequired {
            startPermissionPolling()
        }
        reloadSnapshot()
    }

    func moveBackward() {
        guard let previous = movedDate(by: -1) else { return }
        anchorDate = previous
        reloadSnapshot()
    }

    func moveForward() {
        guard canMoveForward, let next = movedDate(by: 1) else { return }
        anchorDate = next
        reloadSnapshot()
    }

    func moveToToday() {
        period = .day
        anchorDate = now()
        reloadSnapshot()
    }

    func retryMonitoring() {
        monitor.start()
    }

    func requestInputMonitoring() {
        if monitor.requestPermission() {
            permissionPollingTask?.cancel()
            permissionPollingTask = nil
            monitor.start()
            return
        }

        startPermissionPolling()
        if !NSWorkspace.shared.open(Self.inputMonitoringSettingsURL) {
            errorMessage = "无法打开输入监控设置，请手动前往“系统设置 → 隐私与安全性 → 输入监控”。"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "无法更新开机启动：\(error.localizedDescription)"
        }
        refreshLaunchAtLoginStatus()
    }

    func clearAllData() {
        do {
            try store.clearAll()
            snapshot = try store.snapshot(period: period, anchor: anchorDate)
            errorMessage = nil
        } catch {
            errorMessage = "无法清空统计数据：\(error.localizedDescription)"
        }
    }

    func flush() {
        do {
            try store.flush()
        } catch {
            errorMessage = "无法保存统计数据：\(error.localizedDescription)"
        }
    }

    func quit() {
        flush()
        NSApplication.shared.terminate(nil)
    }

    func applicationDidBecomeActive() {
        refreshLaunchAtLoginStatus()
        monitor.start()
        if monitorStatus == .permissionRequired {
            startPermissionPolling()
        }
        anchorDate = min(anchorDate, now())
        reloadSnapshot()
    }

    private func record(keyCode: CGKeyCode) {
        guard let key = KeyLayout.keyByCode[keyCode] else { return }
        do {
            try store.increment(key: key, at: now())
            scheduleSnapshotRefresh()
        } catch {
            errorMessage = "无法记录按键统计：\(error.localizedDescription)"
        }
    }

    private func reloadSnapshot() {
        do {
            snapshot = try store.snapshot(period: period, anchor: anchorDate)
            if store.lastError == nil {
                errorMessage = nil
            }
        } catch {
            errorMessage = "无法读取统计数据：\(error.localizedDescription)"
        }
    }

    private func scheduleSnapshotRefresh() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }
            self.reloadSnapshot()
            self.refreshTask = nil
        }
    }

    private func startPermissionPolling() {
        permissionPollingTask?.cancel()
        permissionPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                guard self.monitor.hasPermission else { continue }

                self.monitor.start()
                self.permissionPollingTask = nil
                return
            }
        }
    }

    private func movedDate(by value: Int) -> Date? {
        let component: Calendar.Component
        switch period {
        case .day:
            component = .day
        case .week:
            component = .weekOfYear
        case .month:
            component = .month
        }
        return calendar.date(byAdding: component, value: value, to: anchorDate)
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    private func installLifecycleObservers() {
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.applicationDidBecomeActive()
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.flush()
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name.NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.anchorDate = min(self?.anchorDate ?? Date(), self?.now() ?? Date())
                    self?.reloadSnapshot()
                }
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.flush()
                }
            }
        )
    }
}
