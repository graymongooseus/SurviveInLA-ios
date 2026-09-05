import Foundation

enum AdventureProduct: String, CaseIterable, Identifiable, Sendable {
    case vietnamGirlfriend = "com.graymongooseus.SurviveInLA.adventure.vietnam"
    case lotteryWin = "com.graymongooseus.SurviveInLA.adventure.lottery"
    case optionsWindfall = "com.graymongooseus.SurviveInLA.adventure.options"
    case garageSaleWatch = "com.graymongooseus.SurviveInLA.adventure.watch"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vietnamGirlfriend: "越南女朋友"
        case .lotteryWin: "CVS 六合彩"
        case .optionsWindfall: "末日期权"
        case .garageSaleWatch: "车库拍卖古董表"
        }
    }

    var storeSummary: String {
        switch self {
        case .vietnamGirlfriend: "借她 $3,000 后，她从你的世界消失"
        case .lotteryWin: "随手买一张，意外中奖 $6,000"
        case .optionsWindfall: "高人指点开户，撞狗运赚 $18,000"
        case .garageSaleWatch: "不起眼的旧表，转手净赚 $36,000"
        }
    }

    var eventTitle: String {
        switch self {
        case .vietnamGirlfriend: "她说只是借几天"
        case .lotteryWin: "今晚，号码全对上了"
        case .optionsWindfall: "高人只说了四个字：末日期权"
        case .garageSaleWatch: "五美元的旧表，藏着一笔横财"
        }
    }

    var narrative: String {
        switch self {
        case .vietnamGirlfriend:
            "你在小西贡认识了一位越南姑娘。她说家里临时有事，向你借了 3,000 美元，答应下周就还。第二天，消息不回，电话停机，连常去的粉店也没人再见过她。洛城的晚霞很美，你的账户却少了一大截。"
        case .lotteryWin:
            "你去 CVS 买水，结账前随手添了一张六合彩。深夜核对号码时，你从第一位看到最后一位，又从最后一位看回第一位。不是幻觉——扣完税费前，你中了 6,000 美元。"
        case .optionsWindfall:
            "一位高人看了你一眼，让你开个 Robinhood 账户，买进本周到期的末日期权。你根本没看懂希腊字母，只凭一句“会涨”按下确认。市场剧烈波动，账户数字一路乱蹦，收盘时竟多出 18,000 美元。"
        case .garageSaleWatch:
            "圣盖博周末的车库拍卖里，你从一盘旧杂物中挑出一块不起眼的机械表。摊主只收了五美元。几天后，识货的收藏家给出报价；你屏住呼吸成交，净赚 36,000 美元。"
        }
    }

    var cashDelta: Int {
        switch self {
        case .vietnamGirlfriend: -3_000
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
        case .vietnamGirlfriend: "小西贡街头，她拖着行李离开，你手里只剩空信封"
        case .lotteryWin: "雨夜药房外，你举着彩票确认中奖号码"
        case .optionsWindfall: "洛杉矶公寓里，交易屏幕显示意外上涨"
        case .garageSaleWatch: "圣盖博车库拍卖上，你在阳光下端详一块旧表"
        }
    }
}
