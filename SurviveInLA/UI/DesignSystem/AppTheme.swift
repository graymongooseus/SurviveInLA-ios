import SwiftUI

enum AppTheme {
    static let coral = Color(red: 0.96, green: 0.34, blue: 0.27)
    static let coralSoft = Color(red: 1.00, green: 0.48, blue: 0.36)
    static let ink = Color(red: 0.045, green: 0.06, blue: 0.08)
    static let panel = Color(red: 0.07, green: 0.085, blue: 0.105)
    static let positive = Color(red: 0.40, green: 0.82, blue: 0.45)
    static let negative = Color(red: 1.00, green: 0.39, blue: 0.32)
    static let warning = Color(red: 1.00, green: 0.68, blue: 0.22)
}

extension Int {
    var usdText: String {
        formatted(
            .currency(code: "USD")
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "en_US"))
        )
    }
}
