import SwiftUI

struct GameHomeView: View {
    @Bindable var store: GameStore
    let profileManager: ProfileManager
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
                GameResultOverlay(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }

            if let worldEventNotice = store.worldEventNotice {
                WorldEventOverlay(store: store, notice: worldEventNotice)
                    .zIndex(11)
            }

            if store.worldEventNotice == nil, let event = store.notice?.healthEvent {
                HealthEventOverlay(event: event) {
                    withAnimation(.snappy) { store.notice = nil }
                }
                .transition(.opacity)
                .zIndex(11)
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
            DiaryView(session: store.session, profileManager: profileManager)
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
        .alert(item: Binding(
            get: { store.notice?.healthEvent == nil ? store.notice : nil },
            set: { if store.notice?.healthEvent == nil { store.notice = $0 } }
        )) { notice in
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
    let openDiary: () -> Void
    let openServices: () -> Void
    let openAdventureShop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sun.horizon.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.coralSoft)

            VStack(alignment: .leading, spacing: 3) {
                Text("Surviving LA")
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
                headerButton(
                    symbol: "storefront.fill",
                    label: "游戏币商店",
                    tint: AppTheme.warning,
                    action: openAdventureShop
                )
                headerButton(symbol: "building.2.fill", label: "城市服务", action: openServices)
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

                storyCard
                    .frame(maxWidth: 560, maxHeight: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
    }

    private var storyCard: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    narrative
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.13))
                .frame(height: 1)

            startingConditions

            Button {
                withAnimation(.snappy) { store.dismissIntroduction() }
            } label: {
                HStack {
                    Text("开始第 1 周")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.title2.weight(.bold))
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .accessibilityHint("关闭序章并进入游戏地图")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 28, y: 18)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("OpeningJourney")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
                .accessibilityLabel("从工厂、博斯普鲁斯海峡和机场一路通往边境的旅程")

            LinearGradient(
                colors: [.clear, AppTheme.ink.opacity(0.4), AppTheme.ink],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("序 章")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.coralSoft)
                        .tracking(2)
                    Rectangle()
                        .fill(AppTheme.coralSoft.opacity(0.7))
                        .frame(width: 30, height: 1)
                }

                Text("没有回头路")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(.white)

                Text("一张机票，一笔债，五十二周求生")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.64))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(height: 220)
    }

    private var narrative: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("四十岁这年，你丢了工作。")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            storyParagraph("留在国内，眼前是送外卖；去广东流水线打螺丝，又像把余生拧进一台看不到尽头的机器。你不甘心，于是刷空信用贷，又向朋友借来 5,000 美元，买下一张没有退路的机票。")

            storyParagraph("飞机掠过博斯普鲁斯海峡，辗转降落在苏克雷元帅国际机场。一路的车票、食宿和“门路费”很快榨干了积蓄。几经波折，你终于翻过边境围栏，却在落地的第一刻被巡逻警察逮捕。")

            storyParagraph("漫长的拘留磨掉了时间，也磨掉了你对美国的幻想。等铁门再次打开，你站在陌生的洛杉矶街头，口袋里只剩 1,000 美元；向朋友借来的 5,000 美元，却仍在按周增加。")

            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.coral)
                    .frame(width: 3)

                Text("没有工作，没有身份，也没有退路。接下来的 52 周，你必须在债务吞掉自己之前活下来——")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func storyParagraph(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white.opacity(0.7))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var startingConditions: some View {
        HStack(spacing: 0) {
            storyStat("身上现金", value: "$1,000", tint: AppTheme.positive)
            statDivider
            storyStat("欠下债务", value: "$5,000", tint: AppTheme.negative)
            statDivider
            storyStat("生存期限", value: "52 周", tint: AppTheme.warning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.13))
            .frame(width: 1, height: 34)
    }

    private func storyStat(_ title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.76)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    GameHomeView(store: GameStore(seed: 42), profileManager: ProfileManager())
}
