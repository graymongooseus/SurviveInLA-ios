import SwiftUI

struct TradeSheetView: View {
    @Bindable var store: GameStore
    let context: TradeContext

    @Environment(\.dismiss) private var dismiss
    @State private var mode: TradeMode
    @State private var quantity = 1

    init(store: GameStore, context: TradeContext) {
        self.store = store
        self.context = context
        _mode = State(initialValue: context.mode)
    }

    private var commodity: Commodity {
        GameContent.commodity(context.commodityID)
    }

    private var quote: MarketQuote? {
        store.session.market.first(where: { $0.commodityID == context.commodityID })
    }

    private var owned: InventoryPosition? {
        store.session.inventory[context.commodityID]
    }

    private var maximumQuantity: Int {
        guard let quote else { return 0 }
        switch mode {
        case .buy:
            return min(store.session.availableCapacity, store.session.cash / max(1, quote.price))
        case .sell:
            return owned?.quantity ?? 0
        }
    }

    private var total: Int {
        (quote?.price ?? 0) * quantity
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                HStack(spacing: 14) {
                    Image(systemName: commodity.symbol)
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.coralSoft)
                        .frame(width: 64, height: 64)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(commodity.name)
                            .font(.title3.weight(.bold))
                        Text("现价 \((quote?.price ?? 0).usdText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Picker("交易类型", selection: $mode) {
                    ForEach(TradeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in normalizeQuantity() }

                VStack(spacing: 10) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("数量")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(quantity) 件")
                                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        }

                        Spacer()

                        Button {
                            quantity = maximumQuantity
                        } label: {
                            Text("全部 \(maximumQuantity) 件")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 38)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.coralSoft)
                        .disabled(maximumQuantity == 0)
                    }

                    if maximumQuantity > 1 {
                        Slider(
                            value: Binding(
                                get: { Double(quantity) },
                                set: { quantity = Int($0.rounded()) }
                            ),
                            in: 1 ... Double(maximumQuantity),
                            step: 1
                        )
                        .tint(AppTheme.coral)
                        .accessibilityLabel("交易数量")
                        .accessibilityValue("\(quantity) 件，最多 \(maximumQuantity) 件")
                    }

                    Text(maximumQuantity > 0 ? "可交易 1–\(maximumQuantity) 件" : "暂无可交易数量")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Text(mode == .buy ? "预计支出" : "预计收入")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(total.usdText)
                        .font(.title3.weight(.bold).monospacedDigit())
                }

                Button {
                    if store.performTrade(
                        commodityID: context.commodityID,
                        mode: mode,
                        quantity: quantity
                    ) {
                        dismiss()
                    }
                } label: {
                    Text("确认\(mode.rawValue) \(quantity) 件")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 17))
                .disabled(maximumQuantity == 0 || quantity == 0)
                .opacity(maximumQuantity == 0 ? 0.45 : 1)

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(AppTheme.panel)
            .onAppear { normalizeQuantity() }
            .onChange(of: maximumQuantity) { _, _ in normalizeQuantity() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func normalizeQuantity() {
        quantity = maximumQuantity > 0
            ? min(max(quantity, 1), maximumQuantity)
            : 0
    }
}
