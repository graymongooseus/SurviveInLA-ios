import MapKit
import SwiftUI

struct ProfileSelectionView: View {
    @Bindable var manager: ProfileManager
    @State private var isRulesPresented = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 34.035, longitude: -118.29),
            span: MKCoordinateSpan(latitudeDelta: 0.34, longitudeDelta: 0.28)
        )
    )

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    titleBlock
                        .padding(.top, 34)
                        .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        ForEach(manager.slots) { slot in
                            ProfileSlotCard(slot: slot) {
                                withAnimation(.snappy) {
                                    manager.open(slot.id)
                                }
                            }
                        }
                    }

                    ironmanNotice
                        .padding(.top, 22)

                    Button("游戏规则") {
                        isRulesPresented = true
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.vertical, 22)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .safeAreaPadding(.vertical, 8)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isRulesPresented) {
            IronmanRulesView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .alert(item: $manager.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }

    private var background: some View {
        ZStack {
            Map(position: $cameraPosition, interactionModes: [])
                .mapStyle(
                    .standard(
                        elevation: .flat,
                        emphasis: .muted,
                        pointsOfInterest: .excludingAll,
                        showsTraffic: false
                    )
                )
                .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Color(red: 0.015, green: 0.035, blue: 0.055).opacity(0.66),
                    Color(red: 0.015, green: 0.035, blue: 0.055).opacity(0.88),
                    Color(red: 0.01, green: 0.025, blue: 0.04).opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [AppTheme.coral.opacity(0.09), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 310
            )
        }
        .ignoresSafeArea()
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.coralSoft)

            Text("洛杉矶浮生记")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .tracking(-1.2)
                .minimumScaleFactor(0.82)
                .lineLimit(1)

            Text("SURVIVE IN LA")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(5)
                .foregroundStyle(AppTheme.coralSoft.opacity(0.9))

            HStack(spacing: 12) {
                Rectangle()
                    .frame(height: 1)
                Text("选择一段人生")
                    .font(.subheadline.weight(.medium))
                    .fixedSize()
                Rectangle()
                    .frame(height: 1)
            }
            .foregroundStyle(.white.opacity(0.42))
            .padding(.horizontal, 32)
            .padding(.top, 10)
        }
    }

    private var ironmanNotice: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.07), in: Circle())
                .overlay {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("仅保存最新进度")
                    .font(.subheadline.weight(.bold))
                Text("你的每个选择都会被立即记录，无法回到过去。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
    }
}

private struct ProfileSlotCard: View {
    let slot: ProfileSlot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let snapshot = slot.snapshot {
                activeContent(snapshot)
            } else {
                emptyContent
            }
        }
        .buttonStyle(ProfileCardButtonStyle())
        .accessibilityHint(slot.isEmpty ? "创建新游戏" : "载入最新自动存档")
    }

    private func activeContent(_ snapshot: GameSnapshot) -> some View {
        let session = snapshot.session
        let district = GameContent.district(session.currentDistrictID)
        let completed = session.isFinished

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(slot.id.displayName)
                        .profileLabel(active: true)
                    Text(completed ? "查看结局" : "继续生存")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                    Text(district.fullName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 0) {
                        Text("第 ")
                        Text("\(min(session.day, session.totalDays))")
                            .foregroundStyle(AppTheme.coralSoft)
                        Text(" / \(session.totalDays) 周")
                    }
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.title2.weight(.bold))
                    .frame(width: 54, height: 54)
                    .foregroundStyle(.white)
                    .background(AppTheme.coral, in: Circle())
                    .shadow(color: AppTheme.coral.opacity(0.25), radius: 14)
            }

            ProgressView(
                value: Double(min(session.day, session.totalDays)),
                total: Double(session.totalDays)
            )
            .tint(AppTheme.coralSoft)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            HStack(spacing: 0) {
                metric("现金", value: session.cash.usdText, symbol: "banknote.fill", tint: AppTheme.positive)
                divider
                metric("欠款", value: session.debt.usdText, symbol: "exclamationmark.triangle.fill", tint: .orange)
                divider
                metric("健康", value: "\(session.health)", symbol: "heart.fill", tint: .pink)
            }
        }
        .padding(20)
        .background(activeBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppTheme.coralSoft.opacity(0.9), lineWidth: 1.2)
        }
    }

    private var emptyContent: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(slot.id.displayName)
                    .profileLabel(active: false)
                Text("开始新人生")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("从丁胖子广场的第 1 周开始")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 48, height: 48)
                .overlay {
                    Circle().stroke(Color.white.opacity(0.26), lineWidth: 1)
                }
        }
        .padding(20)
        .frame(minHeight: 116)
        .background(emptyBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    private func metric(_ title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title)
                    .foregroundStyle(.white.opacity(0.56))
            }
            .font(.caption.weight(.semibold))
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 40)
    }

    private var activeBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.08, blue: 0.11).opacity(0.98),
                Color(red: 0.09, green: 0.085, blue: 0.105).opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var emptyBackground: some ShapeStyle {
        Color(red: 0.055, green: 0.075, blue: 0.1).opacity(0.92)
    }
}

private struct ProfileCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private extension View {
    func profileLabel(active: Bool) -> some View {
        font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(2.1)
            .foregroundStyle(active ? AppTheme.coralSoft : Color.white.opacity(0.48))
    }
}

private struct IronmanRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                rule("arrow.triangle.2.circlepath", "自动记录", "交易、移动和城市服务完成后，系统立即覆盖当前 Profile 的进度。")
                rule("clock.arrow.circlepath", "无法回退", "每个 Profile 只保留一个最新状态，不提供历史存档或读档重试。")
                rule("person.3.fill", "三段人生", "三个 Profile 互相独立，你可以同时进行三段不同的旅程。")
                Spacer()
            }
            .padding(24)
            .background(AppTheme.ink)
            .navigationTitle("游戏规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func rule(_ symbol: String, _ title: String, _ message: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(AppTheme.coralSoft)
                .frame(width: 40, height: 40)
                .background(AppTheme.coral.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ProfileSelectionView(manager: ProfileManager())
}
