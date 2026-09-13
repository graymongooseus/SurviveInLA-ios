import SwiftUI

struct CelebrityActingOverlay: View {
    @Bindable var store: GameStore

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.82).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Label("名人交互 · 片场邀约", systemImage: "film.stack")
                            .font(.caption.weight(.bold)).foregroundStyle(AppTheme.warning)
                        if let notice = store.actingNotice {
                            Text(notice.title).font(.title2.weight(.bold))
                            Text(notice.message).fixedSize(horizontal: false, vertical: true)
                            EventEffectText(notice.baseEffectSummary).font(.subheadline)
                            Button("收下这段经历") { store.dismissActingNotice(notice.id) }
                                .buttonStyle(ActingChoiceStyle())
                                .accessibilityIdentifier("acting-notice-dismiss")
                        } else if let encounter = store.session.pendingActingEncounter {
                            Text(encounter.event.invitation.title).font(.title2.weight(.bold))
                            Text(encounter.event.invitation.message).fixedSize(horizontal: false, vertical: true)
                            ForEach(encounter.event.options) { option in
                                Button {
                                    store.chooseActingRole(option.id, encounterID: encounter.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(option.title).font(.headline)
                                        EventEffectText(option.effectSummary).font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .padding(16)
                                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                                .accessibilityIdentifier("acting-choice-\(option.id)")
                            }
                            if let error = store.actingEventError {
                                Text(error).font(.footnote).foregroundStyle(AppTheme.negative)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28))
                    .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.14), lineWidth: 1) }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: 520, maxHeight: max(100, geometry.size.height - 32))
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct ActingChoiceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(12)
            .background(AppTheme.coral.opacity(configuration.isPressed ? 0.65 : 0.9), in: RoundedRectangle(cornerRadius: 14))
    }
}
