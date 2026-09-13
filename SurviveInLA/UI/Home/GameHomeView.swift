import SwiftUI

struct GameHomeView: View {
    @Bindable var store: GameStore
    let profileManager: ProfileManager
    let adventureShopStore: AdventureShopStore
    @State private var isDiaryPresented = false
    @State private var isServicesPresented = false
    @State private var isAdventureShopPresented = false
    @State private var isAmericanDreamPresented = false
    @State private var isActionPanelCollapsed = false

    private var gameContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Group {
                    CityMapView(store: store) {
                        withAnimation(.snappy) {
                            isActionPanelCollapsed = false
                        }
                    }
                        .ignoresSafeArea()

                    VStack {
                        HeaderView(
                            week: min(store.session.day, store.session.totalDays),
                            totalWeeks: store.session.totalDays,
                            dreamProgress: store.session.currentEquipment.completedMilestoneCount,
                            hasHope: store.session.hasHope,
                            openDiary: { isDiaryPresented = true },
                            openServices: { isServicesPresented = true },
                            openAmericanDream: { isAmericanDreamPresented = true },
                            openAdventureShop: { isAdventureShopPresented = true }
                        )
                        Spacer(minLength: 220)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    SurvivalBenefitRail(store: store)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 170)
                        .padding(.trailing, 10)

                    MarketPanelView(
                        store: store,
                        isCollapsed: $isActionPanelCollapsed
                    )
                        .offset(y: geometry.safeAreaInsets.bottom)

                }
                .allowsHitTesting(store.presentation == nil)

                if store.presentation == .introduction {
                    OpeningStoryOverlay(store: store)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(9)
                }

                if store.presentation == .result {
                    GameResultOverlay(store: store, uploads: profileManager.rankingUploads)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(10)
                }

                if store.presentation == .worldEvent, let worldEventNotice = store.worldEventNotice {
                    WorldEventOverlay(store: store, notice: worldEventNotice)
                        .zIndex(11)
                }

                if store.presentation == .healthEvent, let event = store.notice?.healthEvent {
                    HealthEventOverlay(event: event) {
                        withAnimation(.snappy) { store.dismissNotice() }
                    }
                    .transition(.opacity)
                    .zIndex(11)
                }

                if store.presentation == .notice, let event = store.notice?.event {
                    GeneralEventOverlay(event: event) {
                        withAnimation(.snappy) { store.dismissNotice() }
                    }
                    .zIndex(11)
                }

                if store.presentation == .purchasedAdventure, let adventure = store.purchasedAdventure {
                    PurchasedAdventureOverlay(adventure: adventure) {
                        withAnimation(.snappy) { store.dismissPurchasedAdventure() }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(12)
                }

                if store.presentation == .lifeChoice, let choice = store.pendingLifeChoice {
                    LifeChoiceOverlay(store: store, choice: choice)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(13)
                }

                if store.presentation == .lifeChoiceResult, let event = store.lifeChoiceResult {
                    LifeChoiceResultOverlay(event: event) {
                        withAnimation(.snappy) { store.dismissNotice() }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(14)
                }

                if store.presentation == .celebrity,
                   let encounter = store.session.pendingCelebrityEncounter {
                    CelebrityEventOverlay(store: store, encounter: encounter)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(15)
                }

                if store.presentation == .acting {
                    CelebrityActingOverlay(store: store)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(15)
                }

                if store.presentation == .investment {
                    InvestmentEventOverlay(store: store)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        .zIndex(15)
                }
            }
        }
    }

    var body: some View {
        gameContent
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
        .sheet(isPresented: $isAmericanDreamPresented) {
            AmericanDreamView(store: store)
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
        }
        .alert(item: Binding<UserNotice?>(
            get: {
                guard store.presentation == .notice, let notice = store.notice,
                      notice.event == nil else { return nil }
                return notice
            },
            set: { newValue in
                guard store.presentation == .notice else { return }
                if newValue == nil {
                    store.dismissNotice()
                } else {
                    store.notice = newValue
                }
            }
        )) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
}

private enum SurvivalBenefit: String, CaseIterable, Identifiable {
    case housing
    case vehicle
    case license

    var id: Self { self }

