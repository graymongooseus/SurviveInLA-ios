import Foundation
import Observation
import StoreKit

enum AdventurePurchaseError: LocalizedError {
    case productUnavailable
    case failedVerification
    case noActiveSession

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            "这个游戏币包暂时无法购买，请稍后再试。"
        case .failedVerification:
            "交易验证失败，没有发放游戏奖励。请稍后重试或联系支持。"
        case .noActiveSession:
            "请先开始一局游戏，再购买游戏币。未完成的 App Store 交易会在下一局开始后自动补发。"
        }
    }
}

@MainActor
@Observable
final class AdventureShopStore {
    @ObservationIgnored
    private var directGrantSequence = UInt64(Date.now.timeIntervalSince1970 * 1_000_000)

    private(set) var products: [String: Product] = [:]
    private(set) var isLoading = false
    private(set) var purchasingProductID: String?
    var notice: UserNotice?

    var usesDirectGrantMode: Bool {
#if DEBUG
        ProcessInfo.processInfo.environment["SURVIVE_IN_LA_USE_STOREKIT"] != "1"
#else
        false
#endif
    }

    func loadProducts() async {
        guard !usesDirectGrantMode else { return }
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

        if usesDirectGrantMode {
            directGrantSequence &+= 1
            if !grant(adventure, directGrantSequence) {
                notice = UserNotice(title: "暂时无法充值", message: AdventurePurchaseError.noActiveSession.localizedDescription)
            }
            return
        }

        do {
            guard let product = products[adventure.rawValue] else {
                throw AdventurePurchaseError.productUnavailable
            }

            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                guard grant(adventure, transaction.id) else {
                    throw AdventurePurchaseError.noActiveSession
                }
                await transaction.finish()
            case .pending:
                notice = UserNotice(
                    title: "等待确认",
                    message: "这笔购买正在等待批准。确认后，游戏现金会自动到账。"
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
        guard !usesDirectGrantMode else { return }

        for await update in Transaction.updates {
            guard !Task.isCancelled else { return }

            do {
                let transaction = try verified(update)
                guard let adventure = AdventureProduct(rawValue: transaction.productID) else {
                    continue
                }
                if grant(adventure, transaction.id) {
                    await transaction.finish()
                } else {
                    notice = UserNotice(
                        title: "游戏币等待发放",
                        message: AdventurePurchaseError.noActiveSession.localizedDescription
                    )
                }
            } catch {
                notice = UserNotice(title: "交易验证失败", message: error.localizedDescription)
            }
        }
    }

    func syncPurchases() async {
        guard !usesDirectGrantMode else {
            notice = UserNotice(title: "正在使用测试模式", message: "点击商品会直接发放固定游戏现金，不会连接 App Store。")
            return
        }

        do {
            try await AppStore.sync()
            notice = UserNotice(
                title: "交易已同步",
                message: "已向 App Store 请求同步。已发放的消耗型游戏币包不会重复恢复。"
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
