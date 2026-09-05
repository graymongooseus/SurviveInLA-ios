import SwiftUI

struct GameResultOverlay: View {
    @Bindable var store: GameStore
    var exitToProfiles: (() -> Void)?
    @State private var showsSummary = false
    @State private var showsLeaderboard = false
    @State private var confirmsRestart = false

    private var session: GameSession { store.session }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("洛杉矶浮生记 / 终章", systemImage: "sun.horizon.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.coralSoft)
                Spacer()
                if let exitToProfiles {
                    Button("返回存档", action: exitToProfiles)
                        .font(.caption.weight(.semibold))
                        .tint(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if showsSummary || !session.isDeported {
                        summary
                    } else {
                        departure
                    }
                }
                .frame(maxWidth: 540)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
            .id(showsSummary)

            VStack(spacing: 10) {
                if !showsSummary && session.isDeported {
                    Button { showsSummary = true } label: {
                        HStack {
                            Text("翻开这一年的账单")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                    }
                    .buttonStyle(EndingButtonStyle())
                }
                Button {
                    store.loadLeaderboard()
                    showsLeaderboard = true
                } label: {
                    Label("查看排行榜", systemImage: "list.number")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EndingButtonStyle(prominent: showsSummary || !session.isDeported))
                .accessibilityIdentifier("ending.leaderboard")

                if showsSummary || !session.isDeported {
                    HStack {
                        if session.isDeported {
                            Button("重读终章") { showsSummary = false }
                            Spacer()
                        }
                        Button("开始新的人生") { confirmsRestart = true }
                            .accessibilityIdentifier("ending.restart")
                    }
                    .font(.subheadline)
                    .tint(.white.opacity(0.7))
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(AppTheme.ink.shadow(color: .black.opacity(0.3), radius: 16, y: -6))
        }
        .background(AppTheme.ink.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
        .sheet(isPresented: $showsLeaderboard) {
            JourneyLeaderboardView(store: store)
        }
        .alert("开始新的人生？", isPresented: $confirmsRestart) {
            Button("再看看", role: .cancel) { }
            Button("重新开始") { store.restart() }
        } message: {
            Text("本局成绩和历史事件会保留在本机排行榜，新旅程将从第 1 周开始。")
        }
    }

    private var departure: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                Text("WEEK 52 · 最后一天")
                    .font(.caption.weight(.bold).monospaced())
                    .tracking(2)
                    .foregroundStyle(AppTheme.coralSoft)
                Text("门响了。\n美国梦醒了。")
                    .font(.system(size: 39, weight: .black, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
                Text("你以为还有下周。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }

            VStack(alignment: .leading, spacing: 16) {
                storyText("第 52 周的一个清晨，敲门声比闹钟先响。你以为是房东，门外却是 ICE 执法人员。对方核对了姓名，没给你收拾生活的时间，就把你直接带走。")
                storyText("锅里还有昨夜的饭，手机上还有没回的报价。车窗外，熟悉的路口一个接一个退后。你突然明白：这座城市照常醒来，只是今天不再需要你。")
                storyText("之后的日子缩成了几道门、几次叫号和一张纸。剩下的货被清算，账户里扣掉 500 美元，换来一张飞往广州的单程机票。在这个故事里，你被永久禁止再次进入美国。")
            }
            boardingPass
            Text("你带走的，究竟是本钱，\n还是一身还没来得及算的账？")
                .font(.title3.weight(.semibold))
                .lineSpacing(5)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var boardingPass: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ONE WAY / 单程")
                    .font(.caption2.weight(.black).monospaced())
                    .tracking(2)
                Spacer()
                Text("$500")
                    .font(.headline.monospacedDigit())
            }
            HStack {
                airport("LAX", city: "洛杉矶")
                Spacer()
                Image(systemName: "airplane")
                    .font(.title2)
                    .foregroundStyle(AppTheme.coral)
                Spacer()
                airport("CAN", city: "广州")
            }
            Rectangle().fill(.black.opacity(0.15)).frame(height: 1)
            HStack {
                Text("行李：一年的浮生")
                Spacer()
                Text("无返程")
                    .foregroundStyle(Color(red: 0.65, green: 0.15, blue: 0.12))
            }
            .font(.caption.weight(.semibold))
        }
        .padding(20)
        .foregroundStyle(Color.black.opacity(0.82))
        .background(Color(red: 0.91, green: 0.88, blue: 0.80), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var summary: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(min(session.day, session.totalDays)) 周 · 人生结算")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.coralSoft)
                Text(session.health <= 0 ? "身体先说了再见。" : "这一年，值不值？")
                    .font(.largeTitle.weight(.black))
                Text(session.isDeported ? "一张回程票，把所有数字变成了过去。" : "每一份成绩，都有数字之外的代价。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(session.isDeported ? "回国净本钱" : "最终净资产")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Text(session.netWorth.usdText)
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(session.netWorth > 0 ? AppTheme.positive : AppTheme.coralSoft)
                Text(session.isDeported ? "已清算库存、扣除机票及全部未偿债务 · 美元" : "现金 + 存款 − 债务 · 美元；未清算库存不计入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 22))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metric("这一年净赚", value: session.netGain?.usdText ?? "未记录", detail: "期末净资产 − 开局净资产", symbol: "dollarsign.circle", tint: AppTheme.positive)
                metric("累计健康损耗", value: session.journey.map { "\($0.healthLost) 点" } ?? "未记录", detail: "现有健康 \(session.health) / 100", symbol: "heart.slash", tint: AppTheme.coralSoft)
                metric("走过的街区", value: session.journey.map { "\($0.visitedDistricts.count) / \(GameContent.districts.count)" } ?? "未记录", detail: "不同地点，不同活法", symbol: "map", tint: .cyan)
                metric("经历的事件", value: "\(session.experienceCount) 种", detail: "已记录 \(session.historicalEvents.count) 次遭遇", symbol: "book.pages", tint: AppTheme.warning)
            }

            VStack(spacing: 12) {
                ledgerRow("剩余现金", session.cash.usdText)
                ledgerRow("银行存款", session.bank.usdText)
                ledgerRow("未偿债务", session.debt.usdText)
                if let settlement = session.settlement {
                    Divider()
                    ledgerRow("库存清算（已计入）", "+\(settlement.liquidationIncome.usdText)")
                    ledgerRow("单程机票（已扣除）", "−\(settlement.ticketCost.usdText)")
                    if settlement.ticketDebt > 0 {
                        ledgerRow("机票欠款（已计入债务）", settlement.ticketDebt.usdText)
                    }
                }
                if let journey = session.journey {
                    Divider()
                    ledgerRow("累计恢复健康", "\(journey.healthRecovered) 点")
                    ledgerRow("诊所治疗支出", journey.treatmentSpending.usdText)
                }
            }
            .font(.subheadline)
            .padding(18)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 14) {
                Text(session.health <= 0 ? "未完的人生" : "尾声 / 广州")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(AppTheme.coralSoft)
                Text(session.homecomingTitle)
                    .font(.title2.weight(.bold))
                storyText(session.homecomingStory)
            }
            if session.journey == nil {
                Text("旧存档只展示已有记录，未记录的年度损耗与净赚不作推算。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("净赚含事件与奇遇奖励；健康损耗按每次实际减少累计，可能超过 100 点。回国计划为角色的故事走向。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func airport(_ code: String, city: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(code).font(.system(size: 34, weight: .black, design: .monospaced))
            Text(city).font(.caption.weight(.semibold))
        }
    }

    private func storyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.72))
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func ledgerRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
        }
    }

    private func metric(_ title: String, value: String, detail: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(tint)
            Text(value).font(.title2.weight(.bold).monospacedDigit()).minimumScaleFactor(0.5).lineLimit(1)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(15)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct EndingButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .foregroundStyle(.white)
            .background(prominent ? AppTheme.coral : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct JourneyLeaderboardView: View {
    @Bindable var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var leaders: [JourneyRecord] { JourneyRecord.rankedBest(from: store.journeyRecords) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("有人带回本钱，有人留下故事。")
                            .font(.title3.weight(.bold))
                        Text("本机全部 Profile · 每位玩家取历次最高净资产，包含提前结束的旅程。相同成绩按达成时间排列。")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("\(leaders.count) 位玩家 / \(store.journeyRecords.count) 段人生")
                            .font(.caption.monospacedDigit()).foregroundStyle(AppTheme.coralSoft)
                    }
                    .padding(.vertical, 8)
                }
                if let error = store.leaderboardError {
                    Section("暂时无法读取成绩") {
                        Text(error).font(.caption)
                        Button("重试") { store.loadLeaderboard() }
                    }
                } else if leaders.isEmpty {
                    ContentUnavailableView("还没有完成的旅程", systemImage: "list.number", description: Text("完成一局后，最高成绩与历史事件会保存在这里。"))
                } else {
                    Section("玩家最高成绩") {
                        ForEach(Array(leaders.enumerated()), id: \.element.profileID) { index, record in
                            NavigationLink {
                                PlayerJourneyHistoryView(profileID: record.profileID, records: store.journeyRecords)
                            } label: {
                                HStack(spacing: 14) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.title2.weight(.black).monospacedDigit())
                                        .foregroundStyle(index == 0 ? AppTheme.warning : .secondary)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(record.profileID.displayName).font(.headline)
                                        Text("\(record.session.isDeported ? "单程广州" : (record.session.health <= 0 ? "健康归零" : "旅程结束")) · 第 \(min(record.session.day, record.session.totalDays)) 周")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text("\(record.session.experienceCount) 种事件 · 查看全部历程 ›")
                                            .font(.caption2).foregroundStyle(AppTheme.coralSoft)
                                    }
                                    Spacer(minLength: 2)
                                    Text(record.session.netWorth.usdText)
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .foregroundStyle(record.session.netWorth > 0 ? AppTheme.positive : AppTheme.coralSoft)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                    }
                }
                Section {
                    Text("成绩与事件保存在本机，重开或删除存档槽不会删除这些记录。本榜尚未连接全球玩家服务，也不随 iCloud 存档同步。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("本机排行榜")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

private struct PlayerJourneyHistoryView: View {
    let profileID: ProfileID
    let records: [JourneyRecord]

    private var runs: [JourneyRecord] {
        records.filter { $0.profileID == profileID }.sorted(by: JourneyRecord.ranksBefore)
    }

    var body: some View {
        List {
            Section("历次成绩 · 按净资产排序") {
                ForEach(runs) { record in
                    NavigationLink {
                        JourneyEventHistoryView(record: record)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(record.id == runs.first?.id ? "个人最高" : "历史成绩")
                                    .font(.headline)
                                Spacer()
                                Text(record.session.netWorth.usdText).bold().monospacedDigit()
                            }
                            Text("\(record.session.homecomingTitle) · 健康 \(record.session.health)/100")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("\(record.completedAt.formatted(date: .abbreviated, time: .shortened)) · \(record.session.experienceCount) 种事件")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle(profileID.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JourneyEventHistoryView: View {
    let record: JourneyRecord

    var body: some View {
        List {
            Section("这一局的成绩") {
                LabeledContent("最终净资产", value: record.session.netWorth.usdText)
                LabeledContent("剩余健康", value: "\(record.session.health) / 100")
                LabeledContent("不同事件", value: "\(record.session.experienceCount) 种")
                Text(record.session.homecomingTitle).foregroundStyle(AppTheme.coralSoft)
            }
            Section("达成与遭遇 · 历史事件记录") {
                // Include legacy diary entries, which predate structured event IDs.
                ForEach(record.session.log.sorted { $0.day < $1.day }) { entry in
                    VStack(alignment: .leading, spacing: 7) {
                        Text("第 \(entry.day) 周")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.coralSoft)
                        Text(entry.title).font(.headline)
                        Text(entry.message).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("这一年的故事")
        .navigationBarTitleDisplayMode(.inline)
    }
}
