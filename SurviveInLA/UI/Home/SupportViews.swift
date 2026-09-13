import SwiftUI

struct DiaryView: View {
    let session: GameSession
    @Bindable var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GameSettingsView(manager: profileManager)
                    } label: {
                        Label("游戏设置", systemImage: "gearshape.fill")
                    }
                }

                Section("本局概览") {
                    LabeledContent("当前位置", value: GameContent.district(session.currentDistrictID).fullName)
                    LabeledContent("净资产", value: session.netWorth.usdText)
                    LabeledContent("库存", value: "\(session.usedCapacity) / \(session.capacity)")
                    LabeledContent("随身证件", value: "外国护照")
                    LabeledContent("运气", value: "\(session.currentLuck) / 100")
                    LabeledContent("生活配置", value: equipmentSummary)
                }

                if !session.inventory.isEmpty {
                    Section("随身货物") {
                        ForEach(session.inventory.values.sorted(by: { $0.commodityID.rawValue < $1.commodityID.rawValue })) { position in
                            let commodity = GameContent.commodity(position.commodityID)
                            LabeledContent {
                                Text("\(position.quantity) 件 · 均价 \(position.averageCost.usdText)")
                            } label: {
                                Label(commodity.name, systemImage: commodity.symbol)
                            }
                        }
                    }
                }

                Section("生存日记") {
                    ForEach(session.log) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(entry.title)
                                    .font(.headline)
                                Spacer()
                                Text("第 \(entry.day) 周")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("调试日志") {
                    LabeledContent("存储位置", value: "Documents/DebugLogs")
                    ShareLink(item: DebugLog.fileURL) {
                        Label("导出 survive-in-la.log", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    NavigationLink {
                        WorldRankingView(uploads: profileManager.rankingUploads)
                    } label: {
                        Label("世界排名", systemImage: "globe.americas.fill")
                    }
                    .accessibilityIdentifier("diary.worldRanking")
                } footer: {
                    Text("查看全球玩家递交的通关存档与 Top 50 成绩。")
                }
            }
            .navigationTitle("生存日记")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var equipmentSummary: String {
        let equipment = session.currentEquipment
        var parts: [String] = []
        if let housing = equipment.activeHousingTier { parts.append(housing.name) }
        if equipment.rentsCar { parts.append("租车") }
        if equipment.ownsCar { parts.append("自有车") }
        if equipment.hasDriversLicense { parts.append("驾照") }
        if equipment.hasTools { parts.append("工具") }
        if equipment.hasProperty { parts.append("物业") }
        if equipment.hasHope { parts.append("HOPE") }
        return parts.isEmpty ? "暂无" : parts.joined(separator: " · ")
    }
}

struct ServiceCenterView: View {
    private enum MoneyAction: String, CaseIterable, Identifiable {
        case deposit = "存款"
        case withdraw = "取款"
        case repay = "还债"

        var id: Self { self }
    }

    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var moneyAction = MoneyAction.deposit
    @State private var amount = 100
    @State private var treatmentPoints = 1

    private var maximumAmount: Int {
        switch moneyAction {
        case .deposit: store.session.cash
        case .withdraw: store.session.bank
        case .repay: min(store.session.cash, store.session.debt)
        }
    }

    private var missingHealth: Int {
        max(0, 100 - store.session.health)
    }

    private var maximumTreatmentPoints: Int {
        min(missingHealth, store.clinicRemainingTreatmentPoints)
    }

    private var treatmentRecovery: Int {
        store.clinicTreatmentRecovery(min(treatmentPoints, maximumTreatmentPoints))
    }

    private var treatmentCost: Int { treatmentRecovery * store.treatmentCostPerPoint }

    private var medicalButtonTitle: String {
        if store.clinicClosureHoliday != nil { return "本周休诊" }
        if missingHealth == 0 { return "目前不需要治疗" }
        if store.clinicRemainingTreatmentPoints == 0 { return "本周治疗额度已用完" }
        if store.session.cash < treatmentCost { return "现金不足" }
        return "接受治疗"
    }

    private var massageButtonTitle: String {
        if store.didVisitMassageThisWeek { return "本周已体验，下周再来" }
        if missingHealth == 0 { return "目前不需要按摩" }
        if store.session.cash < store.massageCost { return "现金不足" }
        return "接受按摩 · \(store.massageCost.usdText)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    financeCard
                    medicalCard
                    massageCard
                    storageCard
                }
                .padding(20)
            }
            .background(AppTheme.ink)
            .navigationTitle("城市服务")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: maximumTreatmentPoints) { _, maximum in
                treatmentPoints = min(treatmentPoints, max(1, maximum))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var financeCard: some View {
        serviceCard(title: "银行与债务", symbol: "building.columns.fill") {
            HStack(spacing: 10) {
                accountMetric("现金", value: store.session.cash.usdText, tint: AppTheme.positive)
                accountMetric("存款", value: store.session.bank.usdText, tint: .cyan)
                accountMetric("欠款", value: store.session.debt.usdText, tint: AppTheme.negative)
            }

            Picker("资金操作", selection: $moneyAction) {
                ForEach(MoneyAction.allCases) { action in
                    Text(action.rawValue).tag(action)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: moneyAction) { _, _ in
                amount = min(100, maximumAmount)
            }

            HStack {
                TextField("金额", value: $amount, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                Button("最大") {
                    amount = maximumAmount
                }
                .buttonStyle(.bordered)
            }

            Button(action: performMoneyAction) {
                Text("确认\(moneyAction.rawValue) \(max(0, amount).usdText)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.coral)
            .disabled(amount <= 0 || amount > maximumAmount)
        }
    }

    private var medicalCard: some View {
        serviceCard(title: "社区诊所", symbol: "cross.case.fill") {
            HStack {
                Text("当前健康")
                Spacer()
                Text("\(store.session.health) / 100")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.pink)
            }

            if let holiday = store.clinicClosureHoliday {
                Label("今天是\(holiday.rawValue)节日关门一周", systemImage: "calendar.badge.exclamationmark")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.coralSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("services.clinic.closure")
            } else {
                Text("本周营业 · 最多治疗 \(store.clinicWeeklyHealthLimit) 点 · 剩余 \(store.clinicRemainingTreatmentPoints) 点")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Stepper(value: $treatmentPoints, in: 1 ... max(1, maximumTreatmentPoints)) {
                    Text("恢复 \(treatmentRecovery) 点 · \(treatmentCost.usdText)")
                }
                .disabled(maximumTreatmentPoints == 0)
                .accessibilityIdentifier("services.clinic.points")
            }

            Button {
                _ = store.heal(min(treatmentPoints, maximumTreatmentPoints))
                treatmentPoints = min(treatmentPoints, max(1, maximumTreatmentPoints))
            } label: {
                Text(medicalButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.clinicClosureHoliday != nil || maximumTreatmentPoints == 0
                      || store.session.cash < treatmentCost || store.session.isFinished)
            .accessibilityIdentifier("services.clinic.heal")
        }
    }

    private var massageCard: some View {
        serviceCard(title: "波霸按摩院", symbol: "hands.sparkles.fill") {
            HStack {
                Text("每次恢复 \(store.massageHealthRecovery) 点健康")
                    .font(.headline)
                Spacer()
                Text(store.massageCost.usdText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.pink)
            }

            Text("每周可去一次 · \(store.massageCostPerPoint.usdText) / 点\n不占用赚钱行动，节假日照常营业。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if missingHealth > 0, missingHealth < store.massageHealthRecovery {
                Text("健康上限 100，本次实际恢复 \(missingHealth) 点，费用仍为 \(store.massageCost.usdText)。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.coralSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                _ = store.visitMassageParlor()
            } label: {
                Text(massageButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.didVisitMassageThisWeek || missingHealth == 0
                      || store.session.cash < store.massageCost || store.session.isFinished)
            .accessibilityIdentifier("services.massage.visit")
        }
    }

    private var storageCard: some View {
        serviceCard(title: "租赁与仓储", symbol: "shippingbox.fill") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("容量 \(store.session.usedCapacity) / \(store.session.capacity)")
                        .font(.headline)
                    Text("每次增加 10 格，最高 \(store.maximumCapacity) 格")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(store.capacityUpgradeCost.usdText)
                    .font(.headline.monospacedDigit())
            }

            Button {
                _ = store.expandCapacity()
            } label: {
                Text(store.session.capacity >= store.maximumCapacity ? "容量已满" : "升级仓储")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.session.capacity >= store.maximumCapacity)
        }
    }

    private func performMoneyAction() {
        let succeeded: Bool
        switch moneyAction {
        case .deposit: succeeded = store.deposit(amount)
        case .withdraw: succeeded = store.withdraw(amount)
        case .repay: succeeded = store.repayDebt(amount)
        }
        if succeeded {
            amount = min(100, maximumAmount)
        }
    }

    private func accountMetric(_ title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func serviceCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label(title, systemImage: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.coralSoft)
            content()
        }
        .padding(18)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

struct AmericanDreamView: View {
    private struct RouteNotice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var routeNotice: RouteNotice?
    @State private var showsLicenseConfirmation = false
    @State private var pendingHousingTier: HousingTier?

    private var equipment: LifeEquipment { store.session.currentEquipment }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    progressCard
                    housingCard
                    licenseCard
                    vehicleCard
                    toolsCard
                    propertyCard
                    hopeCard
                }
                .padding(20)
            }
            .background(AppTheme.ink)
            .navigationTitle("美国生存路线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(item: $routeNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
        .confirmationDialog(
            pendingHousingTier == .basement ? "确认租下半地下室？" : "选择租房付款方式",
            isPresented: Binding(
                get: { pendingHousingTier != nil },
                set: { if !$0 { pendingHousingTier = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingHousingTier
        ) { tier in
            if tier == .basement {
                Button("确认支付 \(store.basementMoveInFee.usdText)") {
                    pendingHousingTier = nil
                    perform { store.startHousingRental(tier, paymentMethod: .weeklyWithSavingsProof) }
                }
            } else {
                Button("提供存款证明 · 本周付 \(tier.weeklyRent.usdText)") {
                    pendingHousingTier = nil
                    perform { store.startHousingRental(tier, paymentMethod: .weeklyWithSavingsProof) }
                }
                Button("无证明 · 预付 \(tier.prepaidWeeks) 周 \((tier.weeklyRent * tier.prepaidWeeks).usdText)") {
                    pendingHousingTier = nil
                    perform { store.startHousingRental(tier, paymentMethod: .prepaidInstallments) }
                }
            }
            Button("取消", role: .cancel) { pendingHousingTier = nil }
        } message: { tier in
            if tier == .basement {
                Text("确认支付 \(store.basementMoveInFee.usdText) 费用给房东，暂且找到一个安顿的地方，但是交不出房租会被随时赶出来。")
            } else {
                Text("存款证明要求银行余额达到 \(tier.savingsProofAmount.usdText)，之后每周扣 \(tier.weeklyRent.usdText)。没有证明则先付 \(tier.prepaidWeeks) 周现金，以后每 \(tier.prepaidWeeks) 周自动扣款。")
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("从落脚到扎根")
                        .font(.title2.weight(.black))
                    Text("进度只由完成投入推动，与周数无关。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(equipment.completedMilestoneCount) / 5")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(equipment.hasHope ? AppTheme.positive : AppTheme.coralSoft)
            }

            HStack(spacing: 5) {
                ForEach(0 ..< 5, id: \.self) { index in
                    Capsule()
                        .fill(index < equipment.completedMilestoneCount ? AppTheme.positive : Color.white.opacity(0.12))
                        .frame(height: 9)
                }
            }

            Text("租房 → 驾照 → 车辆 → 工具 → 物业 → HOPE")
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(.white.opacity(0.62))

            if store.session.didPerformDreamActionThisWeek {
                Label("本周路线操作已完成，下周可继续", systemImage: "clock.badge.checkmark.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warning)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.28), AppTheme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.purple.opacity(0.5), lineWidth: 1)
        }
    }

    private var housingCard: some View {
        routeCard(
            number: 1,
            title: "租房",
            symbol: "house.fill",
            detail: "住房按周计费并恢复健康。公寓与豪斯需要存款证明；没有证明则周期预付。扣款时现金和存款合计不足，会被赶出并失去“有住处”。",
            completed: equipment.hasHousingMilestone,
            unlocked: true
        ) {
            if equipment.hasProperty {
                statusPill("已由自有物业取代", tint: AppTheme.positive)
            } else {
                VStack(spacing: 9) {
                    ForEach(store.housingTiers) { tier in
                        housingChoiceRow(tier)
                    }
                }
                if equipment.rentsHousing {
                    if let tier = equipment.activeHousingTier {
                        Text(housingPaymentSummary(tier))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    routeButton("退租", tint: .secondary) { perform(store.stopHousingRental) }
                }
            }
        }
    }

    private var licenseCard: some View {
        routeCard(
            number: 2,
            title: "驾照",
            symbol: "person.text.rectangle.fill",
            detail: "先用一周学习并参加路考，首次报名费 \(store.driversLicenseCost.usdText)。当前运气 \(store.session.currentLuck)，通过率 \(store.driversLicensePassChancePercent)%。",
            completed: store.session.hasActiveDriversLicense,
            unlocked: equipment.hasHousingMilestone
        ) {
            if store.session.hasActiveDriversLicense {
                statusPill("驾照已取得", tint: AppTheme.positive)
            } else if let recoveryWeek = equipment.driversLicenseRecoveryUntilWeek {
                statusPill("补办中 · 第 \(recoveryWeek) 周恢复", tint: .orange)
            } else {
                routeButton(equipment.licenseAttemptCount == 0 ? "报名并学习一周" : "再次参加路考", tint: AppTheme.coral) {
                    showsLicenseConfirmation = true
                }
                .disabled(!equipment.hasHousingMilestone)
                .alert("报名驾照考试？", isPresented: $showsLicenseConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button(equipment.licenseAttemptCount == 0 ? "支付并开始" : "参加路考") {
                        perform(store.obtainDriversLicense)
                    }
                } message: {
                    Text(equipment.licenseAttemptCount == 0
                        ? "报名费 \(store.driversLicenseCost.usdText)。本周路线操作将用于学习和考试，通过率 \(store.driversLicensePassChancePercent)%。若未通过，只能下一周再路考。"
                        : "本次不再收报名费，通过率 \(store.driversLicensePassChancePercent)%。若仍未通过，需要再等到下一周。")
                }
            }
        }
    }

    private var vehicleCard: some View {
        routeCard(
            number: 3,
            title: "租车 / 买车",
            symbol: "car.fill",
            detail: "有车才能接带车工作，并减少这类工作的健康损耗。租车每周 \(store.weeklyCarRent.usdText)；买车 \(store.carPurchasePrice.usdText)。",
            completed: equipment.hasVehicleMilestone,
            unlocked: store.session.hasActiveDriversLicense
        ) {
            if equipment.rentsCar {
                routeButton("还车", tint: .secondary) { perform(store.stopCarRental) }
            } else if equipment.ownsCar {
                routeButton("卖车 · 收回 \(store.carResaleValue.usdText)", tint: .secondary) { perform(store.sellCar) }
            } else {
                HStack(spacing: 10) {
                    routeButton("租车", tint: AppTheme.coral) { perform(store.startCarRental) }
                    routeButton("买车", tint: .cyan) { perform(store.buyCar) }
                }
                .disabled(!store.session.hasActiveDriversLicense)
            }
        }
    }

    private var toolsCard: some View {
        routeCard(
            number: 4,
            title: "买设备 / 工具",
            symbol: "wrench.and.screwdriver.fill",
            detail: "一次性 \(store.toolsPurchasePrice.usdText)。普通工作基础工资 +15%，每次少损耗 \(store.toolsHealthProtection) 点健康。",
            completed: equipment.hasTools,
            unlocked: equipment.hasVehicleMilestone
        ) {
            if equipment.hasTools {
                statusPill("工具已备齐", tint: AppTheme.positive)
            } else {
                routeButton("购买工具", tint: AppTheme.coral) { perform(store.buyTools) }
                    .disabled(!equipment.hasVehicleMilestone)
            }
        }
    }

    private var propertyCard: some View {
        routeCard(
            number: 5,
            title: "投资物业",
            symbol: "building.2.fill",
            detail: "投入 \(store.propertyInvestmentPrice.usdText)。不再交房租；每周获得 \(store.propertyWeeklyIncome.usdText) 收入并恢复 \(store.propertyHealthRecovery) 点健康。",
            completed: equipment.hasProperty,
            unlocked: equipment.hasTools
        ) {
            if equipment.hasProperty {
                statusPill("物业已持有", tint: AppTheme.positive)
            } else {
                routeButton("投资物业", tint: AppTheme.coral) { perform(store.investInProperty) }
                    .disabled(!equipment.hasTools)
            }
        }
    }

    private var hopeCard: some View {
        Button {
            routeNotice = RouteNotice(
                title: equipment.hasHope ? "已经生根洛杉矶" : "希望尚未点亮",
                message: equipment.hasHope
                    ? "你已经完成全部五项投入。只要健康撑到第 52 周，就不会触发 ICE 遣返剧情；洛杉矶会成为故事的下一站，而不是终点。"
                    : "完成前面的五项投入，HOPE 才会点亮。它不会随周数自动增长。"
            )
        } label: {
            VStack(spacing: 12) {
                Image(systemName: equipment.hasHope ? "sun.max.fill" : "sun.max")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(equipment.hasHope ? Color.yellow : Color.white.opacity(0.35))
                    .symbolEffect(.pulse, options: .repeating, isActive: equipment.hasHope)
                Text("HOPE")
                    .font(.title2.weight(.black).monospaced())
                    .tracking(4)
                Text(equipment.hasHope ? "已经生根洛杉矶" : "完成五项投入后点亮")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(equipment.hasHope ? AppTheme.positive : .secondary)
                Text(equipment.hasHope ? "第 52 周避免 ICE 遣返结局" : "点击查看说明")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                equipment.hasHope ? Color.yellow.opacity(0.1) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(equipment.hasHope ? Color.yellow.opacity(0.55) : Color.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("americanDream.hope")
    }

    private func routeCard<Actions: View>(
        number: Int,
        title: String,
        symbol: String,
        detail: String,
        completed: Bool,
        unlocked: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(completed ? AppTheme.positive.opacity(0.18) : Color.white.opacity(0.07))
                        .frame(width: 42, height: 42)
                    Image(systemName: completed ? "checkmark" : symbol)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(completed ? AppTheme.positive : (unlocked ? AppTheme.coralSoft : .secondary))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("STEP \(number)")
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundStyle(.secondary)
                    Text(title).font(.headline)
                }
                Spacer()
                Text(completed ? "已完成" : (unlocked ? "待投入" : "未解锁"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(completed ? AppTheme.positive : .secondary)
            }

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(unlocked || completed ? .secondary : Color.secondary.opacity(0.55))

            actions()
        }
        .padding(18)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(completed ? AppTheme.positive.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        }
        .opacity(unlocked || completed ? 1 : 0.62)
    }

    private func routeButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(!store.canPerformDreamAction)
    }

    private func housingChoiceRow(_ tier: HousingTier) -> some View {
        let isActive = equipment.activeHousingTier == tier
        return Button {
            pendingHousingTier = tier
        } label: {
            HStack(spacing: 11) {
                Image(systemName: tier.symbol)
                    .font(.headline)
                    .foregroundStyle(isActive ? AppTheme.positive : AppTheme.coralSoft)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tier.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("每周 \(tier.weeklyRent.usdText) · 健康 +\(tier.weeklyHealthRecovery)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if tier.savingsProofMonths > 0 {
                        Text("存款证明 \(tier.savingsProofMonths) 个月，或预付 \(tier.prepaidWeeks) 周")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.warning)
                    }
                }
                Spacer(minLength: 4)
                Text(isActive ? "正在租住" : (equipment.rentsHousing ? "更换" : "选择"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isActive ? AppTheme.positive : AppTheme.coralSoft)
            }
            .padding(12)
            .background(Color.white.opacity(isActive ? 0.09 : 0.045), in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isActive ? AppTheme.positive.opacity(0.45) : Color.white.opacity(0.07))
            }
        }
        .buttonStyle(.plain)
        .disabled(isActive || !store.canPerformDreamAction)
    }

    private func housingPaymentSummary(_ tier: HousingTier) -> String {
        let method = equipment.activeHousingPaymentMethod
        let nextWeek = equipment.housingNextPaymentWeek ?? (store.session.day + 1)
        let amount = method == .prepaidInstallments
            ? tier.weeklyRent * tier.prepaidWeeks
            : tier.weeklyRent
        return "当前：\(method.name) · 第 \(nextWeek) 周自动扣 \(amount.usdText)"
    }

    private func statusPill(_ text: String, tint: Color) -> some View {
        Label(text, systemImage: "checkmark.seal.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func perform(_ action: () -> Bool) {
        let succeeded = action()
        if let notice = store.notice {
            routeNotice = RouteNotice(title: notice.title, message: notice.message)
            store.dismissNotice()
        } else if !succeeded {
            routeNotice = RouteNotice(title: "操作没有完成", message: "请检查现金和前置条件。")
        }
    }
}
