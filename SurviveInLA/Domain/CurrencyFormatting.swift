import Foundation

extension Int {
    var usdText: String {
        formatted(
            .currency(code: "USD")
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "en_US"))
        )
    }
}
