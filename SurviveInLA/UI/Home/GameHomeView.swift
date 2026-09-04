import SwiftUI

struct GameHomeView: View {
    @Bindable var store: GameStore
    var exitToProfiles: (() -> Void)?
    @State private var isDiaryPresented = false
    @State private var isServicesPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CityMapView(store: store)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HeaderView(
                    day: min(store.session.day, store.session.totalDays),
                    totalDays: store.session.totalDays,
                    exitToProfiles: exitToProfiles,
                    openDiary: { isDiaryPresented = true },
                    openServices: { isServicesPresented = true }
                )
                StatusStripView(session: store.session)
                Spacer(minLength: 220)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            MarketPanelView(store: store)

            if store.session.isFinished {
                GameResultOverlay(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
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
            DiaryView(session: store.session)
        }
        .sheet(isPresented: $isServicesPresented) {
            ServiceCenterView(store: store)
        }
        .alert(item: $store.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
}

private struct HeaderView: View {
    let day: Int
    let totalDays: Int
    let exitToProfiles: (() -> Void)?
    let openDiary: () -> Void
    let openServices: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sun.horizon.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.coralSoft)

            VStack(alignment: .leading, spacing: 3) {
                Text("洛杉矶浮生记")
                    .font(.title2.weight(.bold))
                Label("第 \(day) / \(totalDays) 天", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let exitToProfiles {
                    headerButton(symbol: "person.crop.rectangle.stack.fill", label: "游戏槽", action: exitToProfiles)
                }
                headerButton(symbol: "building.columns.fill", label: "城市服务", action: openServices)
                headerButton(symbol: "book.pages.fill", label: "生存日记", action: openDiary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func headerButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.plain)
        .background(.thinMaterial, in: Circle())
        .accessibilityLabel(label)
    }
}

#Preview {
    GameHomeView(store: GameStore(seed: 42))
}
