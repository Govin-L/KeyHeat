import SwiftUI

struct KeyboardHeatmapView: View {
    let counts: [KeyID: Int]

    private var maximum: Int {
        max(counts.values.max() ?? 0, 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(KeyLayout.rows.enumerated()), id: \.offset) { index, row in
                KeyboardRowView(
                    definitions: row,
                    counts: counts,
                    maximum: maximum,
                    height: index == 0 ? 58 : 68,
                    usesArrowCluster: index == KeyLayout.rows.count - 1
                )
            }
        }
        .padding(28)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
    }
}

private struct KeyboardRowView: View {
    let definitions: [KeyDefinition]
    let counts: [KeyID: Int]
    let maximum: Int
    let height: CGFloat
    let usesArrowCluster: Bool

    private let spacing: CGFloat = 9

    var body: some View {
        GeometryReader { geometry in
            let renderedCount = usesArrowCluster ? definitions.count - 1 : definitions.count
            let totalWidth = definitions.reduce(CGFloat.zero) { $0 + $1.width }
            let unit = (geometry.size.width - spacing * CGFloat(renderedCount - 1)) / totalWidth

            if usesArrowCluster {
                bottomRow(unit: unit)
            } else {
                HStack(spacing: spacing) {
                    ForEach(Array(definitions.enumerated()), id: \.offset) { _, definition in
                        key(definition, unit: unit)
                    }
                }
            }
        }
        .frame(height: height)
    }

    private func bottomRow(unit: CGFloat) -> some View {
        let leading = Array(definitions.prefix(7))
        let left = definitions[7]
        let down = definitions[8]
        let up = definitions[9]
        let right = definitions[10]

        return HStack(spacing: spacing) {
            ForEach(Array(leading.enumerated()), id: \.offset) { _, definition in
                key(definition, unit: unit)
            }

            key(left, unit: unit)

            VStack(spacing: 4) {
                KeyCap(definition: up, count: count(for: up), maximum: maximum)
                KeyCap(definition: down, count: count(for: down), maximum: maximum)
            }
            .frame(width: unit * (up.width + down.width), height: height)

            key(right, unit: unit)
        }
    }

    private func key(_ definition: KeyDefinition, unit: CGFloat) -> some View {
        KeyCap(
            definition: definition,
            count: count(for: definition),
            maximum: maximum
        )
        .frame(width: unit * definition.width, height: height)
    }

    private func count(for definition: KeyDefinition) -> Int {
        guard let id = definition.id else { return 0 }
        return counts[id, default: 0]
    }
}

private struct KeyCap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    let definition: KeyDefinition
    let count: Int
    let maximum: Int

    private var intensity: Double {
        guard count > 0, maximum > 0 else { return 0 }
        return pow(Double(count) / Double(maximum), 0.55)
    }

    private var fill: Color {
        guard definition.style != .untracked else {
            return Color(nsColor: .controlBackgroundColor)
        }
        guard count > 0 else {
            return Color(red: 0.91, green: 0.92, blue: 0.94)
        }
        return Color(
            red: 0.70 - 0.68 * intensity,
            green: 0.85 - 0.37 * intensity,
            blue: 0.97 - 0.09 * intensity
        )
    }

    private var labelColor: Color {
        intensity > 0.58 ? .white : AppPalette.ink
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.black.opacity(count == 0 ? 0.08 : 0.04), lineWidth: 1)
                )

            if definition.style == .untracked {
                VStack(spacing: 3) {
                    Image(systemName: "touchid")
                        .font(.system(size: 18, weight: .medium))
                    Text("未统计")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(AppPalette.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(definition.label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if count > 0 {
                Text(count.formatted())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.10, green: 0.20, blue: 0.28))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.88), in: Capsule())
                    .padding(7)
            }
        }
        .scaleEffect(hovered ? 1.018 : 1)
        .shadow(color: .black.opacity(hovered ? 0.14 : 0.04), radius: hovered ? 7 : 2, y: hovered ? 3 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovered)
        .onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard definition.style != .untracked else { return "Touch ID，不统计" }
        return "\(definition.label.replacingOccurrences(of: "\n", with: " "))，\(count) 次"
    }
}
