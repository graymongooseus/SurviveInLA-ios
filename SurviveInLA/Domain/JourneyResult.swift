import Foundation

struct JourneyStatistics: Codable, Sendable {
    var startingNetWorth: Int
    var startingHealth: Int
    var healthLost = 0
    var healthRecovered = 0
    var treatmentSpending = 0
    var visitedDistricts: Set<District.ID>
    var housingSpending: Int? = nil
    var vehicleSpending: Int? = nil
    var drivingIncome: Int? = nil
    var keyChoices: [String]? = nil
    var dreamInvestmentSpending: Int? = nil
}

struct JourneySettlement: Codable, Sendable {
    static let airfare = 500
    let liquidationIncome: Int
    let ticketCost: Int
    let ticketDebt: Int
}

/// An immutable completed run. The first diary entry identifies old saves as well as new ones.
struct JourneyRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let profileID: ProfileID
    let completedAt: Date
    let session: GameSession

    init?(snapshot: GameSnapshot) {
        guard snapshot.session.isFinished,
              let firstEntry = snapshot.session.log.last(where: { $0.title == "抵达丁胖子广场" })
                ?? snapshot.session.log.min(by: { $0.day < $1.day }) else { return nil }
        id = firstEntry.id
        profileID = snapshot.profileID
        completedAt = snapshot.updatedAt
        session = snapshot.session
    }

    static func rankedBest(from records: [JourneyRecord]) -> [JourneyRecord] {
        Dictionary(grouping: records, by: \.profileID).values.compactMap { runs in
            runs.sorted(by: ranksBefore).first
        }.sorted(by: ranksBefore)
    }

    static func ranksBefore(_ lhs: JourneyRecord, _ rhs: JourneyRecord) -> Bool {
        if lhs.session.netWorth != rhs.session.netWorth {
            return lhs.session.netWorth > rhs.session.netWorth
        }
        if lhs.completedAt != rhs.completedAt { return lhs.completedAt < rhs.completedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}


/// Shared copy keeps the ending screen, epilogue and archived event in the same story.
enum RootedEndingStory {
    static let title = "此心安处，是吾乡"
    static let subtitle = "产业有了起色，生活有了同行的人。"
    static let recordSummary = "你投资的物业开始带来稳定收入，也在共同经营与相互照顾中找到了人生另一半。在这条故事线里，你的居留问题得到妥善解决；第 52 周没有遣返，也没有回程机票。你留在洛杉矶，开始两个人的新生活。"
    static let chapters = [
        "第 52 周的一个清晨，你被钥匙开门的声音叫醒。你还是下意识绷紧了肩膀，门外却传来一句熟悉的话：『早餐买回来了，今天别又空着肚子出门。』桌上没有飞往广州的单程票，只有两杯还冒着热气的咖啡。",
        "这一年，你终于把钱投进了真正能够经营的产业。那笔物业投资，起初意味着一页页看不懂的合同、跑不完的手续，还有维修和空置带来的焦虑。你学着问清费用、留够周转金，把每一笔支出记下来。后来，租金按时到账，经营渐渐稳定。它没有让你一夜暴富，却给了你一份可以认真安排的明天。",
        "你也在这些忙碌的日子里遇见了一个人。对方同样来到洛杉矶寻找发展，知道重新开始有多难。你们最初聊房子、聊生意，后来一起核对账目，一起等维修师傅，忙到很晚时分一份已经凉了的晚饭。对方见过你算错账时的狼狈，也听过你不愿对别人提起的担心，还是愿意留下。你慢慢明白，自己已经不再是一个人撑着。",
        "在这条故事线里，你的居留问题也终于得到妥善解决。你和对方认真谈起未来：生意做多大才合适，要给自己留多少休息的时间，什么时候一起回广州看看家人。你们都不是来拯救谁的人，只是决定把往后的日子放到一起过。第 52 周，ICE 没有上门。你留下来，既有自己的事业，也有愿意共同生活的另一半。"
    ]
    static let epilogue = "傍晚，你关掉办公室最后一盏灯，把账本收进抽屉。手机亮了一下：『到哪儿了？饭快好了。』\n\n你站在门口，看着洛杉矶一点点亮起的灯。刚来时，你总想着等赚够了钱，真正的生活才会开始。现在你才发现，它早已经藏在按时到账的收入里，藏在周末一起买菜的路上，也藏在那句再平常不过的『等你回家』里。\n\n你给广州的家人发去一张合照。消息打了又删，最后留下：『生意慢慢稳下来了。我也遇到了想一起过日子的人。别担心，我在这里有家了。』\n\n窗外的洛杉矶，仍然很大。属于你们的生活，刚刚好。\n\n五十二周的游戏结束了。你们的第五十三周，才刚刚开始。"
}

extension GameSession {
    var isDeported: Bool { settlement != nil && health > 0 && rootedEnding != true }
    var isRootedInLosAngeles: Bool { rootedEnding == true && health > 0 }
    var netGain: Int? { journey.map { netWorth - $0.startingNetWorth } }
    var historicalEvents: [GameLogEntry] {
        log.filter { $0.eventID != nil }.sorted { $0.day < $1.day }
    }
    var experienceCount: Int { Set(historicalEvents.compactMap(\.eventID)).count }

    var homecomingTitle: String {
        if isRootedInLosAngeles { return RootedEndingStory.title }
        if health <= 0 { return "先把自己找回来" }
        if netWorth <= 0 { return "行李很轻，日子还重" }
        if health < 40 { return "本钱有了，身体要慢慢还" }
        if netWorth < 10_000 { return "先站稳，再出发" }
        if netWorth < 50_000 { return "这一次，从一门小生意开始" }
        return "你终于有了选择的余地"
    }

    var homecomingStory: String {
        if isRootedInLosAngeles { return RootedEndingStory.epilogue }
        if health <= 0 {
            return "你终于倒在了一个再普通不过的日子里。手机还亮着，下一笔生意却已经和你无关。洛杉矶的这一程提前结束；账上的数字留在这里，身体没能陪你走到第五十二周。若人生还有下一次开局，记得给自己留一点喘息的时间。"
        }
        if settlement == nil {
            return "这是旧版本留下的一份成绩单。那一年的账已经封存，未曾记录的健康损耗和事件无法补写。无论数字好坏，你都曾在这座城市努力活过。"
        }
        let money: String
        if netWorth <= 0 {
            money = "算上未还的债，你还没有真正属于自己的本钱。回到广州，第一件事不是开店，而是给债主回电话，把账摊开，再找一份能按时领工资的工作。美国没有替你还清生活，但你终于不用隔着时差面对它。"
        } else if netWorth < 10_000 {
            money = "这笔钱能让你喘口气，却经不起再赌一次。你打算先租个小房间，找工作，把每月的开销写下来。第一笔按时到账的工资，也许没有美元那么好看，却能让明天踏实一点。"
        } else if netWorth < 50_000 {
            money = "你有了一笔可以安排的本钱。你想起在洛杉矶摸熟的进货、议价和记账，决定先找工作，再用小额预算试做生意。先有客人，再谈店面；先留生活费，再谈扩张。你已经知道，流水不是利润，胆子也不能当本金。"
        } else {
            money = "这笔结余让你可以缓一缓，不必在落地当天就答应第一份工作。你列出生活费、备用金和试营业预算，准备从自己懂的买卖做起。这一次，你有资格选择，但你不打算再把全部身家压在一个承诺上。"
        }
        let body = health < 40
            ? "只是搬行李时，腰背的疼提醒你：账上的钱不是这一年的全部。先休养，把身体照顾好，生意可以晚一点开始。"
            : "你把行李放下，决定今晚好好吃一顿，睡一觉。明天的事，明天清醒地做。"
        return "广州白云机场的门打开，潮湿的热风扑在脸上。手机重新连上网络，家人的消息一条接一条跳出来。你打了很久，最后只发出四个字：『我回来了。』\n\n\(money)\n\n\(body)\n\n洛杉矶没有第五十三周。广州，还有明天。"
    }
}

extension GameEvent {
    var historyID: String {
        if id.hasPrefix("work-"), let district = districtIDs?.first { return "work-\(district.rawValue)" }
        if id.hasPrefix("investment-"), let district = districtIDs?.first { return "investment-\(district.rawValue)" }
        if id.hasPrefix("pimping-") { return "work-figueroaCorridor" }
        return id
    }
}
