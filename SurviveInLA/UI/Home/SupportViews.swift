import SwiftUI

struct DiaryView: View {
    let session: GameSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("本局概览") {
                    LabeledContent("当前位置", value: GameContent.district(session.currentDistrictID).fullName)
                    LabeledContent("净资产", value: session.netWorth.usdText)
                    LabeledContent("库存", value: "\(session.usedCapacity) / \(session.capacity)")
                    LabeledContent("随身证件", value: "外国护照")
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    financeCard
                    medicalCard
                    storageCard
                }
                .padding(20)
            }
            .background(AppTheme.ink)
            .navigationTitle("城市服务")
            .navigationBarTitleDisplayMode(.inline)
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

            Stepper(value: $treatmentPoints, in: 1 ... max(1, missingHealth)) {
                Text("治疗 \(treatmentPoints) 点 · \((treatmentPoints * store.treatmentCostPerPoint).usdText)")
            }
            .disabled(missingHealth == 0)

            Button {
                _ = store.heal(treatmentPoints)
                treatmentPoints = min(treatmentPoints, max(1, missingHealth))
            } label: {
                Text(missingHealth == 0 ? "目前不需要治疗" : "接受治疗")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(missingHealth == 0)
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
