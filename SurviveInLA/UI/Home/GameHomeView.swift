import SwiftUI

struct GameHomeView: View {
    @Bindable var store: GameStore
    var exitToProfiles: (() -> Void)?
    @State private var isDiaryPresented = false
    @State private var isServicesPresented = false
    @State private var isAdventureShopPresented = false
    @State private var adventureShopStore = AdventureShopStore()

    var body: some View {
        ZStack(alignment: .bottom) {
            CityMapView(store: store)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HeaderView(
                    week: min(store.session.day, store.session.totalDays),
                    totalWeeks: store.session.totalDays,
                    exitToProfiles: exitToProfiles,
                    openDiary: { isDiaryPresented = true },
                    openServices: { isServicesPresented = true },
                    openAdventureShop: { isAdventureShopPresented = true }
                )
                StatusStripView(session: store.session)
                Spacer(minLength: 220)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            MarketPanelView(store: store)

            if store.isIntroductionPresented {
                OpeningStoryOverlay(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(9)
            }

            if store.session.isFinished {
                GameResultOverlay(store: store, exitToProfiles: exitToProfiles)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }

            if let adventure = store.purchasedAdventure {
                PurchasedAdventureOverlay(adventure: adventure) {
                    withAnimation(.snappy) { store.dismissPurchasedAdventure() }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(12)
            }
        }
        .background(AppTheme.ink)
        .sheet(item: $store.tradeContext) { context in
            TradeSheetView(store: store, context: context)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isDiaryPresented) {
            DiaryView(session: store.session)
        }
        .sheet(isPresented: $isServicesPresented) {
            ServiceCenterView(store: store)
        }
        .sheet(isPresented: $isAdventureShopPresented) {
            AdventureShopView(shopStore: adventureShopStore, gameStore: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .task(id: store.session.isFinished) {
            guard !store.session.isFinished else { return }
            await adventureShopStore.loadProducts()
            await adventureShopStore.listenForTransactions { adventure, transactionID in
                store.applyPurchasedAdventure(adventure, transactionID: transactionID)
            }
        }
        .alert(item: $store.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
}

private struct HeaderView: View {
    let week: Int
    let totalWeeks: Int
    let exitToProfiles: (() -> Void)?
    let openDiary: () -> Void
    let openServices: () -> Void
    let openAdventureShop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sun.horizon.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.coralSoft)

            VStack(alignment: .leading, spacing: 3) {
                Text("洛杉矶浮生记")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                Label("第 \(week) / \(totalWeeks) 周", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let exitToProfiles {
                    headerButton(symbol: "person.crop.rectangle.stack.fill", label: "游戏槽", action: exitToProfiles)
                }
                headerButton(
                    symbol: "sparkles",
                    label: "奇遇商店",
                    tint: AppTheme.warning,
                    action: openAdventureShop
                )
                headerButton(symbol: "building.columns.fill", label: "城市服务", action: openServices)
                headerButton(symbol: "book.pages.fill", label: "生存日记", action: openDiary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func headerButton(
        symbol: String,
        label: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .background(.thinMaterial, in: Circle())
        .accessibilityLabel(label)
    }
}

private struct OpeningStoryOverlay: View {
    @Bindable var store: GameStore

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.84)
                    .ignoresSafeArea()

                storyCard(in: proxy.size)
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func storyCard(in size: CGSize) -> some View {
        let cardWidth = min(size.width - 24, 520)
        let cardHeight = min(size.height - 20, 820)
        let heroHeight = min(236, max(205, size.height * 0.28))

        return VStack(spacing: 0) {
            hero(height: heroHeight)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("四十岁这年，你丢了工作。")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    storyParagraph(
                        "留在国内，眼前是送外卖；去广东流水线打螺丝，又像把余生拧进一台看不到尽头的机器。你不甘心，于是刷空信用贷，又向朋友借来 5,000 美元，买下一张没有退路的机票。"
                    )

                    storyParagraph(
                        "飞机掠过博斯普鲁斯海峡，辗转降落在苏克雷元帅国际机场。一路的车票、食宿和“门路费”很快榨干了积蓄。几经波折，你终于翻过边境围栏，却在落地的第一刻被巡逻警察逮捕。"
                    )

                    storyParagraph(
                        "漫长的拘留磨掉了时间，也磨掉了你对美国的幻想。等铁门再次打开，你站在陌生的洛杉矶街头，口袋里只剩 \(GameBalance().startingCash.usdText)；向朋友借来的 5,000 美元，却仍在按周增加。"
                    )

                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.coral)
                            .frame(width: 3)

                        Text("没有工作，没有身份，也没有退路。接下来的 52 周，你必须在债务吞掉自己之前活下来——如果运气够好，也许还能翻身。")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineSpacing(3)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }

            Divider()
                .overlay(Color.white.opacity(0.1))

            VStack(spacing: 14) {
                HStack(spacing: 0) {
                    openingMetric("身上现金", value: GameBalance().startingCash.usdText, tint: AppTheme.positive)
                    metricDivider
                    openingMetric("欠下债务", value: "$5,000", tint: AppTheme.negative)
                    metricDivider
                    openingMetric("生存期限", value: "52 周", tint: AppTheme.warning)
                }

                Button {
                    withAnimation(.snappy) { store.dismissIntroduction() }
                } label: {
                    HStack {
                        Text("开始第 1 周")
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .accessibilityHint("关闭序章并进入游戏地图")
            }
            .padding(16)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(AppTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.48), radius: 30, y: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaPadding(.vertical, 10)
    }

    private func hero(height: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image("OpeningJourney")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
                .accessibilityLabel("从广东工厂出发，辗转跨越海峡与机场，最终走向边境的旅程")

            LinearGradient(
                colors: [.clear, AppTheme.ink.opacity(0.18), AppTheme.ink.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    Text("序章")
                        .font(.caption2.weight(.black))
                        .tracking(2.2)
                        .foregroundStyle(AppTheme.coralSoft)

                    Rectangle()
                        .fill(AppTheme.coralSoft.opacity(0.7))
                        .frame(width: 30, height: 1)
                }

                Text("没有回头路")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(-0.7)

                Text("一张机票，一笔债，五十二周求生")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 17)
        }
        .frame(height: height)
    }

    private func storyParagraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15.5))
            .foregroundStyle(.white.opacity(0.7))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func openingMetric(_ title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.48))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.11))
            .frame(width: 1, height: 34)
    }
}

#Preview {
    GameHomeView(store: GameStore(seed: 42))
}
