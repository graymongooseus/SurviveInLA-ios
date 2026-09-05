import Foundation

enum AdventureProduct: String, CaseIterable, Identifiable, Sendable {
    case vietnamGirlfriend = "com.graymongooseus.SurviveInLA.adventure.vietnam"
    case lotteryWin = "com.graymongooseus.SurviveInLA.adventure.lottery"
    case optionsWindfall = "com.graymongooseus.SurviveInLA.adventure.options"
    case garageSaleWatch = "com.graymongooseus.SurviveInLA.adventure.watch"

    var id: String { rawValue }

    var sequenceLabel: String {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return String(format: "%02d", index + 1)
    }

    var title: String {
        switch self {
        case .vietnamGirlfriend: "越南女朋友"
        case .lotteryWin: "便利店乐透刮刮卡"
        case .optionsWindfall: "末日期权"
        case .garageSaleWatch: "车库拍卖古董表"
        }
    }

    var storeSummary: String {
        switch self {
        case .vietnamGirlfriend: "她留下一个信封便不知去向，里面是 $3,000 支票"
        case .lotteryWin: "随手买一张，意外中奖 $6,000"
        case .optionsWindfall: "高人指点开户，撞狗运赚 $18,000"
        case .garageSaleWatch: "不起眼的旧表，转手净赚 $36,000"
        }
    }

    var eventTitle: String {
        switch self {
        case .vietnamGirlfriend: "打开信封，是一张 $3,000 支票"
        case .lotteryWin: "今晚，号码全对上了"
        case .optionsWindfall: "高人只说了四个字：末日期权"
        case .garageSaleWatch: "五美元的旧表，藏着一笔横财"
        }
    }

    var narrative: String {
        switch self {
        case .vietnamGirlfriend:
            "你在小西贡认识的越南女友，给了你一个信封后便不知去向。打开一看，里面是一张 3,000 美元的支票。钱到账了，但是感情到此为止。"
        case .lotteryWin:
            "你去便利店买水，结账前随手添了一张乐透刮刮卡。深夜核对卡面时，你从第一行看到最后一行，又从最后一行看回第一行。不是幻觉——扣完税费前，你中了 6,000 美元。"
        case .optionsWindfall:
            "一位高人看了你一眼，让你在手机上的某匿名券商平台开户，买进本周到期的末日期权。你根本没看懂希腊字母，只凭一句“会涨”按下确认。市场剧烈波动，账户数字一路乱蹦，收盘时竟多出 18,000 美元。"
        case .garageSaleWatch:
            "圣盖博周末的车库拍卖里，你从一盘旧杂物中挑出一块不起眼的机械表。摊主只收了五美元。几天后，识货的收藏家给出报价；你屏住呼吸成交，净赚 36,000 美元。"
        }
    }

    var cashDelta: Int {
        switch self {
        case .vietnamGirlfriend: 3_000
        case .lotteryWin: 6_000
        case .optionsWindfall: 18_000
        case .garageSaleWatch: 36_000
        }
    }

    var fallbackPrice: String {
        switch self {
        case .vietnamGirlfriend: "$1.99"
        case .lotteryWin: "$2.99"
        case .optionsWindfall: "$5.99"
        case .garageSaleWatch: "$9.99"
        }
    }

    var imageName: String {
        switch self {
        case .vietnamGirlfriend: "AdventureVietnam"
        case .lotteryWin: "AdventureLottery"
        case .optionsWindfall: "AdventureOptions"
        case .garageSaleWatch: "AdventureWatch"
        }
    }

    var resultLabel: String {
        cashDelta >= 0 ? "+\(cashDelta.usdText)" : cashDelta.usdText
    }

    var accessibilitySummary: String {
        switch self {
        case .vietnamGirlfriend: "小西贡夕阳下，你打开她留下的信封，里面是一张三千美元的支票，她的身影已消失在街头"
        case .lotteryWin: "雨夜便利店外，你举着乐透刮刮卡确认中奖"
        case .optionsWindfall: "洛杉矶公寓里，交易屏幕显示意外上涨"
        case .garageSaleWatch: "圣盖博车库拍卖上，你在阳光下端详一块旧表"
        }
    }
}