    var title: String {
        switch self {
        case .housing: "有住处"
        case .vehicle: "有车开"
        case .license: "有驾照"
        }
    }

    var symbol: String {
        switch self {
        case .housing: "house.fill"
        case .vehicle: "car.fill"
        case .license: "checkmark.seal.fill"
        }
    }
}

private struct SurvivalBenefitRail: View {
    @Bindable var store: GameStore
    @State private var selectedBenefit: SurvivalBenefit?
    @State private var isCelebrityCollectionPresented = false

    var body: some View {
        VStack(spacing: 9) {
            Button {
                isCelebrityCollectionPresented = true
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(store.session.currentPlayerBuffs.isEmpty ? Color.secondary : AppTheme.warning)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.panel.opacity(0.82), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("合照与增益")
            .accessibilityIdentifier("celebrity-collection-open")
            ForEach(SurvivalBenefit.allCases) { benefit in
                Button {
                    selectedBenefit = benefit
                } label: {
                    Image(systemName: benefit.symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isActive(benefit) ? tint(benefit) : Color.secondary)
                        .frame(width: 42, height: 42)
                        .background(.regularMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(isActive(benefit) ? tint(benefit).opacity(0.7) : Color.white.opacity(0.15))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(benefit.title)，\(isActive(benefit) ? "已生效" : "未获得")")
            }
        }
        .sheet(isPresented: $isCelebrityCollectionPresented) {
            CelebrityCollectionView(store: store)
                .presentationDetents([.medium, .large])
        }
        .popover(item: $selectedBenefit, arrowEdge: .trailing) { benefit in
            benefitDetail(benefit)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func benefitDetail(_ benefit: SurvivalBenefit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(benefit.title, systemImage: benefit.symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(isActive(benefit) ? tint(benefit) : .secondary)
            Text(isActive(benefit) ? "增益已生效" : "增益尚未获得")
                .font(.caption.weight(.bold))
                .foregroundStyle(isActive(benefit) ? AppTheme.positive : AppTheme.negative)
            Text(detail(benefit))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 270, alignment: .leading)
    }

    private func isActive(_ benefit: SurvivalBenefit) -> Bool {
        switch benefit {
        case .housing: store.session.currentEquipment.hasHousing
        case .vehicle: store.session.currentEquipment.hasVehicle
        case .license: store.session.hasActiveDriversLicense
        }
    }

    private func tint(_ benefit: SurvivalBenefit) -> Color {
        switch benefit {
        case .housing: AppTheme.positive
        case .vehicle: .cyan
        case .license: .purple
        }
    }

    private func detail(_ benefit: SurvivalBenefit) -> String {
        let equipment = store.session.currentEquipment
        switch benefit {
        case .housing:
            if equipment.hasProperty {
                return "自有物业提供稳定住处。每周收入 \(store.propertyWeeklyIncome.usdText)，并恢复 \(store.propertyHealthRecovery) 点健康；可申请要求稳定住处的工作。"
            }
            if let tier = equipment.activeHousingTier {
                let nextWeek = equipment.housingNextPaymentWeek ?? (store.session.day + 1)
                return "正在居住：\(tier.name)。每周恢复 \(tier.weeklyHealthRecovery) 点健康；下次房租在第 \(nextWeek) 周扣除。可申请要求稳定住处的工作。"
            }
            return "租房或拥有物业后获得。没有住处时，只能选择标注“临时短工 · 无需住处”的工作。"
        case .vehicle:
            if equipment.hasVehicle {
                return "当前有车可开，可申请带车工作；这类工作的健康损耗减少 \(store.vehicleHealthProtection) 点。"
            }
            return "取得驾照后租车或买车可获得。用于解锁带车工作并降低其健康损耗。"
        case .license:
            let equipment = store.session.currentEquipment
            if store.session.hasActiveDriversLicense {
                return "当前持有有效驾照。驾驶工作正常结算，仍有小概率遗失驾照。"
            }
            if let recoveryWeek = equipment.driversLicenseRecoveryUntilWeek {
                return "驾照正在补办中，预计第 \(recoveryWeek) 周恢复。补办期间没有“有驾照”增益，驾驶被警察拦下的概率更高。"
            }
            return "尚未取得驾照。驾驶工作属于无证驾驶，有一定概率被警察抓住并关押 2 个回合（两周）。"
        }
    }
}

private struct LifeChoiceOverlay: View {
    @Bindable var store: GameStore
    let choice: LifeChoiceEvent

    var body: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("人生选择 · 第 \(store.session.day) 周", systemImage: "arrow.triangle.branch")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.coralSoft)
                    Text(choice.title)
                        .font(.largeTitle.weight(.black))
                    Text(choice.story)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.76))
                        .lineSpacing(5)
                    ForEach(choice.options) { option in
                        Button {
                            withAnimation(.snappy) { store.resolveLifeChoice(option.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(option.title).font(.headline).foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("选择会立即生效，人生事件不占用本周赚钱任务。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(22)
            }
            .frame(maxWidth: 520, maxHeight: 650)
            .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 28))
            .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.12)) }
            .padding(14)
        }
        .accessibilityAddTraits(.isModal)
    }

}

