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
                                    gameStore.applyPurchasedAdventure(purchased, transactionID: transactionID)
                                    dismiss()
                                }
                            }
                        }
                    }

                    if shopStore.usesDirectGrantMode {
                        Label("测试模式：点击后直接存入游戏账户", systemImage: "hammer.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.warning)
                            .padding(.top, 8)
                    } else {
                        Button {
                            Task { await shopStore.syncPurchases() }
                        } label: {
                            Label("重新连接 App Store", systemImage: "arrow.clockwise")
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.coralSoft)
                        .padding(.top, 8)
                    }

                    Text(shopStore.usesDirectGrantMode
                         ? "Debug 构建不会请求 App Store；正式版会在完成 App Store 购买后发放剧情和存款。"
                         : "每项都是一次性剧情：购买成功后立即写入当前存档并改变游戏存款。已发放的剧情不会重复恢复。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.42))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background {
                ZStack {
                    AppTheme.ink
                    RadialGradient(
                        colors: [AppTheme.coral.opacity(0.11), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()
            }
            .navigationTitle("奇遇商店")
            .navigationSubtitle("当前存款 \(gameStore.session.cash.usdText) · 每次购买触发一次")
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
            ZStack(alignment: .topLeading) {
                Image(adventure.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 124, height: 124)
                    .clipped()
                    .accessibilityLabel(adventure.accessibilitySummary)

                Text(adventure.sequenceLabel)
                    .font(.caption2.weight(.black).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
                    .padding(8)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(adventure.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .layoutPriority(1)
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("剧情入账")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.38))
                        Text(adventure.resultLabel)
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(adventure.cashDelta >= 0 ? AppTheme.positive : AppTheme.negative)
                    }
                }

                Text(adventure.storeSummary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: purchase) {
                    HStack(spacing: 8) {
                        if isLoading || isPurchasing {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        if isLoading {
                            Text("连接 App Store…")
                        } else if isPurchasing {
                            Text("正在解锁…")
                        } else {
                            Text("解锁奇遇")
                            Spacer()
                            Text(price)
                                .monospacedDigit()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.black))
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 39)
                }
                .buttonStyle(AdventurePurchaseButtonStyle())
                .foregroundStyle(.white)
                .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .disabled(isLoading || isAnotherPurchaseActive)
                .opacity(isLoading || (isAnotherPurchaseActive && !isPurchasing) ? 0.5 : 1)
                .accessibilityLabel("购买\(adventure.title)，价格\(price)")
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [AppTheme.panel.opacity(0.98), AppTheme.panel.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
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
                        Text("游戏存款变化")
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

private struct AdventurePurchaseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.08 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
