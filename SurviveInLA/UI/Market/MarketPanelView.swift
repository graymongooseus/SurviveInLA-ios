import SwiftUI

struct MarketPanelView: View {
    @Bindable var store: GameStore
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
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)

            actionPicker
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if let event = store.activeWorldEvent {
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
        .onAppear { normalizeInvestmentAmount() }
        .onChange(of: store.session.day) { _, _ in normalizeInvestmentAmount() }
    }

    private var actionPicker: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                ForEach(WeeklyAction.allCases) { action in
                    Button {
                        store.selectedAction = action
                        if action != .trading {
                            store.select(store.session.currentDistrictID)
                        }
                        normalizeInvestmentAmount()
                    } label: {
                        Label(action.rawValue, systemImage: action.symbol)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.selectedAction == action ? .white : .secondary)
                    .background(
                        store.selectedAction == action ? AppTheme.coral : Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .disabled(store.session.actionThisWeek.map { $0 != action } ?? false)
                    .opacity(store.session.actionThisWeek.map { $0 != action } == true ? 0.38 : 1)
                }
            }

            Text(weeklyActionStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                    Text("剩余 \(store.activeWorldEventRemainingWeeks) 周")
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
        let job = store.currentJob
        let isCompleted = store.session.actionThisWeek == .work
        return VStack(spacing: 0) {
            panelHeader(symbol: "hammer.fill", title: job.title, subtitle: store.currentDistrict.fullName)

            VStack(alignment: .leading, spacing: 10) {
                Text(job.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Label(
                        store.session.currentDistrictID == .figueroaCorridor
                            ? "收入 $500–$700"
                            : "工资 \(job.wage.usdText)",
                        systemImage: "banknote.fill"
                    )
                        .foregroundStyle(AppTheme.positive)
                    Spacer()
                    Label("健康 −\(job.healthCost)", systemImage: "heart.fill")
                        .foregroundStyle(.pink)
                }
                .font(.subheadline.weight(.semibold))
                Text(
                    store.session.currentDistrictID == .figueroaCorridor
                        ? "扫黄事件有 30% 几率令当周收入翻倍；当前连续 \(store.session.consecutivePimpingWeeks ?? 0) / 3 周，第三周将触发 LAPD 钓鱼执法。"
                        : "实际收入可能因本周的小插曲略有变化。"
                )
                    .font(.caption)
                    .foregroundStyle(
                        store.session.currentDistrictID == .figueroaCorridor
                            ? AppTheme.warning
                            : Color.secondary
                    )
            }
            .padding(14)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            primaryButton(
                title: isCompleted ? "本周打工已完成" : "开始打工 · 完成本周任务",
                symbol: isCompleted ? "checkmark.circle.fill" : "hammer.fill",
                isDisabled: isCompleted
            ) {
                store.work()
            }

            if isCompleted {
                primaryButton(
                    title: isFinalWeek ? "完成第 52 周并结算" : "结束第 \(store.session.day) 周 · 进入下一周",
                    symbol: isFinalWeek ? "flag.checkered" : "arrow.right.circle.fill"
                ) {
                    store.finishStationaryWeek()
                }
            }
        }
    }

    private var investmentPanel: some View {
        let opportunity = store.currentInvestment
        let isCompleted = store.session.actionThisWeek == .investment
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
                title: isCompleted ? "本周投资已完成" : "投入 \(investmentAmount.usdText) · 完成本周任务",
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

            if isCompleted {
                primaryButton(
                    title: isFinalWeek ? "完成第 52 周并结算" : "结束第 \(store.session.day) 周 · 进入下一周",
                    symbol: isFinalWeek ? "flag.checkered" : "arrow.right.circle.fill"
                ) {
                    store.finishStationaryWeek()
                }
            }
        }
    }

    private var travelSummary: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("这趟倒卖会进入下一周")
                    .font(.subheadline.weight(.semibold))
                Text(store.selectedDestination.marketRole)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.coralSoft)
                Text("交通不额外收费；债务 +2%，存款 +0.2%，行情与事件刷新。")
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
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDisabled ? Color.secondary : .white)
        .background(
            isDisabled ? Color.white.opacity(0.08) : AppTheme.coral,
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .disabled(isDisabled)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
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
        switch store.session.actionThisWeek {
        case .trading: "本周已选择倒卖，前往新地点后进入下一周"
        case .work: "本周打工任务已完成，请进入下一周"
        case .investment: "本周投资任务已完成，请进入下一周"
        case nil: "每周只能选择一种赚钱方式"
        }
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
