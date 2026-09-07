import SwiftUI

struct StatusStripView: View {
    let session: GameSession
    @State private var selectedMetric: StatusMetric?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatusMetric.allCases) { metric in
                Button {
                    selectedMetric = metric
                } label: {
                    metricCell(metric)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("查看\(metric.title)历史记录")

                if metric != StatusMetric.allCases.last {
                    divider
                }
            }
        }
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .sheet(item: $selectedMetric) { metric in
            StatusHistoryView(session: session, metric: metric)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.11))
            .frame(width: 1, height: 32)
    }

    private func metricCell(_ metric: StatusMetric) -> some View {
        VStack(spacing: 2) {
            Label(metric.title, systemImage: metric.symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .labelStyle(CompactLabelStyle(tint: metric.tint))
            Text(metric.formatted(session.statusValue(for: metric)))
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(metric.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
    }
}

private struct StatusHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let session: GameSession
    let metric: StatusMetric

    private var entries: [StatusHistoryEntry] {
        session.history(for: metric)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    currentValueCard

                    ForEach(entries) { entry in
                        historyRow(entry)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.ink)
            .navigationTitle("\(metric.title)记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var currentValueCard: some View {
        HStack(spacing: 14) {
            Image(systemName: metric.symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(metric.tint)
                .frame(width: 46, height: 46)
                .background(metric.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text("当前\(metric.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(metric.formatted(session.statusValue(for: metric)))
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(metric.tint)
            }
            Spacer()
            Text("\(entries.filter { $0.delta != 0 }.count) 次变动")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    private func historyRow(_ entry: StatusHistoryEntry) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text("第 \(entry.day) 周")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.reason)
                    .font(.subheadline.weight(.semibold))
                Text("变动后 \(metric.formatted(entry.valueAfter))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(metric.formattedDelta(entry.delta))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(metric.deltaTint(entry.delta))
        }
        .padding(14)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
    }
}

private extension StatusMetric {
    var title: String {
        switch self {
        case .cash: "现金"
        case .debt: "欠款"
        case .health: "健康"
        case .luck: "运气"
        }
    }

    var symbol: String {
        switch self {
        case .cash: "banknote.fill"
        case .debt: "exclamationmark.triangle.fill"
        case .health: "heart.fill"
        case .luck: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .cash: AppTheme.positive
        case .debt: AppTheme.negative
        case .health: .pink
        case .luck: .purple
        }
    }

    private var isMoney: Bool {
        self == .cash || self == .debt
    }

    func formatted(_ value: Int) -> String {
        isMoney ? value.usdText : String(value)
    }

    func formattedDelta(_ delta: Int) -> String {
        guard delta != 0 else { return "起点" }
        let value = isMoney ? abs(delta).usdText : String(abs(delta))
        return (delta > 0 ? "+" : "−") + value
    }

    func deltaTint(_ delta: Int) -> Color {
        guard delta != 0 else { return .secondary }
        let isFavorable = self == .debt ? delta < 0 : delta > 0
        return isFavorable ? AppTheme.positive : AppTheme.negative
    }
}

private struct CompactLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}
