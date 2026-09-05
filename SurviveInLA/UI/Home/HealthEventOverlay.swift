import SwiftUI

/// 图片负责叙事氛围，文案与基础效果始终来自事件数据。
struct HealthEventOverlay: View {
    let event: GameEvent
    let dismiss: () -> Void
    @ScaledMetric(relativeTo: .body) private var contentHeight: CGFloat = 342

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 36, 440)
            let heroHeight = min(width * 0.86, 320)
            ZStack {
                Color.black.opacity(0.86)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            hero(height: heroHeight)
                            content
                        }
                    }
                    .scrollIndicators(.hidden)
                    .defaultScrollAnchor(.top)

                    Button("知道了", action: dismiss)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 16))
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                        .accessibilityIdentifier("health-event-dismiss")
                        .accessibilityHint("关闭事件卡片")
                }
                .frame(width: width, height: min(heroHeight + contentHeight, geometry.size.height - 24))
                .background(AppTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
                .accessibilityAddTraits(.isModal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func hero(height: CGFloat) -> some View {
        GeometryReader { geometry in
            if let imageName = event.healthEventImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: height)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, AppTheme.ink.opacity(0.55), AppTheme.ink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: height * 0.32)
                    }
                    .accessibilityLabel("\(event.title)事件插图")
            }
        }
        .frame(height: height)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("健康事件")
                    .font(.caption.weight(.bold))
                Rectangle()
                    .frame(width: 28, height: 1)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AppTheme.coralSoft)

            Text(event.title)
                .font(.system(.title, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
                .accessibilityAddTraits(.isHeader)

            Text("基础效果")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 14)

            Rectangle()
                .fill(.white.opacity(0.16))
                .frame(height: 1)
                .padding(.top, 10)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                effect("健康", value: event.healthDelta, isCash: false)
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(width: 1, height: 48)
                    .accessibilityHidden(true)
                effect("现金", value: event.cashDelta, isCash: true)
            }
            .padding(.top, 14)

            Text(event.message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.74))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 23)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
    }

    private func effect(_ title: String, value: Int, isCash: Bool) -> some View {
        let magnitude = isCash ? abs(value).usdText : String(abs(value))
        let text = value == 0 ? "无变化" : "\(value < 0 ? "−" : "+")\(magnitude)"
        return VStack(spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.58))
            Text(text)
                .font(.system(value == 0 ? .title2 : .largeTitle, weight: .bold).monospacedDigit())
                .foregroundStyle(value < 0 ? AppTheme.coral : (value > 0 ? AppTheme.positive : .white.opacity(0.65)))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HealthEventOverlay(event: LocationEventCatalog.healthEvents[0], dismiss: {})
        .preferredColorScheme(.dark)
}
