import Foundation

enum AdventureProduct: String, CaseIterable, Identifiable, Sendable {
    case vietnamGirlfriend = "com.graymongooseus.SurviveInLA.adventure.vietnam"
    case convenienceScratchCard = "com.graymongooseus.SurviveInLA.adventure.lottery"
    case anonymousBroker = "com.graymongooseus.SurviveInLA.adventure.options"
    case sanGabrielGarageSale = "com.graymongooseus.SurviveInLA.adventure.watch"

    var id: String { rawValue }

    var sequenceLabel: String {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return String(format: "%02d", index + 1)
    }

    var title: String {
        switch self {
        case .vietnamGirlfriend: "越南女朋友雪中送炭"
        case .convenienceScratchCard: "便利店乐透刮刮卡"
        case .anonymousBroker: "手机发现匿名券商"
        case .sanGabrielGarageSale: "圣盖博车库拍卖"
        }
    }

    var storeSummary: String {
        switch self {
        case .vietnamGirlfriend: "她留下一个信封便不知去向，里面是 $3,000 支票"
        case .convenienceScratchCard: "便利店随手刮一张，奖金竟是 $6,000"
        case .anonymousBroker: "高人隔空指点，末日期权撞运赚 $18,000"
        case .sanGabrielGarageSale: "五美元淘到旧表，转手净赚 $36,000"
        }
    }

    var eventTitle: String {
        switch self {
        case .vietnamGirlfriend: "那只没有回音的信封"
        case .convenienceScratchCard: "雨夜里刮开的最后一格"
        case .anonymousBroker: "凌晨四点，手机突然亮了"
        case .sanGabrielGarageSale: "五美元旧表里的秘密"
        }
    }

    var narrative: String {
        switch self {
        case .vietnamGirlfriend:
            """
            洛杉矶少见地下起了冷雨。你刚丢掉一份零工，房租催缴单压在桌角，银行账户里的数字已经不够撑到周末。你不敢告诉任何人，只能照常去小西贡见她，假装一切都还过得去。

            她一眼就看穿了。临走前，她把一个写着你名字的信封塞进你手里，只说：“回家以后再打开。”你想追问，她却已经走进雨幕。第二天，她的电话停机，住处也退了租，所有消息都没有回音。

            信封里是一张 3,000 美元的支票，还有一张很短的纸条。她瞒着父母，把自己攒下的钱借给你，只希望你先把眼前的难关熬过去。纸条最后写着：不要找我，也不必等我。

            支票到账，欠下的房租终于补齐。你度过了最冷的那一周，却也明白，这场感情已经走到了尽头。
            """
        case .convenienceScratchCard:
            """
            深夜的雨把霓虹灯揉成一片。你走进街角便利店，本来只想买瓶水和一份打折三明治。结账时，口袋里刚好剩下几枚硬币，收银台旁那张乐透刮刮卡像是在等你。

            你坐到窗边，用硬币慢慢刮开银色涂层。前几格毫无动静，直到最后一个数字出现——它和中奖号码完全相同。你盯着奖金栏看了半分钟，又请店员核对了三遍：6,000 美元，一分不少。

            店员笑着递来兑奖说明，门外一辆公交车溅起水花。你把卡片紧紧夹进钱包，连那份三明治都突然变得格外香。

            几天后，奖金到账。那张原本只值几美元的纸片，替你买来了几个月喘息的时间。
            """
        case .anonymousBroker:
            """
            凌晨四点，你被手机的震动惊醒。屏幕上多了一个从未见过的券商应用，图标没有名字，账户里却躺着一笔来源不明的可用资金。紧接着，一位自称“高人”的陌生人发来一句话：买下今天到期的看涨期权，开盘后别眨眼。

            你看不懂那些希腊字母，也不知道对方是谁。行情开盘后先是急跌，账户几乎归零；就在你准备认赔时，价格突然掉头。绿色数字像失控的电梯，一层接一层向上冲。

            午后，那位高人只发来一个“卖”字。你按下确认，应用随即退出登录，再也无法打开。几分钟后，18,000 美元已经转进你的游戏存款，交易记录却只剩下一串星号。

            你不知道这是运气、恶作剧，还是一次永远不会再来的机会。至少今天，幸运站在了你这一边。
            """
        case .sanGabrielGarageSale:
            """
            圣盖博一个晴朗的周六，你在住宅区的车库拍卖间闲逛。旧唱片、餐具和褪色相框堆满折叠桌。角落的鞋盒里压着一块停走的机械表，表面满是划痕，标价只有五美元。

            卖家说那是祖父留下的旧物，搬家时没人愿意带走。你喜欢它沉甸甸的手感，便付了钱。回家擦去表背的污渍后，一枚几乎看不清的工坊印记露了出来。

            修表师看到照片后立刻让你带实物过去。原来它出自一个早已停产的小型瑞士工坊，同批次存世极少。消息传到收藏圈，当晚便有人从橙县赶来验货。

            几轮报价后，你屏住呼吸签下成交单。扣除修复和佣金，这块五美元买来的旧表为你净赚 36,000 美元。离开时，秒针刚好重新开始走动。
            """
        }
    }

    var cashDelta: Int {
        switch self {
        case .vietnamGirlfriend: 3_000
        case .convenienceScratchCard: 6_000
        case .anonymousBroker: 18_000
        case .sanGabrielGarageSale: 36_000
        }
    }

    var fallbackPrice: String {
        switch self {
        case .vietnamGirlfriend: "$1.99"
        case .convenienceScratchCard: "$2.99"
        case .anonymousBroker: "$5.99"
        case .sanGabrielGarageSale: "$9.99"
        }
    }

    var imageName: String {
        switch self {
        case .vietnamGirlfriend: "AdventureVietnam"
        case .convenienceScratchCard: "AdventureLottery"
        case .anonymousBroker: "AdventureOptions"
        case .sanGabrielGarageSale: "AdventureWatch"
        }
    }

    var resultLabel: String {
        "+\(cashDelta.usdText)"
    }

    var accessibilitySummary: String {
        switch self {
        case .vietnamGirlfriend: "小西贡夕阳下，你打开她留下的信封，里面是一张三千美元的支票，她的身影已消失在街头"
        case .convenienceScratchCard: "雨夜便利店外，你刮开乐透刮刮卡并发现六千美元奖金"
        case .anonymousBroker: "洛杉矶公寓里，你看着手机券商账户意外上涨一万八千美元"
        case .sanGabrielGarageSale: "圣盖博车库拍卖上，你在阳光下端详一块旧机械表"
        }
    }
}
