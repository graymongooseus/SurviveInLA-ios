import SwiftUI

struct MarketPanelView: View {
    @Bindable var store: GameStore

    private var isTravelSelection: Bool {
        !isFinalDay && store.selectedDestinationID != store.session.currentDistrictID
    }

    private var isFinalDay: Bool {
        store.session.day == store.session.totalDays
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.45))
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 12)

            HStack(spacing: 12) {
                Image(systemName: isFinalDay ? "flag.checkered" : (isTravelSelection ? "tram.fill" : "chart.line.uptrend.xyaxis"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.coralSoft)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.coral.opacity(0.18), in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 3) {
                    Text(isFinalDay ? "最后一天" : (isTravelSelection ? "准备前往" : "今日市场机会"))
                        .font(.headline)
                        .foregroundStyle(AppTheme.coralSoft)
                    Text(isTravelSelection ? store.selectedDestination.fullName : "\(store.currentDistrict.name) 今日市场")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isTravelSelection {
                    Text(store.selectedDestination.transitHint)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

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

            Button {
                if isFinalDay {
                    store.finishGame()
                } else if isTravelSelection {
                    store.travel()
                } else {
                    withAnimation(.snappy) {
                        store.isMarketExpanded.toggle()
                    }
                }
            } label: {
                Label(
                    isFinalDay
                        ? "结束旅程并结算"
                        : (isTravelSelection ? "前往 \(store.selectedDestination.name)" : (store.isMarketExpanded ? "收起市场" : "查看市场")),
                    systemImage: isFinalDay ? "flag.checkered" : (isTravelSelection ? "arrow.right.circle.fill" : "storefront.fill")
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)
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
        .animation(.snappy, value: isTravelSelection)
        .animation(.snappy, value: store.isMarketExpanded)
    }

    private var travelSummary: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("移动会进入下一天")
                    .font(.subheadline.weight(.semibold))
                Text(store.selectedDestination.marketRole)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.coralSoft)
                Text("交通不额外收费；债务 +10%，行情和事件刷新。")
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
            Text("今日新价")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
