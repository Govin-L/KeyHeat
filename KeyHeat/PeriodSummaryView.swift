import Charts
import SwiftUI

struct PeriodSummaryView: View {
    let period: UsagePeriod
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                CardTitle(title: "每日节奏", subtitle: period == .week ? "过去一周的按键量" : "本月每天的按键量")

                Chart(snapshot.dailyTotals) { item in
                    BarMark(
                        x: .value("日期", item.date),
                        y: .value("按键次数", item.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppPalette.heatLight, AppPalette.heatDeep],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: period == .week ? 7 : 6)) { value in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisTick().foregroundStyle(AppPalette.muted.opacity(0.5))
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppPalette.muted.opacity(0.12))
                        AxisValueLabel()
                    }
                }
                .frame(height: 210)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 18) {
                CardTitle(title: "高频按键", subtitle: "按累计次数排序")

                if snapshot.topKeys.isEmpty {
                    ContentUnavailableView(
                        "还没有统计",
                        systemImage: "keyboard",
                        description: Text("开始输入后，这里会显示最常用的按键。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 170)
                } else {
                    VStack(spacing: 14) {
                        ForEach(Array(snapshot.topKeys.enumerated()), id: \.element.id) { index, item in
                            TopKeyRow(
                                rank: index + 1,
                                item: item,
                                maximum: snapshot.topKeys.first?.count ?? 1
                            )
                        }
                    }
                }
            }
            .padding(22)
            .frame(width: 340, alignment: .leading)
            .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 22))
        }
    }
}

private struct CardTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppPalette.muted)
        }
    }
}

private struct TopKeyRow: View {
    let rank: Int
    let item: KeyCount
    let maximum: Int

    private var label: String {
        let raw = KeyLayout.definitionByID[item.key]?.label ?? item.key.rawValue
        let parts = raw.components(separatedBy: "\n")
        return parts.last?.isEmpty == false ? parts.last! : item.key.rawValue
    }

    var body: some View {
        HStack(spacing: 11) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(AppPalette.muted)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(width: 48, alignment: .leading)

            GeometryReader { geometry in
                Capsule()
                    .fill(AppPalette.heatDeep.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppPalette.heatDeep)
                            .frame(width: geometry.size.width * CGFloat(item.count) / CGFloat(max(maximum, 1)))
                    }
            }
            .frame(height: 8)

            Text(item.count.formatted())
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(AppPalette.ink)
                .frame(minWidth: 45, alignment: .trailing)
        }
    }
}
