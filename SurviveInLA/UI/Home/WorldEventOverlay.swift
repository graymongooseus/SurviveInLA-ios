import SwiftUI

struct WorldEventOverlay: View {
    @Bindable var store: GameStore
    let notice: WorldEventNotice

    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    private var event: WorldEvent {
        var definition = WorldEventCatalog.event(notice.eventID)!
        let instance = ((store.session.unreadWorldEvents ?? []) + store.session.activeWorldEvents).first {
            $0.eventID == notice.eventID && $0.startedWeek == notice.triggeredWeek
        }
        definition.modifiers = instance?.modifiers ?? definition.modifiers
        return definition
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.82)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        heroImage
                        eventContent
                    }
                    .background(
                        .ultraThickMaterial,
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                }
                .scrollIndicators(.hidden)
                .frame(
                    maxWidth: 520,
                    maxHeight: min(geometry.size.height - 32, 780)
                )
                .padding(.horizontal, 18)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var heroImage: some View {
        Image(event.imageName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 188)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 92)
            }
            .overlay(alignment: .bottomLeading) {
                Label("世界事件", systemImage: "globe.americas.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.46), in: Capsule())
                    .padding(14)
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    topTrailingRadius: 28,
                    style: .continuous
                )
            )
            .accessibilityLabel("\(event.title)事件插图")
    }

    private var eventContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.title2.weight(.black))
                Text("第 \(notice.triggeredWeek) 周触发 · 持续至第 \(notice.endingWeek) 周")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.warning)
                Text(event.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(store.activeWorldEvents.count > 1 ? "叠加后的数值影响" : "当前数值影响")
                    .font(.headline)

                Text("本事件：\(event.effectSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if store.activeWorldEvents.count > 1 {
                    Text("同时生效：" + store.activeWorldEvents.map(\.title).joined(separator: "、"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(impactItems) { item in
                        impactCard(item)
                    }
                }
            }

            if let localNotice = notice.localNotice, localNotice.healthEvent == nil {
                VStack(alignment: .leading, spacing: 5) {
                    Label("同时发生 · \(localNotice.title)", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.coralSoft)
                    Text(localNotice.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
            }

            Button("知道了") {
                withAnimation(.snappy) { store.dismissWorldEvent() }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(20)
    }

    private func impactCard(_ item: ImpactItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(item.title, systemImage: item.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(item.value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(item.tone.color)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
    }

    private var impactItems: [ImpactItem] {
        let modifiers = store.combinedWorldModifiers
        return [
            ImpactItem(
                id: "work",
                title: "打工收入",
                symbol: "hammer.fill",
                value: multiplierText(modifiers.workIncome),
                tone: directionTone(modifiers.workIncome)
            ),
            ImpactItem(
                id: "trade",
                title: "倒卖收入",
                symbol: "arrow.left.arrow.right",
                value: multiplierText(modifiers.tradeIncome),
                tone: directionTone(modifiers.tradeIncome)
            ),
            ImpactItem(
                id: "market-price",
                title: "消费品报价",
                symbol: "cart.fill.badge.plus",
                value: multiplierText(modifiers.marketPrice),
                tone: directionTone(modifiers.marketPrice, higherIsBetter: false)
            ),
            ImpactItem(
                id: "bank",
                title: "存款周息",
                symbol: "building.columns.fill",
                value: interestText(
                    principal: store.session.bank,
                    baseRate: store.bankInterestRate,
                    multiplier: modifiers.bankInterest
                ),
                tone: directionTone(modifiers.bankInterest)
            ),
            ImpactItem(
                id: "investment",
                title: "投资盈亏",
                symbol: "chart.line.uptrend.xyaxis",
                value: investmentText(modifiers),
                tone: modifiers.investmentReturnCap == nil ? .mixed : .unfavorable
            ),
            ImpactItem(
                id: "debt",
                title: "债务周息",
                symbol: "exclamationmark.triangle.fill",
                value: interestText(
                    principal: store.session.debt,
                    baseRate: store.debtInterestRate,
                    multiplier: modifiers.debtInterest
                ),
                tone: directionTone(modifiers.debtInterest, higherIsBetter: false)
            ),
            ImpactItem(
                id: "health",
                title: "健康变动",
                symbol: "heart.fill",
                value: multiplierText(modifiers.healthChange),
                tone: .mixed
            ),
        ]
    }

    private func multiplierText(_ multiplier: Double) -> String {
        let percentage = Int(((multiplier - 1) * 100).rounded())
        let signedPercentage = percentage >= 0 ? "+\(percentage)%" : "\(percentage)%"
        return String(format: "×%.2f · %@", multiplier, signedPercentage)
    }

    private func investmentText(_ modifiers: WorldEventModifiers) -> String {
        guard let cap = modifiers.investmentReturnCap else {
            return multiplierText(modifiers.investmentReturn)
        }
        return "最高回报 \(cap)% · 强制亏损"
    }

    private func interestText(
        principal: Int,
        baseRate: Double,
        multiplier: Double
    ) -> String {
        let adjustedRate = baseRate * multiplier
        let amount = Int((Double(principal) * adjustedRate).rounded(.down))
        return String(
            format: "%.2f%% → %.2f%% · +%@",
            baseRate * 100,
            adjustedRate * 100,
            amount.usdText
        )
    }

    private func directionTone(
        _ multiplier: Double,
        higherIsBetter: Bool = true
    ) -> ImpactTone {
        guard multiplier != 1 else { return .mixed }
        let isFavorable = higherIsBetter ? multiplier > 1 : multiplier < 1
        return isFavorable ? .favorable : .unfavorable
    }
}

private struct ImpactItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let value: String
    let tone: ImpactTone
}

private enum ImpactTone {
    case favorable
    case unfavorable
    case mixed

    var color: Color {
        switch self {
        case .favorable: AppTheme.positive
        case .unfavorable: AppTheme.negative
        case .mixed: AppTheme.warning
        }
    }
}
