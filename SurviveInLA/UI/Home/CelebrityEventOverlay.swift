import SwiftUI

struct CelebrityEventOverlay: View {
    @Bindable var store: GameStore
    let encounter: PendingCelebrityEncounter

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.82).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("名人交互 · 合影", systemImage: "camera.fill")
                            .font(.caption.weight(.bold)).foregroundStyle(AppTheme.warning)
                        switch encounter.stage {
                        case .invitation:
                            story(encounter.event.invitation)
                            action("上前问问能不能合影", id: "celebrity-approach") {
                                store.respondToCelebrityInvitation(encounter.id, approach: true)
                            }
                            Button("点头打招呼，继续看海") {
                                store.respondToCelebrityInvitation(encounter.id, approach: false)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(.secondary)
                        case .background:
                            story(encounter.event.selection)
                            ForEach(encounter.event.options) { option in
                                Button {
                                    store.chooseCelebrityBackground(option.id, encounterID: encounter.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(option.title).font(.headline)
                                        EventEffectText("\(option.buff.effectSummary) · \(option.buff.durationTurns) 回合")
                                            .font(.caption).foregroundStyle(AppTheme.warning)
                                        Text("签名合照可出售 \(option.salePrice.usdText)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("celebrity-background-\(option.id)")
                            }
                        case .result:
                            if let option = encounter.selectedOption {
                                story(EventStory(title: option.photoTitle, message: option.result))
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(option.buff.title, systemImage: "sparkles").font(.headline)
                                    EventEffectText("\(option.buff.effectSummary) · 持续 \(option.buff.durationTurns) 回合")
                                        .font(.subheadline)
                                    Text(option.buff.message).font(.caption).foregroundStyle(.secondary)
                                }
                                .foregroundStyle(AppTheme.warning)
                                Text("码头的照片收藏者愿意出 \(option.salePrice.usdText) 收下这张签名合照。出售后，合影带来的增益仍然生效。")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                action("出售合照 · +\(option.salePrice.usdText)", id: "celebrity-photo-sell-now") {
                                    store.finishCelebrityEncounter(encounter.id, sell: true)
                                }
                                Button("留作纪念，放入合照相册") {
                                    store.finishCelebrityEncounter(encounter.id, sell: false)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .accessibilityIdentifier("celebrity-photo-keep")
                            }
                        }
                        if let error = store.celebrityEventError {
                            Text(error).font(.caption).foregroundStyle(AppTheme.negative)
                        }
                    }
                    .padding(24)
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28))
                    .overlay { RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.14)) }
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: 520, maxHeight: max(100, geometry.size.height - 32))
                .padding(.horizontal, 18)
            }
        }
    }

    private func story(_ story: EventStory) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(story.title).font(.title2.weight(.bold))
            Text(story.message).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func action(_ title: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title).font(.headline).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

struct CelebrityCollectionView: View {
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var canSell: Bool {
        !store.session.isFinished && store.session.pendingCelebrityEncounter == nil
            && store.session.pendingInvestmentInvitation == nil && store.pendingLifeChoice == nil
    }

    var body: some View {
        NavigationStack {
            List {
                Section("正在生效") {
                    if store.session.currentPlayerBuffs.isEmpty {
                        Text("暂时没有名人交互带来的增益。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.session.currentPlayerBuffs) { buff in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(buff.definition.title, systemImage: "sparkles").font(.headline)
                            EventEffectText(buff.definition.effectSummary).font(.subheadline)
                            Text("剩余 \(buff.remainingTurns) 回合").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("合照相册") {
                    if (store.session.celebrityPhotos ?? []).isEmpty {
                        Text("遇见名人，留下属于你的洛城回忆。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach((store.session.celebrityPhotos ?? []).reversed()) { photo in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(photo.title).font(.headline)
                            Text("第 \(photo.acquiredTurn) 回合 · 签名合照")
                                .font(.caption).foregroundStyle(.secondary)
                            if let soldTurn = photo.soldTurn {
                                Text("第 \(soldTurn) 回合已出售 · \(photo.salePrice.usdText)")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("出售合照 · +\(photo.salePrice.usdText)") {
                                    store.sellCelebrityPhoto(photo.id)
                                }
                                .disabled(!canSell)
                                .accessibilityIdentifier("celebrity-photo-sell-\(photo.id)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                if let error = store.celebrityEventError {
                    Text(error).foregroundStyle(AppTheme.negative)
                }
            }
            .navigationTitle("合照与增益")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
