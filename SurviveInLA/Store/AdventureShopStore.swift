import Foundation
import Observation
import StoreKit

enum AdventurePurchaseError: LocalizedError {
    case productUnavailable
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "这个奇遇暂时无法购买，请稍后再试。"
        case .failedVerification:
            "交易验证失败，没有发放游戏奖励。请稍后重试或联系支持。"
        }
    }
}

@MainActor
@Observable
final class AdventureShopStore {
    private(set) var products: [String: Product] = [:]
    private(set) var isLoading = false
    private(set) var purchasingProductID: String?
    var notice: UserNotice?

    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: AdventureProduct.allCases.map(\.rawValue))
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            notice = UserNotice(title: "商店没有连上", message: "无法取得商品信息。请检查网络后再试。")
        }
    }

    func displayPrice(for adventure: AdventureProduct) -> String {
        products[adventure.rawValue]?.displayPrice ?? adventure.fallbackPrice
    }

    func purchase(
        _ adventure: AdventureProduct,
        grant: @escaping @MainActor (AdventureProduct, UInt64) -> Bool
    ) async {
        purchasingProductID = adventure.rawValue
        defer { purchasingProductID = nil }

        do {
            guard let product = products[adventure.rawValue] else {
                throw AdventurePurchaseError.productUnavailable
            }

            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                if grant(adventure, transaction.id) { await transaction.finish() }
            case .pending:
                notice = UserNotice(
                    title: "等待确认",
                    message: "这笔购买正在等待批准。确认后，奇遇会自动出现。"
                )
            case .userCancelled:
                break
            @unknown default:
                notice = UserNotice(title: "购买没有完成", message: "App Store 返回了未知状态，请稍后再试。")
            }
        } catch {
            notice = UserNotice(title: "购买没有完成", message: error.localizedDescription)
        }
    }

    func listenForTransactions(
        grant: @escaping @MainActor (AdventureProduct, UInt64) -> Bool
    ) async {
        // A purchase approved after an ending is delivered to the next active run.
        for await update in Transaction.unfinished {
            guard !Task.isCancelled else { return }
            if let transaction = try? verified(update),
               let adventure = AdventureProduct(rawValue: transaction.productID),
               grant(adventure, transaction.id) {
                await transaction.finish()
            }
        }
        for await update in Transaction.updates {
            guard !Task.isCancelled else { return }

            do {
                let transaction = try verified(update)
                guard let adventure = AdventureProduct(rawValue: transaction.productID) else {
                    continue
                }
                if grant(adventure, transaction.id) { await transaction.finish() }
            } catch {
                notice = UserNotice(title: "交易验证失败", message: error.localizedDescription)
            }
        }
    }

    func syncPurchases() async {
        do {
            try await AppStore.sync()
            notice = UserNotice(
                title: "交易已同步",
                message: "已向 App Store 请求同步。消耗型奇遇在发放后不会重复恢复。"
            )
        } catch {
            notice = UserNotice(title: "同步失败", message: error.localizedDescription)
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw AdventurePurchaseError.failedVerification
        }
    }
}
