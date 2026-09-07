import SwiftUI

struct MarketPanelView: View {
    @Bindable var store: GameStore
    @Binding var isCollapsed: Bool
    @State private var investmentAmount = 100

    private var isFinalWeek: Bool {
        store.session.day == store.session.totalDays
    }

    private var isTravelSelection: Bool {
        store.selectedAction == .trading
            && !isFinalWeek
            && store.selectedDestinationID != store.session.currentDistrictID
    }

    var body: some View {
        VStack(spacing: 0) {
            drawerHandle

            if !isCollapsed {
                actionPicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                ForEach(store.activeWorldEvents) { event in
                    worldEventBanner(event)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }

                switch store.selectedAction {
                case .trading:
                    tradingPanel
                case .work:
                    workPanel
                case .investment:
                    investmentPanel
                }

                if store.session.hasCompletedAnyWeeklyAction,
                   !isTravelSelection,
                   !(isFinalWeek && store.selectedAction == .trading) {
                    endWeekButton
                }

                StatusStripView(session: store.session)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .background(
            AppTheme.panel.opacity(0.97),
            in: UnevenRoundedRectangle(
                topLeadingRadius: 30,
                topTrailingRadius: 30,
                style: .continuous
            )
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .animation(.snappy, value: store.selectedAction)
        .animation(.snappy, value: isTravelSelection)
        .animation(.snappy, value: store.isMarketExpanded)
        .animation(.snappy, value: isCollapsed)
        .onAppear { normalizeInvestmentAmount() }
        .onChange(of: store.session.day) { _, _ in normalizeInvestmentAmount() }
    }

    private var drawerHandle: some View {
        Button {
            withAnimation(.snappy) {
                isCollapsed.toggle()
            }
        } label: {
            VStack(spacing: 7) {
                Capsule()
                    .fill(.secondary.opacity(0.55))
                    .frame(width: 42, height: 5)

                HStack(spacing: 8) {
                    Label("动作面板", systemImage: "rectangle.bottomthird.inset.filled")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.coralSoft)

                    Text(weeklyActionStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 4)

                    Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.horizontal, 20)
            .padding(.top, 9)
            .padding(.bottom, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCollapsed ? "展开动作面板" : "收起动作面板")
        .accessibilityHint("轻点切换动作面板大小")
    }

    private var actionPicker: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                ForEach(WeeklyAction.allCases) { action in
                    let isCompleted = store.session.didCompleteWeeklyAction(action)
                    Button {
                        store.selectedAction = action
                        normalizeInvestmentAmount()
                    } label: {
                        Label(action.rawValue, systemImage: isCompleted ? "checkmark.circle.fill" : action.symbol)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        store.selectedAction == action
                            ? .white
                            : (isCompleted ? AppTheme.positive : .secondary)
                    )
                    .background(
                        store.selectedAction == action ? AppTheme.coral : Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }

        }
    }

    private func worldEventBanner(_ event: WorldEvent) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "globe.americas.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.warning)
                .frame(width: 38, height: 38)
                .background(AppTheme.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("剩余 \(store.worldEventRemainingWeeks(event.id)) 周")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.warning)
                }
                Text(event.effectSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(AppTheme.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(AppTheme.warning.opacity(0.22), lineWidth: 1)
        }
    }

    private var tradingPanel: some View {
        VStack(spacing: 0) {
            panelHeader(
                symbol: isFinalWeek ? "flag.checkered" : (isTravelSelection ? "tram.fill" : "arrow.left.arrow.right"),
                title: isFinalWeek ? "最后一周" : (isTravelSelection ? "准备前往" : "本周倒卖行情"),
                subtitle: isTravelSelection ? store.selectedDestination.fullName : "\(store.currentDistrict.name)本周市场"
            )

            if !isTravelSelection && store.isMarketExpanded {
                VStack(spacing: 0) {
                    ForEach(store.session.market) { quote in
                        MarketRowView(
                            quote: quote,
                            ownedQuantity: store.session.inventory[quote.commodityID]?.quantity ?? 0
                        ) {
                            store.openTrade(for: quote.commodityID)
                        }

                        if quote.id != store.session.market.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isTravelSelection {
                travelSummary
                    .padding(.horizontal, 20)
            }

            primaryButton(
                title: isFinalWeek
                    ? "结束第 52 周并结算"
                    : (isTravelSelection ? "前往 \(store.selectedDestination.name)" : (store.isMarketExpanded ? "收起市场" : "查看市场")),
                symbol: isFinalWeek ? "flag.checkered" : (isTravelSelection ? "arrow.right.circle.fill" : "storefront.fill")
            ) {
                if isFinalWeek {
                    store.finishGame()
                } else if isTravelSelection {
                    store.travel()
                } else {
                    withAnimation(.snappy) { store.isMarketExpanded.toggle() }
                }
            }
        }
    }

    private var workPanel: some View {
        let isCompleted = store.session.didCompleteWeeklyAction(.work)
        return VStack(spacing: 0) {
            panelHeader(symbol: "hammer.fill", title: "工作或躺平", subtitle: "本周二选一 · \(store.currentDistrict.fullName)")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.currentJobs) { job in
                        jobCard(job, isCompleted: isCompleted)
                    }
                }
                .padding(.horizontal, 20)
            }

            restAtHomeCard(isCompleted: isCompleted)
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
    }

    private func restAtHomeCard(isCompleted: Bool) -> some View {
        let hasHousing = store.session.currentEquipment.hasHousing
        return HStack(spacing: 13) {
            Image(systemName: "bed.double.fill")
                .font(.title3)
                .foregroundStyle(hasHousing ? Color.cyan : Color.secondary)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text("在家躺平休息")
                    .font(.subheadline.weight(.bold))
                Text(hasHousing
                     ? "代替本周打工，恢复 \(store.restAtHomeHealthRecovery) 点健康"
                     : "需要先获得“有住处”增益")
                    .font(.caption)
                    .foregroundStyle(hasHousing ? AppTheme.positive : AppTheme.negative)
            }

            Spacer()

            Button {
                store.restAtHome()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "moon.zzz.fill")
                    .font(.title3)
                    .frame(width: 42, height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.coral)
            .disabled(isCompleted || !hasHousing)
        }
        .padding(12)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        .opacity(hasHousing && !isCompleted ? 1 : 0.62)
    }

    private func jobCard(_ job: JobOpportunity, isCompleted: Bool) -> some View {
        let housingLocked = job.requiresHousing && !store.session.currentEquipment.hasHousing
        let vehicleLocked = job.requiresVehicle && !store.session.currentEquipment.hasVehicle
        let locked = housingLocked || vehicleLocked
        let usesTools = store.session.currentEquipment.hasTools && job.id != "figueroa-pimping"
        let vehicleAdjustedHealthCost = job.requiresVehicle
            ? max(0, job.healthCost - store.vehicleHealthProtection)
            : job.healthCost
        let healthCost = max(0, vehicleAdjustedHealthCost - (usesTools ? store.toolsHealthProtection : 0))
        let equippedWage = usesTools
            ? Int((Double(job.wage) * store.toolsWageMultiplier).rounded())
            : job.wage
        let netWage = equippedWage - (job.requiresVehicle ? store.drivingOperatingCost : 0)
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(job.title).font(.headline).foregroundStyle(AppTheme.coralSoft)
                Spacer()
                if job.requiresHousing {
                    Image(systemName: "house.fill")
                        .foregroundStyle(housingLocked ? Color.secondary : AppTheme.positive)
                }
                if job.requiresVehicle {
                    Image(systemName: "car.fill").foregroundStyle(vehicleLocked ? Color.secondary : Color.cyan)
                }
            }
            Text(job.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Label("净工资 \(netWage.usdText)", systemImage: "banknote.fill")
                    .foregroundStyle(AppTheme.positive)
                Spacer()
                Label("−\(healthCost)", systemImage: "heart.fill").foregroundStyle(.pink)
            }
            .font(.caption.weight(.semibold))
            if housingLocked {
                Text("需要先获得“有住处”增益")
                    .font(.caption2).foregroundStyle(AppTheme.negative)
            } else if vehicleLocked {
                Text("还需要驾照和车辆")
                    .font(.caption2).foregroundStyle(AppTheme.negative)
            } else if !job.requiresHousing {
                Text("临时短工 · 无需住处")
                    .font(.caption2).foregroundStyle(AppTheme.warning)
            } else if job.id == "figueroa-pimping" {
                Text("连续 \(store.session.consecutivePimpingWeeks ?? 0) / 3 天")
                    .font(.caption2).foregroundStyle(AppTheme.warning)
            } else if job.requiresVehicle {
                Text("含 \(store.drivingOperatingCost.usdText) 运营费，车辆减少 \(store.vehicleHealthProtection) 点损耗\(usesTools ? "，工具继续增益" : "")")
                    .font(.caption2).foregroundStyle(.cyan)
            } else if usesTools {
                Text("工具已生效：基础工资 +15%，健康损耗 −\(store.toolsHealthProtection)")
                    .font(.caption2).foregroundStyle(.cyan)
            } else {
                Text("实际收入可能因本周插曲变化")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Button {
                store.work(job.id)
            } label: {
                Label(isCompleted ? "本周已完成" : (locked ? "条件不足" : "选择这份工"), systemImage: isCompleted ? "checkmark.circle.fill" : "hammer.fill")
                    .frame(maxWidth: .infinity).frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.coral)
            .disabled(isCompleted || locked)
        }
        .padding(14)
        .frame(width: 286, alignment: .leading)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
        .opacity(locked ? 0.62 : 1)
    }

    private var investmentPanel: some View {
        let opportunity = store.currentInvestment
        let isCompleted = store.session.didCompleteWeeklyAction(.investment)
        return VStack(spacing: 0) {
            panelHeader(
                symbol: "chart.line.uptrend.xyaxis",
                title: opportunity.title,
                subtitle: "\(store.currentDistrict.name) · \(opportunity.risk.rawValue)"
            )

            VStack(alignment: .leading, spacing: 11) {
                Text(opportunity.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("可能回报")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(opportunity.risk.returnRange)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppTheme.warning)
                }

                HStack(spacing: 8) {
                    ForEach(investmentChoices, id: \.self) { amount in
                        Button(amount.usdText) { investmentAmount = amount }
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .buttonStyle(.plain)
                            .foregroundStyle(investmentAmount == amount ? .white : AppTheme.coralSoft)
                            .background(
                                investmentAmount == amount ? AppTheme.coral : Color.white.opacity(0.07),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .disabled(isCompleted)
                    }
                }

                Text(store.session.cash < opportunity.minimumInvestment
                     ? "现金不足，最低需要 \(opportunity.minimumInvestment.usdText)。"
                     : "投入金额只影响本周盈亏，不建立长期持仓。")
                    .font(.caption)
                    .foregroundStyle(store.session.cash < opportunity.minimumInvestment ? AppTheme.negative : .secondary)
            }
            .padding(14)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            primaryButton(
                title: isCompleted ? "本周投资已完成" : "投入 \(investmentAmount.usdText) · 完成本周投资",
                symbol: isCompleted ? "checkmark.circle.fill" : "dollarsign.arrow.circlepath",
                isDisabled: isCompleted
            ) {
                store.invest(investmentAmount)
            }
            .disabled(
                store.session.cash < opportunity.minimumInvestment
                    || investmentAmount < opportunity.minimumInvestment
                    || investmentAmount > store.session.cash
            )
            .opacity(store.session.cash < opportunity.minimumInvestment ? 0.45 : 1)
        }
    }

    private var travelSummary: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("出发会结束本周")
                    .font(.subheadline.weight(.semibold))
                Text(store.selectedDestination.marketRole)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.coralSoft)
                Text("想打工或投资请先完成；出发后债务 +2%、存款 +0.2%，行情与事件刷新。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(AppTheme.warning)
        }
        .padding(14)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
    }

    private func panelHeader(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.coralSoft)
                .frame(width: 44, height: 44)
                .background(AppTheme.coral.opacity(0.18), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.coralSoft)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func primaryButton(
        title: String,
        symbol: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(isDisabled ? Color.secondary : .white)
                .background(
                    isDisabled ? Color.white.opacity(0.08) : AppTheme.coral,
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var endWeekButton: some View {
        primaryButton(
            title: isFinalWeek ? "完成第 52 周并结算" : "结束第 \(store.session.day) 周 · 留在本地",
            symbol: isFinalWeek ? "flag.checkered" : "arrow.right.circle.fill"
        ) {
            if isFinalWeek {
                store.finishGame()
            } else {
                store.finishStationaryWeek()
            }
        }
    }

    private var investmentChoices: [Int] {
        let minimum = store.currentInvestment.minimumInvestment
        guard store.session.cash >= minimum else { return [] }
        let halfCash = max(minimum, (store.session.cash / 200) * 100)
        return Array(Set([minimum, min(500, store.session.cash), halfCash]))
            .filter { $0 >= minimum && $0 <= store.session.cash }
            .sorted()
    }

    private func normalizeInvestmentAmount() {
        let choices = investmentChoices
        if !choices.contains(investmentAmount) {
            investmentAmount = choices.first ?? store.currentInvestment.minimumInvestment
        }
    }

    private var weeklyActionStatus: String {
        WeeklyAction.allCases.map { action in
            "\(action.rawValue) \(store.session.didCompleteWeeklyAction(action) ? "✓" : "○")"
        }
        .joined(separator: "  ·  ")
    }
}

private struct MarketRowView: View {
    let quote: MarketQuote
    let ownedQuantity: Int
    let action: () -> Void

    private var commodity: Commodity {
        GameContent.commodity(quote.commodityID)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: commodity.symbol)
                    .font(.title3)
                    .foregroundStyle(AppTheme.coralSoft)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))

                VStack(alignment: .leading, spacing: 3) {
                    Text(commodity.name)
                        .font(.subheadline.weight(.semibold))
                    if ownedQuantity > 0 {
                        Text("持有 \(ownedQuantity)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(quote.price.usdText)
                        .font(.body.weight(.bold).monospacedDigit())
                    trend
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var trend: some View {
        if let change = quote.change {
            let rising = change >= 0
            Label(
                change.formatted(.percent.precision(.fractionLength(0))),
                systemImage: rising ? "arrow.up.right" : "arrow.down.right"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(rising ? AppTheme.positive : AppTheme.negative)
        } else {
            Text("本周新价")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
