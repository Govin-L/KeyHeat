import AppKit
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.model?.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if Self.model?.showsMenuBarIcon == false {
            Self.model?.showsMenuBarIcon = true
        }
        return true
    }
}

@main
struct KeyHeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @StateObject private var model: AppModel

    init() {
        do {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            let storeDirectory = applicationSupport.appendingPathComponent(
                "KeyHeat",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: storeDirectory,
                withIntermediateDirectories: true
            )
            let configuration = ModelConfiguration(
                "KeyHeat",
                url: storeDirectory.appendingPathComponent("KeyHeat.store"),
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: DailyKeyUsage.self,
                configurations: configuration
            )
            self.container = container
            let model = AppModel(container: container)
            _model = StateObject(wrappedValue: model)
            AppDelegate.model = model
            model.start()
        } catch {
            fatalError("无法创建本地统计数据库：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup("键盘热力图", id: "heatmap") {
            HeatmapWindow()
                .environmentObject(model)
        }
        .modelContainer(container)
        .defaultSize(width: 1320, height: 880)

        MenuBarExtra(isInserted: menuBarIconBinding) {
            MenuBarCommands()
                .environmentObject(model)
        } label: {
            Label("键盘热力图", systemImage: menuBarIcon)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
        .modelContainer(container)
    }

    private var menuBarIcon: String {
        model.monitorStatus == .running ? "keyboard.fill" : "keyboard"
    }

    private var menuBarIconBinding: Binding<Bool> {
        Binding(
            get: { model.showsMenuBarIcon },
            set: { isVisible in
                if model.showsMenuBarIcon != isVisible {
                    model.showsMenuBarIcon = isVisible
                }
            }
        )
    }
}

private struct MenuBarCommands: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.monitorStatus == .running ? "正在统计" : "等待输入监控权限")
        Text("今日已记录 \(model.period == .day ? model.snapshot.totalCount.formatted() : "—") 次")
            .foregroundStyle(.secondary)

        Divider()

        Button("打开键盘热力图") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: "heatmap")
        }
        .keyboardShortcut("o")

        SettingsLink { Text("设置") }

        Divider()

        Button("退出") { model.quit() }
            .keyboardShortcut("q")
    }
}
