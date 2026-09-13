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
                    Label(
                        "当前存款 \(gameStore.session.cash.usdText) · 每次购买触发一次奇遇",
                        systemImage: "sparkles"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)

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
                                    let wasApplied = gameStore.applyPurchasedAdventure(
                                        purchased,
                                        transactionID: transactionID
                                    )
                                    if wasApplied { dismiss() }
                                    return wasApplied
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
                            Task {
                                await shopStore.syncPurchases { adventure, transactionID in
                                    gameStore.applyPurchasedAdventure(
                                        adventure,
                                        transactionID: transactionID
                                    )
                                }
                            }
                        } label: {
                            Label("重新连接 App Store", systemImage: "arrow.clockwise")
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.coralSoft)
                        .padding(.top, 8)
                    }

                    Text(shopStore.usesDirectGrantMode
                         ? "已明确启用直接发放测试模式；点击后不会请求 App Store。"
                         : "每项都是固定结果的一次性剧情：购买成功后立即写入当前存档并改变游戏存款。已发放的剧情不会重复恢复。")
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
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .layoutPriority(1)
                    Spacer(minLength: 2)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("剧情入账")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.38))
                        Text(adventure.resultLabel)
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.positive)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: 68, alignment: .trailing)
                }

                Text(adventure.storeSummary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)

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
            .frame(height: 124)
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
                AppTheme.ink
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        hero(width: proxy.size.width)
                        story
                    }
                    .frame(width: proxy.size.width)
                    .padding(.bottom, 92)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: dismiss) {
                HStack {
                    Text("收下这份运气")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(adventure.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 330)
                .clipped()
                .accessibilityLabel(adventure.accessibilitySummary)

            LinearGradient(
                colors: [.clear, AppTheme.ink.opacity(0.3), AppTheme.ink],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Label("命运已改写", systemImage: "sparkles")
                    .font(.caption.weight(.black))
                    .tracking(1.7)
                    .foregroundStyle(AppTheme.warning)

                Text(adventure.eventTitle)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: width, height: 330)
        .clipped()
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(adventure.narrative)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.76))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("奇遇结算")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.46))
                    Text("已存入当前游戏")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text(adventure.resultLabel)
                    .font(.title2.weight(.black).monospacedDigit())
                    .foregroundStyle(AppTheme.positive)
            }
            .padding(16)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
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
    PurchasedAdventureOverlay(adventure: .anonymousBroker, dismiss: {})
        .preferredColorScheme(.dark)
}
