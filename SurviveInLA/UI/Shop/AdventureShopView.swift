import StoreKit
import SwiftUI

struct AdventureShopView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var shopStore: AdventureShopStore
    @Bindable var gameStore: GameStore
    var loadsProducts = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(AdventureProduct.allCases) { adventure in
                        AdventureProductRow(
                            adventure: adventure,
                            price: shopStore.displayPrice(for: adventure),
                            isLoading: shopStore.isLoading,
                            isPurchasing: shopStore.purchasingProductID == adventure.rawValue,
                            isAnotherPurchaseActive: shopStore.purchasingProductID != nil
                        ) {
                            Task {
                                await shopStore.purchase(adventure) { purchased, transactionID in
                                    let delivered = gameStore.applyPurchasedAdventure(purchased, transactionID: transactionID)
                                    dismiss()
                                    return delivered
                                }
                            }
                        }
                    }

                    Button("同步 App Store 交易") {
                        Task { await shopStore.syncPurchases() }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.coralSoft)
                    .padding(.top, 4)

                    Text("奇遇属于消耗型内购。每次购买只触发一次事件；已发放的奇遇不会被重复恢复。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(AppTheme.ink)
            .navigationTitle("奇遇商店")
            .navigationSubtitle("买一张命运门票，触发一次洛城奇遇")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .task {
            if loadsProducts { await shopStore.loadProducts() }
        }
        .alert(item: $shopStore.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
}

private struct AdventureProductRow: View {
    let adventure: AdventureProduct
    let price: String
    let isLoading: Bool
    let isPurchasing: Bool
    let isAnotherPurchaseActive: Bool
    let purchase: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(adventure.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 124, height: 124)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityLabel(adventure.accessibilitySummary)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(adventure.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Text(adventure.resultLabel)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(adventure.cashDelta >= 0 ? AppTheme.positive : AppTheme.negative)
                }

                Text(adventure.storeSummary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: purchase) {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isPurchasing ? "请求中…" : price)
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 39)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .disabled(isLoading || isAnotherPurchaseActive)
                .opacity(isLoading || (isAnotherPurchaseActive && !isPurchasing) ? 0.5 : 1)
                .accessibilityLabel("购买\(adventure.title)，价格\(price)")
            }
        }
        .padding(10)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

struct PurchasedAdventureOverlay: View {
    let adventure: AdventureProduct
    let dismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.86)
                    .ignoresSafeArea()

                storyCard(in: proxy.size)
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func storyCard(in size: CGSize) -> some View {
        let width = min(size.width - 24, 520)
        let height = min(size.height - 24, 720)
        let heroHeight = min(238, max(190, size.height * 0.27))

        return VStack(spacing: 0) {
            Image(adventure.imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: heroHeight)
                .clipped()
                .accessibilityLabel(adventure.accessibilitySummary)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Label("命运已改写", systemImage: "sparkles")
                        .font(.caption.weight(.black))
                        .tracking(1.7)
                        .foregroundStyle(AppTheme.warning)

                    Text(adventure.eventTitle)
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .tracking(-0.45)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(adventure.narrative)
                        .font(.system(size: 15.5))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text("本次奇遇为你带来")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text(adventure.resultLabel)
                            .font(.title2.weight(.black).monospacedDigit())
                            .foregroundStyle(adventure.cashDelta >= 0 ? AppTheme.positive : AppTheme.negative)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
                }
                .padding(20)
            }

            Button(action: dismiss) {
                HStack {
                    Text(adventure.cashDelta >= 0 ? "收下这份运气" : "认下这次教训")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .padding(16)
        }
        .frame(width: width, height: height)
        .background(AppTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.warning.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.55), radius: 30, y: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.vertical, 10)
    }
}

#Preview("奇遇商店") {
    AdventureShopView(
        shopStore: AdventureShopStore(),
        gameStore: GameStore(seed: 42),
        loadsProducts: false
    )
        .preferredColorScheme(.dark)
}

#Preview("奇遇结果") {
    PurchasedAdventureOverlay(adventure: .optionsWindfall, dismiss: {})
        .preferredColorScheme(.dark)
}
