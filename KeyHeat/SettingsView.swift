import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmsClear = false

    var body: some View {
        Form {
            Section("统计权限") {
                LabeledContent("输入监控", value: monitorStatusText)
                Text("只读取物理键位并累计次数，不保存字符、顺序、应用名或时间点。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("请求权限") { model.requestInputMonitoring() }
                    Button("重新检测") { model.retryMonitoring() }
                }
            }

            Section("运行") {
                Toggle("在菜单栏显示图标", isOn: $model.showsMenuBarIcon)
                Text("关闭后只隐藏图标，后台统计仍会继续。重新打开 KeyHeat 可恢复图标。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(
                    "登录后自动启动",
                    isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
            }

            Section("本地数据") {
                Button("清空全部统计数据", role: .destructive) {
                    confirmsClear = true
                }
                Text("此操作只清除 KeyHeat 的每日按键计数，不影响系统设置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("退出键盘热力图") { model.quit() }
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 540, height: 480)
        .preferredColorScheme(.light)
        .alert("清空全部统计数据？", isPresented: $confirmsClear) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) { model.clearAllData() }
        } message: {
            Text("所有日、周、月统计都会归零，此操作无法撤销。")
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("知道了") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var monitorStatusText: String {
        switch model.monitorStatus {
        case .running:
            return "正在统计"
        case .permissionRequired:
            return "需要授权"
        case .stopped:
            return "已停止"
        case .failed:
            return "启动失败"
        }
    }
}
