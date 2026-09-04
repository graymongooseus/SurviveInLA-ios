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
                    week: min(store.session.day, store.session.totalDays),
                    totalWeeks: store.session.totalDays,
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

            if store.isIntroductionPresented {
                OpeningStoryOverlay(store: store)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(9)
            }

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
    let week: Int
    let totalWeeks: Int
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .layoutPriority(1)
                Label("第 \(week) / \(totalWeeks) 周", systemImage: "calendar")
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

private struct OpeningStoryOverlay: View {
    @Bindable var store: GameStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.coralSoft)

                VStack(spacing: 8) {
                    Text("抵达丁胖子广场")
                        .font(.largeTitle.weight(.black))
                    Text("洛杉矶 · 第 1 周")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text("你从墨西哥一侧翻过边境围栏进入美国。一路辗转之后，你终于来到洛杉矶的丁胖子广场。没人保证这里会有新生活，但你已经没有回头路。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    storyRow("身上现金", value: "$2,000", symbol: "banknote.fill", tint: AppTheme.positive)
                    storyRow("欠下债务", value: "$5,000", symbol: "exclamationmark.triangle.fill", tint: AppTheme.negative)
                    storyRow("随身证件", value: "一本外国护照", symbol: "person.text.rectangle.fill", tint: .cyan)
                    storyRow("生存期限", value: "52 周", symbol: "calendar", tint: AppTheme.warning)
                }
                .padding(16)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))

                Text("每周只能选择一种赚钱方式：倒卖、打工或投资。")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Button("开始第 1 周") {
                    withAnimation(.snappy) { store.dismissIntroduction() }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 17))
            }
            .padding(24)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(24)
        }
    }

    private func storyRow(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.body.weight(.bold).monospacedDigit())
        }
    }
}

#Preview {
    GameHomeView(store: GameStore(seed: 42))
}
