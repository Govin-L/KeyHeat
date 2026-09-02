import SwiftUI

enum AppPalette {
    static let canvasTop = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let canvasBottom = Color(red: 0.88, green: 0.90, blue: 0.93)
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.15)
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let heatLight = Color(red: 0.70, green: 0.85, blue: 0.97)
    static let heatDeep = Color(red: 0.02, green: 0.48, blue: 0.88)
    static let success = Color(red: 0.15, green: 0.62, blue: 0.43)
}

struct HeatmapWindow: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.canvasTop, AppPalette.canvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if model.monitorStatus != .running {
                        permissionBanner
                    }

                    controls

                    KeyboardHeatmapView(counts: model.snapshot.counts)

                    if model.period != .day {
                        PeriodSummaryView(
                            period: model.period,
                            snapshot: model.snapshot
                        )
                    }
                }
                .padding(32)
            }
        }
        .frame(minWidth: 1100, minHeight: 720)
        .preferredColorScheme(.light)
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

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                Text("键盘热力图")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(AppPalette.ink)

                Text("查看你的按键指纹。只统计次数，不记录输入内容。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppPalette.muted)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(model.monitorStatus == .running ? AppPalette.success : Color.orange)
                    .frame(width: 8, height: 8)
                Text(model.monitorStatus == .running ? "正在统计" : "等待授权")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.ink.opacity(0.78))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.62), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 1))
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text(permissionTitle)
                    .font(.system(size: 14, weight: .bold))
                Text(permissionMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.muted)
            }

            Spacer()

            if model.monitorStatus == .permissionRequired {
                Button("授予输入监控权限") {
                    model.requestInputMonitoring()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("重试") { model.retryMonitoring() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.28)))
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Picker("统计周期", selection: $model.period) {
                Text("日").tag(UsagePeriod.day)
                Text("周").tag(UsagePeriod.week)
                Text("月").tag(UsagePeriod.month)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)

            HStack(spacing: 6) {
                Button { model.moveBackward() } label: {
                    Image(systemName: "chevron.left")
                }
                .help("上一个周期")

                Text(model.periodTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 150)

                Button { model.moveForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.canMoveForward)
                .help("下一个周期")
            }
            .buttonStyle(.bordered)

            Button("今天") { model.moveToToday() }
                .buttonStyle(.bordered)

            Spacer()

            MetricLabel(value: model.snapshot.totalCount, title: "次按键")
            Divider().frame(height: 28)
            MetricLabel(value: model.snapshot.activeKeyCount, title: "个活跃键")
        }
        .padding(14)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.85)))
    }

    private var permissionTitle: String {
        if case let .failed(message) = model.monitorStatus {
            return message
        }
        return "需要输入监控权限"
    }

    private var permissionMessage: String {
        switch model.monitorStatus {
        case .permissionRequired:
            return "macOS 会打开隐私设置，授权后将自动开始统计。"
        case .failed:
            return "检查“系统设置 → 隐私与安全性 → 输入监控”，然后重新启动监听。"
        case .stopped:
            return "监听尚未启动。"
        case .running:
            return ""
        }
    }
}

private struct MetricLabel: View {
    let value: Int
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value.formatted())
                .font(.system(size: 20, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppPalette.ink)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.muted)
        }
    }
}
