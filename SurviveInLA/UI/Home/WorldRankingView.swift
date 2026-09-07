import SwiftUI

struct WorldRankingView: View {
    let uploads: RankingUploadStore
    @State private var ranking = WorldRankingStore()
    @State private var nickname = ""

    var body: some View {
        List {
            Section("我的榜单昵称") {
                TextField("昵称（1–24 字）", text: $nickname)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("worldRanking.nickname")
                Button("保存昵称") {
                    uploads.saveDisplayName(nickname)
                    Task { await uploads.retryPending(); await ranking.refresh() }
                }
                .disabled(uploads.isUploading)
                Text("当前昵称：\(uploads.displayName)\(uploads.nameNeedsSync ? " · 等待同步" : "")")
                    .font(.caption).foregroundStyle(.secondary)
                Text("每次通关自动公开本局成绩。测试版使用本机玩家 ID，不读取 Apple 账户姓名；昵称请使用你愿意公开的名字。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if uploads.pendingCount > 0 || uploads.errorMessage != nil {
                Section("成绩上传") {
                    Text("\(uploads.pendingCount) 局等待上传")
                    if let error = uploads.errorMessage { Text(error).font(.caption).foregroundStyle(.secondary) }
                    Button(uploads.isUploading ? "正在上传…" : "重试上传") {
                        Task { await uploads.retryPending(); await ranking.refresh() }
                    }.disabled(uploads.isUploading)
                }
            }
            if uploads.uploads.contains(where: { $0.status == .rejected }) {
                Section("未被服务器接受的成绩") {
                    ForEach(uploads.uploads.filter { $0.status == .rejected }) { upload in
                        Text("PROFILE \(upload.submission.profileID) · \(upload.submission.netWorth.usdText)")
                        Text(upload.message ?? "请重试").font(.caption)
                        Button("重试本局") {
                            uploads.retryRejected(upload.id)
                            Task { await uploads.retryPending(); await ranking.refresh() }
                        }.disabled(uploads.isUploading)
                    }
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("TOP 50 · 世界排名", systemImage: "globe.americas.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.coralSoft)
                    Text("五十二周，每一段人生都有自己的成绩。")
                        .font(.subheadline)
                    Text("按通关存档的最终净资产排名，同一玩家的不同通关可分别上榜。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let result = ranking.result {
                        Text("\(result.totalPlayers) 位玩家 · \(result.totalRuns) 份通关存档")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("更新于 \(result.asOf.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            if let error = ranking.errorMessage {
                Section {
                    Label(error, systemImage: "wifi.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("重新加载") { Task { await ranking.refresh() } }
                        .disabled(ranking.isLoading)
                        .accessibilityIdentifier("worldRanking.retry")
                }
            }

            if let result = ranking.result {
                if result.entries.isEmpty {
                    ContentUnavailableView(
                        "还没有提交的通关成绩",
                        systemImage: "list.number",
                        description: Text("玩家提交通关成绩后，前 50 名会出现在这里。")
                    )
                    .accessibilityIdentifier("worldRanking.empty")
                } else {
                    Section("通关存档 · 前 \(result.entries.count) 名") {
                        ForEach(result.entries) { entry in
                            NavigationLink {
                                WorldRankingDetailView(entry: entry)
                            } label: {
                                WorldRankingRow(entry: entry)
                            }
                            .accessibilityIdentifier("worldRanking.run.\(entry.rank)")
                        }
                    }
                }
            } else if ranking.isLoading {
                HStack {
                    Spacer()
                    ProgressView("正在读取世界排名…")
                    Spacer()
                }
                .padding(.vertical, 28)
            }

            Section {
                Text("成绩由玩家提交，包含游戏币充值。相同净资产按首次提交顺序排列；版本号为该局提交的游戏版本。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("世界排名")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.coralSoft)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await ranking.refresh() }
                } label: {
                    if ranking.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(ranking.isLoading)
                .accessibilityLabel("刷新世界排名")
            }
        }
        .refreshable { await ranking.refresh() }
        .task { nickname = uploads.displayName; await ranking.refresh() }
    }
}

private struct WorldRankingRow: View {
    let entry: WorldRankingEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", entry.rank))
                .font(.title2.weight(.black).monospacedDigit())
                .foregroundStyle(entry.rank <= 3 ? AppTheme.warning : .secondary)
                .frame(minWidth: 34, alignment: .leading)
                .accessibilityLabel("第 \(entry.rank) 名")
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.displayName)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.netWorth.usdText)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(entry.netWorth >= 0 ? AppTheme.positive : AppTheme.coralSoft)
                    .accessibilityLabel("最终净资产 \(entry.netWorth.usdText)")
                Text("\(entry.profileName) · 版本 \(entry.appVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.ending == "rooted" ? "生根洛杉矶" : "单程广州")
                    .font(.caption2).foregroundStyle(AppTheme.coralSoft)
                Text("健康 \(entry.health) · \(entry.experienceCount) 种事件\(entry.usedPurchases ? " · 含充值" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct WorldRankingDetailView: View {
    let entry: WorldRankingEntry

    var body: some View {
        List {
            Section("最终成果") {
                LabeledContent("通关结局", value: entry.ending == "rooted" ? "生根洛杉矶" : "单程广州")
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.displayName).font(.title2.weight(.bold))
                    Text("世界第 \(entry.rank) 名 · 52 周通关")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.coralSoft)
                    Text(entry.netWorth.usdText)
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                        .foregroundStyle(entry.netWorth >= 0 ? AppTheme.positive : AppTheme.coralSoft)
                    Text("最终净资产 · 美元")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                LabeledContent("剩余健康", value: "\(entry.health) / 100")
                LabeledContent("经历事件", value: "\(entry.experienceCount) 种")
                LabeledContent("游戏币充值", value: entry.usedPurchases ? "本局使用过" : "本局未使用")
            }
            Section("提交的存档") {
                LabeledContent("玩家名字", value: entry.displayName)
                LabeledContent("存档槽位", value: entry.profileName)
                LabeledContent("游戏版本", value: entry.appVersion)
                LabeledContent("通关时间", value: entry.completedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("提交时间", value: entry.receivedAt.formatted(date: .abbreviated, time: .shortened))
            }
            Section {
                Text("这是该次通关提交的成绩摘要。名次以打开榜单时为准。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("通关成果")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RankingUploadStatusView: View {
    let uploads: RankingUploadStore
    let snapshot: GameSnapshot
    @State private var localError: String?

    private var runID: UUID? { JourneyRecord(snapshot: snapshot)?.id }
    private var upload: RankingUpload? { uploads.upload(for: runID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: upload?.status == .uploaded ? "checkmark.icloud" : "icloud.and.arrow.up")
                    .font(.caption.weight(.semibold))
                Spacer()
                if uploads.isUploading { ProgressView() }
                if upload?.status != .uploaded {
                    Button(upload == nil ? "上传本局成绩" : "重试") {
                        do {
                            try uploads.enqueue(snapshot)
                            if let runID { uploads.retryRejected(runID) }
                            localError = nil
                            Task { await uploads.retryPending() }
                        } catch { localError = "尚未保存到上传队列，请保留本局并重试。" }
                    }
                    .font(.caption.weight(.bold))
                    .disabled(uploads.isUploading)
                    .accessibilityIdentifier("ending.uploadCurrentRun")
                }
            }
            Text("\(uploads.displayName) · 仅本局 · \(snapshot.session.netWorth.usdText)")
                .font(.caption2).foregroundStyle(.secondary)
            if let error = localError ?? upload?.message ?? (upload?.status == .uploaded ? nil : uploads.errorMessage) {
                Text(error).font(.caption2).foregroundStyle(AppTheme.coralSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("ending.uploadStatus")
    }

    private var title: String {
        switch upload?.status {
        case .uploaded: return "本局已上传世界排名"
        case .pending: return uploads.isUploading ? "正在上传本局成绩" : "本局等待上传"
        case .rejected: return "本局上传需要处理"
        case nil: return "本局尚未上传世界排名"
        }
    }
}