private struct LifeChoiceResultOverlay: View {
    let event: GameEvent
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.84).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Label("人生选择 · 结果", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.coralSoft)

                Text(event.title)
                    .font(.title.weight(.black))
                    .foregroundStyle(.white)

                Text(event.message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.76))
                    .lineSpacing(5)

                HStack(spacing: 10) {
                    resultCard(title: "健康", value: event.healthDelta, symbol: "heart.fill")
                    resultCard(title: "运气", value: event.luckDelta ?? 0, symbol: "sparkles")
                    resultCard(title: "现金", value: event.cashDelta, symbol: "dollarsign.circle.fill", isCash: true)
                }

                Button("知道了", action: dismiss)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 16))
                    .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 520)
            .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.14)) }
            .padding(14)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func resultCard(title: String, value: Int, symbol: String, isCash: Bool = false) -> some View {
        let amount = isCash ? abs(value).usdText : String(abs(value))
        let text = value == 0 ? "无变化" : "\(value > 0 ? "+" : "−")\(amount)"
        let color = AppTheme.effectColor(value)

        return VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(color)
            Text(text)
                .font(.system(.headline, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct HeaderView: View {
    let week: Int
    let totalWeeks: Int
    let dreamProgress: Int
    let hasHope: Bool
    let openDiary: () -> Void
    let openServices: () -> Void
    let openAmericanDream: () -> Void
    let openAdventureShop: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sun.horizon.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.coralSoft)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Surviving LA")
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                    Label("第 \(week) / \(totalWeeks) 周", systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                HStack(spacing: 7) {
                    headerButton(
                        symbol: "storefront.fill",
                        label: "奇遇商店",
                        tint: AppTheme.warning,
                        action: openAdventureShop
                    )
                    headerButton(symbol: "building.2.fill", label: "城市服务", action: openServices)
                    headerButton(symbol: "book.pages.fill", label: "生存日记", action: openDiary)
                }
            }

            Button(action: openAmericanDream) {
                HStack(spacing: 9) {
                    Image(systemName: hasHope ? "sun.max.fill" : "sun.max")
                        .foregroundStyle(hasHope ? Color.yellow : Color.purple)
                    Text(hasHope ? "HOPE · 已经生根洛杉矶" : "美国生存路线")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("\(dreamProgress) / 5")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color.purple.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("americanDream.open")
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
    GameHomeView(
        store: GameStore(seed: 42),
        profileManager: ProfileManager(),
        adventureShopStore: AdventureShopStore()
    )
}

private struct GeneralEventOverlay: View {
    let event: GameEvent
    let dismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.84).ignoresSafeArea()
                VStack(spacing: 18) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(event.title)
                                .font(.title2.weight(.bold))
                                .accessibilityAddTraits(.isHeader)
                            Text("基础效果")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            EventEffectText(event.baseEffectSummary)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(event.message)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                    Button("知道了", action: dismiss)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 16))
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("general-event-dismiss")
                }
                .padding(22)
                .frame(maxWidth: 520, maxHeight: min(540, max(100, geometry.size.height - 32)))
                .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 28))
                .overlay { RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.14)) }
                .padding(.horizontal, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityAddTraits(.isModal)
    }
}
