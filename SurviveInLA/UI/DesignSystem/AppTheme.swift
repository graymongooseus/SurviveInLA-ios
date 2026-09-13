import SwiftUI

enum AppTheme {
    static let coral = Color(red: 0.96, green: 0.34, blue: 0.27)
    static let coralSoft = Color(red: 1.00, green: 0.48, blue: 0.36)
    static let ink = Color(red: 0.045, green: 0.06, blue: 0.08)
    static let panel = Color(red: 0.07, green: 0.085, blue: 0.105)
    static let positive = Color(red: 0.40, green: 0.82, blue: 0.45)
    static let negative = Color(red: 1.00, green: 0.39, blue: 0.32)
    static let warning = Color(red: 1.00, green: 0.68, blue: 0.22)

    static func effectColor(_ value: Int) -> Color {
        value > 0 ? positive : (value < 0 ? negative : .secondary)
    }
}

/// Colors each effect independently while preserving summary line breaks and separators.
struct EventEffectText: View {
    let summary: String

    init(_ summary: String) {
        self.summary = summary
    }

    var body: some View {
        Text(attributedSummary)
    }

    private var attributedSummary: AttributedString {
        var result = AttributedString()
        for part in summary.components(separatedBy: "\n") {
            if !result.characters.isEmpty { result.append(AttributedString("\n")) }
            for (index, effect) in part.components(separatedBy: " · ").enumerated() {
                if index > 0 { result.append(AttributedString(" · ")) }
                var text = AttributedString(effect)
                if let color = color(for: effect) { text.foregroundColor = color }
                result.append(text)
            }
        }
        return result
    }

    private func color(for effect: String) -> Color? {
        if let range = effect.range(of: #"[+−-]\$?\d[\d,]*(?:\.\d+)?"#, options: .regularExpression) {
            let number = effect[range].replacingOccurrences(of: "−", with: "-")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            guard let value = Double(number), value != 0 else { return nil }
            let isCost = effect.contains("债务利息") || effect.contains("消费品报价")
            return (isCost ? value < 0 : value > 0) ? AppTheme.positive : AppTheme.negative
        }
        if let range = effect.range(of: #"×\d+(?:\.\d+)?"#, options: .regularExpression),
           let value = Double(effect[range].dropFirst()), value != 1 {
            return value > 1 ? AppTheme.positive : AppTheme.negative
        }
        if effect.contains("免费获得") { return AppTheme.positive }
        if effect.contains("跳过") || effect.contains("投资回报上限") { return AppTheme.negative }
        return nil
    }
}
