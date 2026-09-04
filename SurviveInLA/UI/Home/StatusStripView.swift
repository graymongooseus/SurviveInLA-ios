import SwiftUI

struct StatusStripView: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 0) {
            metric(symbol: "banknote.fill", label: "现金", value: session.cash.usdText, tint: AppTheme.positive)
            divider
            metric(symbol: "exclamationmark.triangle.fill", label: "欠款", value: session.debt.usdText, tint: AppTheme.negative)
            divider
            metric(symbol: "heart.fill", label: "健康", value: "\(session.health)", tint: .pink)
            divider
            metric(symbol: "star.fill", label: "声望", value: "\(session.reputation)", tint: .purple)
        }
        .padding(.vertical, 13)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.11))
            .frame(width: 1, height: 40)
    }

    private func metric(symbol: String, label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .labelStyle(CompactLabelStyle(tint: tint))
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
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
