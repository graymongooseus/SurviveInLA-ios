import SwiftUI

struct InvestmentEventOverlay: View {
    @Bindable var store: GameStore
    @State private var amountText = ""
    @FocusState private var amountIsFocused: Bool

    private var maximumAmount: Int { min(store.session.cash, InvestmentEventEngine.maximumPrincipal) }
    private var amount: Int? {
        guard let invitation = store.session.pendingInvestmentInvitation,
              let value = Int(amountText), value >= invitation.minimumInvestment,
              value <= maximumAmount else { return nil }
        return value
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.82).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("名人交互 · 投资", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.warning)
                        if let notice = store.investmentNotice {
                            story(title: notice.title, message: notice.message)
                            EventEffectText(notice.baseEffectSummary)
                                .font(.subheadline)
                            Button("知道了") {
                                withAnimation(.snappy) { store.dismissInvestmentNotice(notice.id) }
                            }
                            .buttonStyle(InvestmentStoryButtonStyle())
                        } else if let invitation = store.session.pendingInvestmentInvitation {
                            story(title: invitation.invitation.title, message: invitation.invitation.message)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("投资金额").font(.subheadline.weight(.semibold))
                                HStack {
                                    Text("$").foregroundStyle(.secondary)
                                    TextField("输入金额", text: $amountText)
                                        .keyboardType(.numberPad)
                                        .focused($amountIsFocused)
                                        .accessibilityIdentifier("npc-investment-amount")
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                                Text("可用现金 \(store.session.cash.usdText)")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let error = store.investmentInvitationError {
                                    Text(error).font(.caption).foregroundStyle(AppTheme.warning)
                                } else if !amountText.isEmpty && amount == nil {
                                    Text("请输入 \(invitation.minimumInvestment.usdText) 至 \(max(0, maximumAmount).usdText) 的整数金额。")
                                        .font(.caption).foregroundStyle(AppTheme.warning)
                                }
                            }
                            Button("投资") {
                                guard let amount else { return }
                                amountIsFocused = false
                                store.respondToInvestmentInvitation(amount: amount)
                            }
                            .buttonStyle(InvestmentStoryButtonStyle())
                            .disabled(amount == nil)
                            .opacity(amount == nil ? 0.45 : 1)
                            .accessibilityIdentifier("npc-investment-confirm")
                            Button("这次先不投") {
                                amountIsFocused = false
                                store.respondToInvestmentInvitation(amount: nil)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("npc-investment-decline")
                        }
                    }
                    .padding(24)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: 520, maxHeight: max(100, geometry.size.height - 32))
                .padding(.horizontal, 18)
            }
        }
    }

    private func story(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.weight(.bold))
            Text(message).font(.body).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InvestmentStoryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppTheme.coral.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
