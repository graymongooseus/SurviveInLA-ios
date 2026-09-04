import Foundation
import CoreLocation

enum GameContent {
    static let commodities: [Commodity] = [
        Commodity(id: .sneakers, name: "限量球鞋", symbol: "shoe.2.fill", basePrice: 220, minimumPrice: 80, maximumPrice: 620),
        Commodity(id: .camera, name: "二手相机", symbol: "camera.fill", basePrice: 680, minimumPrice: 260, maximumPrice: 1_650),
        Commodity(id: .vinyl, name: "黑胶唱片", symbol: "record.circle", basePrice: 48, minimumPrice: 12, maximumPrice: 180),
        Commodity(id: .concertTickets, name: "演出门票", symbol: "ticket.fill", basePrice: 135, minimumPrice: 35, maximumPrice: 480),
        Commodity(id: .vintageJacket, name: "复古夹克", symbol: "tshirt.fill", basePrice: 95, minimumPrice: 24, maximumPrice: 330),
        Commodity(id: .importedSnacks, name: "进口零食", symbol: "takeoutbag.and.cup.and.straw.fill", basePrice: 18, minimumPrice: 5, maximumPrice: 65),
        Commodity(id: .gameConsole, name: "游戏主机", symbol: "gamecontroller.fill", basePrice: 360, minimumPrice: 160, maximumPrice: 880),
        Commodity(id: .beautySet, name: "美妆套装", symbol: "sparkles", basePrice: 72, minimumPrice: 18, maximumPrice: 260),
        Commodity(id: .usedTesla, name: "二手特斯拉", symbol: "car.side.fill", basePrice: 18_000, minimumPrice: 8_000, maximumPrice: 42_000),
        Commodity(id: .smuggledVape, name: "走私电子烟", symbol: "smoke.fill", basePrice: 55, minimumPrice: 12, maximumPrice: 210)
    ]

    static let districts: [District] = [
        District(
            id: .koreatown,
            name: "韩国城",
            englishName: "Koreatown",
            coordinate: .init(latitude: 34.0578, longitude: -118.3009),
            transitHint: "Metro D Line",
            marketRole: "落脚点 · 进口零食与美妆货源",
            marketBiases: [.importedSnacks: 0.78, .beautySet: 0.84, .gameConsole: 0.94, .smuggledVape: 0.88]
        ),
        District(
            id: .pasadenaRoseBowl,
            name: "帕萨迪纳·玫瑰碗",
            englishName: "Pasadena / Rose Bowl",
            coordinate: .init(latitude: 34.1613, longitude: -118.1676),
            transitHint: "Metro A + Shuttle",
            marketRole: "跳蚤市场与赛事 · 复古品和收藏品货源",
            marketBiases: [.vinyl: 0.82, .vintageJacket: 0.84, .camera: 0.91, .concertTickets: 1.12]
        ),
        District(
            id: .figueroaCorridor,
            name: "菲格罗亚走廊",
            englishName: "Figueroa Corridor",
            coordinate: .init(latitude: 34.0180, longitude: -118.2827),
            transitHint: "Metro E Line",
            marketRole: "校园与场馆 · 零食、球鞋和门票快销",
            marketBiases: [.importedSnacks: 1.08, .sneakers: 1.10, .concertTickets: 1.14, .smuggledVape: 0.88]
        ),
        District(
            id: .hollywood,
            name: "好莱坞",
            englishName: "Hollywood",
            coordinate: .init(latitude: 34.1016, longitude: -118.3269),
            transitHint: "Metro B Line",
            marketRole: "游客与演出 · 脱口秀相机需求旺",
            marketBiases: [.concertTickets: 1.24, .camera: 1.13, .vintageJacket: 1.08, .smuggledVape: 1.20]
        ),
        District(
            id: .silverLake,
            name: "银湖",
            englishName: "Silver Lake",
            coordinate: .init(latitude: 34.0869, longitude: -118.2702),
            transitHint: "Local Bus",
            marketRole: "独立文化 · 黑胶与复古服装溢价",
            marketBiases: [.vinyl: 1.22, .vintageJacket: 1.16, .camera: 1.07]
        ),
        District(
            id: .inglewood,
            name: "英格尔伍德",
            englishName: "Inglewood",
            coordinate: .init(latitude: 33.9617, longitude: -118.3531),
            transitHint: "Metro K Line",
            marketRole: "赛事经济 · 球鞋与演出票波动大",
            marketBiases: [.sneakers: 1.19, .concertTickets: 1.18, .gameConsole: 1.04, .usedTesla: 0.86]
        ),
        District(
            id: .culverCity,
            name: "卡尔弗城",
            englishName: "Culver City",
            coordinate: .init(latitude: 34.0211, longitude: -118.3965),
            transitHint: "Metro E Line",
            marketRole: "影视科技 · 相机、主机与二手车交易活跃",
            marketBiases: [.camera: 1.16, .gameConsole: 1.12, .concertTickets: 1.05, .usedTesla: 0.91]
        ),
        District(
            id: .westwood,
            name: "西木区",
            englishName: "Westwood",
            coordinate: .init(latitude: 34.0635, longitude: -118.4455),
            transitHint: "Metro Bus",
            marketRole: "校园客群 · 主机零食容易出手",
            marketBiases: [.gameConsole: 1.17, .importedSnacks: 1.13, .concertTickets: 1.07]
        ),
        District(
            id: .venice,
            name: "威尼斯",
            englishName: "Venice",
            coordinate: .init(latitude: 33.9850, longitude: -118.4695),
            transitHint: "Big Blue Bus",
            marketRole: "海滨旅游 · 球鞋与复古服装受欢迎",
            marketBiases: [.sneakers: 1.16, .vintageJacket: 1.19, .camera: 1.10]
        ),
        District(
            id: .santaMonica,
            name: "圣塔莫尼卡",
            englishName: "Santa Monica",
            coordinate: .init(latitude: 34.0195, longitude: -118.4912),
            transitHint: "Metro E Line",
            marketRole: "高消费终点 · 多数商品售价偏高",
            marketBiases: [.sneakers: 1.15, .camera: 1.14, .beautySet: 1.20, .importedSnacks: 1.09, .usedTesla: 1.22]
        ),
        District(
            id: .dingPangZiPlaza,
            name: "丁胖子广场",
            englishName: "Ding Pang Zi Plaza",
            coordinate: .init(latitude: 34.0637, longitude: -118.1337),
            transitHint: "Metro Bus",
            marketRole: "草根华人商圈 · 零食、美妆和小商品货源",
            marketBiases: [.importedSnacks: 0.76, .beautySet: 0.86, .gameConsole: 0.94, .smuggledVape: 0.80]
        ),
        District(
            id: .sanGabriel,
            name: "圣盖博",
            englishName: "San Gabriel",
            coordinate: .init(latitude: 34.0782, longitude: -118.1021),
            transitHint: "Metro Bus",
            marketRole: "华人商业中心 · 餐饮、服务与跨境生意",
            marketBiases: [.importedSnacks: 0.82, .beautySet: 0.90, .gameConsole: 0.92, .camera: 0.96, .smuggledVape: 0.84]
        ),
        District(
            id: .rowlandHeights,
            name: "罗兰岗",
            englishName: "Rowland Heights",
            coordinate: .init(latitude: 33.9734, longitude: -117.8941),
            transitHint: "Freeway + Bus",
            marketRole: "新移民商业带 · 广场经济与夜间交易",
            marketBiases: [.importedSnacks: 0.84, .gameConsole: 0.90, .sneakers: 1.08, .usedTesla: 1.10, .smuggledVape: 0.82]
        ),
        District(
            id: .irvine,
            name: "尔湾",
            englishName: "Irvine",
            coordinate: .init(latitude: 33.6887, longitude: -117.8335),
            transitHint: "Metrolink / Car",
            marketRole: "科技与高端华人 · 特斯拉和精品溢价",
            marketBiases: [.usedTesla: 1.28, .beautySet: 1.16, .camera: 1.12, .sneakers: 1.10, .gameConsole: 1.08]
        ),
        District(
            id: .littleSaigon,
            name: "威斯敏斯特·小西贡",
            englishName: "Little Saigon, Westminster",
            coordinate: .init(latitude: 33.7432, longitude: -117.9685),
            transitHint: "OC Bus / Car",
            marketRole: "越南与华裔移民商圈 · 餐饮、金行和家族生意",
            marketBiases: [.importedSnacks: 0.79, .beautySet: 0.88, .smuggledVape: 0.78, .vintageJacket: 0.93]
        )
    ]

    static let jobs: [JobOpportunity] = [
        JobOpportunity(districtID: .dingPangZiPlaza, title: "广场餐馆帮工", detail: "洗菜、打包、送外卖，现金当天结。", wage: 320, healthCost: 4),
        JobOpportunity(districtID: .sanGabriel, title: "华人超市理货", detail: "凌晨补货，忙完正好赶上早市。", wage: 380, healthCost: 5),
        JobOpportunity(districtID: .rowlandHeights, title: "夜市摊位帮手", detail: "搭棚、收摊，再帮老板看一会儿货。", wage: 420, healthCost: 5),
        JobOpportunity(districtID: .irvine, title: "科技展会临工", detail: "替参展公司布置展台、搬运设备。", wage: 560, healthCost: 5),
        JobOpportunity(districtID: .littleSaigon, title: "家族餐馆外场", detail: "午市翻台快，小费全靠手脚麻利。", wage: 360, healthCost: 4),
        JobOpportunity(districtID: .koreatown, title: "韩餐馆夜班", detail: "深夜客人多，下班时天已经快亮了。", wage: 370, healthCost: 5),
        JobOpportunity(districtID: .pasadenaRoseBowl, title: "跳蚤市场搭摊", detail: "天不亮就进场，帮摊主搬货摆货。", wage: 390, healthCost: 5),
        JobOpportunity(districtID: .figueroaCorridor, title: "场馆散场清理", detail: "比赛结束后清场，活累但结账干脆。", wage: 410, healthCost: 6),
        JobOpportunity(districtID: .hollywood, title: "片场临时群演", detail: "等候时间比上镜时间长得多。", wage: 480, healthCost: 4),
        JobOpportunity(districtID: .silverLake, title: "独立咖啡店代班", detail: "会拉花不重要，先记住熟客的名字。", wage: 340, healthCost: 3),
        JobOpportunity(districtID: .inglewood, title: "赛事场馆装卸", detail: "赶在观众入场前把设备全部归位。", wage: 460, healthCost: 6),
        JobOpportunity(districtID: .culverCity, title: "剧组制片助理", detail: "送文件、买咖啡、盯器材，什么都做。", wage: 520, healthCost: 6),
        JobOpportunity(districtID: .westwood, title: "校园跑腿配送", detail: "订单不大，但宿舍楼之间来回很费腿。", wage: 350, healthCost: 4),
        JobOpportunity(districtID: .venice, title: "海边租赁摊帮工", detail: "搬单车、擦滑板，还要回答游客问题。", wage: 390, healthCost: 5),
        JobOpportunity(districtID: .santaMonica, title: "酒店宴会临工", detail: "换场速度快，结束后能拿到一笔小费。", wage: 450, healthCost: 5)
    ]

    static let investments: [InvestmentOpportunity] = [
        InvestmentOpportunity(districtID: .dingPangZiPlaza, title: "广场团购拼单", detail: "几家小店一起进一批节庆礼盒。", risk: .low, minimumInvestment: 100),
        InvestmentOpportunity(districtID: .sanGabriel, title: "新餐馆试营业", detail: "朋友缺最后一笔食材周转金。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .rowlandHeights, title: "夜市快闪摊", detail: "网红摊主要押一周末的人流。", risk: .high, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .irvine, title: "华人创业应用", detail: "一支小团队正在抢发布前的窗口期。", risk: .high, minimumInvestment: 500),
        InvestmentOpportunity(districtID: .littleSaigon, title: "家族金行代购", detail: "短单周转快，但金价一天一个样。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .koreatown, title: "美妆直播拼货", detail: "主播准备测试一批新的本地货盘。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .pasadenaRoseBowl, title: "古董摊联合收货", detail: "几位摊主准备吃下一整仓旧物。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .figueroaCorridor, title: "比赛日零食摊", detail: "学生社团押注本周末的主场人流。", risk: .low, minimumInvestment: 100),
        InvestmentOpportunity(districtID: .hollywood, title: "独立短片众筹", detail: "导演说只差这一周就能开机。", risk: .high, minimumInvestment: 300),
        InvestmentOpportunity(districtID: .silverLake, title: "黑胶再版预购", detail: "唱片店想小批量压一张绝版专辑。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .inglewood, title: "赛事停车联营", detail: "车位已经谈妥，只等比赛日客流。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .culverCity, title: "独立游戏原型", detail: "三个人的团队需要撑过最后一个冲刺周。", risk: .high, minimumInvestment: 300),
        InvestmentOpportunity(districtID: .westwood, title: "校园二手书周转", detail: "开学季需求稳定，利润不算惊人。", risk: .low, minimumInvestment: 100),
        InvestmentOpportunity(districtID: .venice, title: "街头品牌快闪", detail: "主理人把全部希望押在周末天气上。", risk: .high, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .santaMonica, title: "旅游纪念品补货", detail: "码头商店为周末游客提前备货。", risk: .low, minimumInvestment: 200)
    ]

    static let marketEvents: [GameEvent] = [
        GameEvent(
            id: "studio-camera-rush", kind: .opportunity, group: .market,
            title: "片场临时缺设备", message: "附近剧组临时补拍，二手相机被迅速扫货，本周价格明显上涨。",
            affectedCommodityID: .camera, marketPriceMultiplier: 1.90,
            districtIDs: [.hollywood, .culverCity]
        ),
        GameEvent(
            id: "camera-estate-sale", kind: .setback, group: .market,
            title: "相机集中入市", message: "几场 estate sale 同时放货，二手相机供应突然增加。",
            affectedCommodityID: .camera, marketPriceMultiplier: 0.55,
            districtIDs: [.culverCity, .silverLake, .santaMonica]
        ),
        GameEvent(
            id: "headline-ticket-rush", kind: .opportunity, group: .market,
            title: "热门演出开票", message: "热门演出公布嘉宾名单，附近的演出门票需求猛增。",
            affectedCommodityID: .concertTickets, marketPriceMultiplier: 2.40,
            districtIDs: [.hollywood, .inglewood]
        ),
        GameEvent(
            id: "extra-show-added", kind: .setback, group: .market,
            title: "临时宣布加场", message: "主办方增加场次，二级市场上的演出门票价格回落。",
            affectedCommodityID: .concertTickets, marketPriceMultiplier: 0.45,
            districtIDs: [.hollywood, .inglewood]
        ),
        GameEvent(
            id: "vinyl-pop-up", kind: .opportunity, group: .market,
            title: "黑胶快闪市集", message: "独立唱片快闪活动带来人流，黑胶唱片突然变得抢手。",
            affectedCommodityID: .vinyl, marketPriceMultiplier: 1.85,
            districtIDs: [.silverLake, .pasadenaRoseBowl]
        ),
        GameEvent(
            id: "vinyl-reissue", kind: .setback, group: .market,
            title: "经典专辑再版", message: "唱片公司补发再版，原本稀缺的黑胶唱片价格下跌。",
            affectedCommodityID: .vinyl, marketPriceMultiplier: 0.55,
            districtIDs: [.silverLake, .pasadenaRoseBowl]
        ),
        GameEvent(
            id: "vintage-stylist-rush", kind: .opportunity, group: .market,
            title: "造型师集中扫货", message: "颁奖季和拍摄需求碰在一起，复古夹克被造型师批量收走。",
            affectedCommodityID: .vintageJacket, marketPriceMultiplier: 2.05,
            districtIDs: [.pasadenaRoseBowl, .hollywood, .venice]
        ),
        GameEvent(
            id: "vintage-rack-sale", kind: .setback, group: .market,
            title: "跳蚤市场收摊", message: "摊主赶着收摊，大批复古夹克折价流入市场。",
            affectedCommodityID: .vintageJacket, marketPriceMultiplier: 0.50,
            districtIDs: [.pasadenaRoseBowl, .dingPangZiPlaza]
        ),
        GameEvent(
            id: "beauty-viral", kind: .opportunity, group: .market,
            title: "美妆视频走红", message: "本地创作者的试妆视频突然走红，美妆套装需求上升。",
            affectedCommodityID: .beautySet, marketPriceMultiplier: 2.00,
            districtIDs: [.koreatown, .santaMonica, .irvine, .dingPangZiPlaza]
        ),
        GameEvent(
            id: "beauty-overstock", kind: .setback, group: .market,
            title: "批发商清库存", message: "批发商集中清理旧包装，美妆套装售价被压低。",
            affectedCommodityID: .beautySet, marketPriceMultiplier: 0.50,
            districtIDs: [.koreatown, .dingPangZiPlaza, .littleSaigon]
        ),
        GameEvent(
            id: "campus-snack-rush", kind: .opportunity, group: .market,
            title: "校园团购", message: "学生社团组织团购，进口零食很快售罄。",
            affectedCommodityID: .importedSnacks, marketPriceMultiplier: 1.75,
            districtIDs: [.westwood, .koreatown, .figueroaCorridor, .irvine]
        ),
        GameEvent(
            id: "community-leftovers", kind: .opportunity, group: .market,
            title: "社区活动收尾", message: "你帮忙收拾社区活动，组织者把未拆封的进口零食送给了你。",
            reputationDelta: 1, affectedCommodityID: .importedSnacks, grantedQuantity: 6,
            districtIDs: [.figueroaCorridor, .koreatown, .westwood, .sanGabriel, .littleSaigon]
        ),
        GameEvent(
            id: "console-shortage", kind: .opportunity, group: .market,
            title: "游戏主机缺货", message: "新游戏发布带动需求，附近商店的游戏主机很快卖空。",
            affectedCommodityID: .gameConsole, marketPriceMultiplier: 2.10,
            districtIDs: [.culverCity, .westwood]
        ),
        GameEvent(
            id: "console-refresh", kind: .setback, group: .market,
            title: "换代消息公布", message: "厂商公布更新版本，现有游戏主机的二手价格回落。",
            affectedCommodityID: .gameConsole, marketPriceMultiplier: 0.55,
            districtIDs: [.culverCity, .westwood]
        ),
        GameEvent(
            id: "sneaker-game-day", kind: .opportunity, group: .market,
            title: "比赛日球鞋热", message: "比赛和游客人流同时到来，限量球鞋的询价不断。",
            affectedCommodityID: .sneakers, marketPriceMultiplier: 2.15,
            districtIDs: [.inglewood, .venice, .santaMonica]
        ),
        GameEvent(
            id: "sneaker-restock", kind: .setback, group: .market,
            title: "门店集中补货", message: "多家门店同时补货，限量球鞋的转售价迅速回落。",
            affectedCommodityID: .sneakers, marketPriceMultiplier: 0.55,
            districtIDs: [.figueroaCorridor, .venice, .rowlandHeights]
        ),
        GameEvent(
            id: "used-ev-demand", kind: .opportunity, group: .market,
            title: "二手电动车抢手", message: "通勤成本成为热门话题，车况透明的二手特斯拉更受关注。",
            affectedCommodityID: .usedTesla, marketPriceMultiplier: 1.45,
            districtIDs: [.santaMonica, .culverCity, .inglewood, .irvine]
        ),
        GameEvent(
            id: "vape-enforcement", kind: .opportunity, group: .market,
            title: "无证货源收紧", message: "执法检查让无证电子烟货源收缩，黑市报价短暂上升。",
            affectedCommodityID: .smuggledVape, marketPriceMultiplier: 2.50
        ),
        GameEvent(
            id: "ding-pang-zi-gift-box-rush", kind: .opportunity, group: .market,
            title: "节庆礼盒断货", message: "丁胖子广场的商家赶着补节庆礼盒，进口零食很快被扫空。",
            affectedCommodityID: .importedSnacks, marketPriceMultiplier: 1.85,
            districtIDs: [.dingPangZiPlaza]
        ),
        GameEvent(
            id: "san-gabriel-wedding-beauty-rush", kind: .opportunity, group: .market,
            title: "婚宴季美妆抢货", message: "圣盖博周末婚宴排期密集，化妆师开始集中采购美妆套装。",
            affectedCommodityID: .beautySet, marketPriceMultiplier: 1.80,
            districtIDs: [.sanGabriel]
        ),
        GameEvent(
            id: "rowland-colima-sneakers", kind: .opportunity, group: .market,
            title: "商圈球鞋联名", message: "科利马路商圈出现限量联名款，附近球鞋询价突然升高。",
            affectedCommodityID: .sneakers, marketPriceMultiplier: 1.95,
            districtIDs: [.rowlandHeights]
        ),
        GameEvent(
            id: "irvine-tech-ev-turnover", kind: .setback, group: .market,
            title: "科技园换车潮", message: "科技园区一批通勤车集中进入二手市场，二手特斯拉价格回落。",
            affectedCommodityID: .usedTesla, marketPriceMultiplier: 0.68,
            districtIDs: [.irvine]
        ),
        GameEvent(
            id: "little-saigon-tet-gift-rush", kind: .opportunity, group: .market,
            title: "Tết 礼盒抢购", message: "小西贡商圈开始为越南新年备货，进口零食礼盒需求快速上升。",
            affectedCommodityID: .importedSnacks, marketPriceMultiplier: 1.90,
            districtIDs: [.littleSaigon]
        )
    ]

    static let healthEvents: [GameEvent] = [
        GameEvent(
            id: "extreme-heat", kind: .health, group: .health,
            title: "高温警报", message: "内陆街区气温持续升高，你买了水并提前结束了户外奔波。",
            cashDelta: -12, healthDelta: -8,
            districtIDs: [.koreatown, .pasadenaRoseBowl, .figueroaCorridor, .hollywood, .silverLake, .inglewood, .culverCity, .westwood, .dingPangZiPlaza, .sanGabriel, .rowlandHeights, .irvine, .littleSaigon]
        ),
        GameEvent(
            id: "wildfire-smoke", kind: .health, group: .health,
            title: "山火烟尘", message: "风把远处山火烟尘带进城区，你买了 N95 并减少户外活动。",
            cashDelta: -18, healthDelta: -7
        ),
        GameEvent(
            id: "unhealthy-air", kind: .health, group: .health,
            title: "空气质量变差", message: "AQI 升高，长时间在室外跑货让你喉咙不舒服。",
            cashDelta: -10, healthDelta: -4
        ),
        GameEvent(
            id: "metro-hard-stop", kind: .health, group: .health,
            title: "列车急停", message: "Metro 列车突然制动，你扶得及时，但手腕还是扭了一下。",
            healthDelta: -3
        ),
        GameEvent(
            id: "freeway-gridlock", kind: .health, group: .health,
            title: "高速堵死", message: "事故让通勤时间翻倍，你又累又饿，只能买点东西垫肚子。",
            cashDelta: -24, healthDelta: -2
        ),
        GameEvent(
            id: "hillside-dehydration", kind: .health, group: .health,
            title: "山坡脱水", message: "你抄近路翻过一段陡坡，日晒和缺水让身体吃不消。",
            cashDelta: -8, healthDelta: -6,
            districtIDs: [.hollywood, .silverLake, .pasadenaRoseBowl]
        ),
        GameEvent(
            id: "cooler-failure", kind: .health, group: .health,
            title: "冷藏箱断电", message: "露天活动的冷藏箱断了电，你吃坏肚子并买了药。",
            cashDelta: -45, healthDelta: -7,
            districtIDs: [.pasadenaRoseBowl, .figueroaCorridor, .hollywood, .inglewood]
        ),
        GameEvent(
            id: "bike-path-fall", kind: .health, group: .health,
            title: "自行车道摔倒", message: "你在拥挤的自行车道上避让行人，擦伤后买了简单的急救用品。",
            cashDelta: -35, healthDelta: -6,
            districtIDs: [.venice, .santaMonica, .culverCity]
        ),
        GameEvent(
            id: "rip-current", kind: .health, group: .health,
            title: "离岸流", message: "海边突然出现离岸流，你听从救生员指示脱险，但体力消耗很大。",
            healthDelta: -12,
            districtIDs: [.venice, .santaMonica]
        ),
        GameEvent(
            id: "earthquake-jolt", kind: .health, group: .health,
            title: "地震晃动", message: "手机刚收到预警，货架就开始摇晃；你及时趴下掩护，但还是受了轻伤。",
            cashDelta: -25, healthDelta: -5
        ),
        GameEvent(
            id: "sleep-debt", kind: .health, group: .health,
            title: "连续缺觉", message: "赶早市又盯夜盘，你靠咖啡硬撑了一天。",
            cashDelta: -7, healthDelta: -4
        ),
        GameEvent(
            id: "seasonal-flu", kind: .health, group: .health,
            title: "季节性流感", message: "你开始发冷咳嗽，只能买药并放慢节奏。",
            cashDelta: -28, healthDelta: -5
        ),
        GameEvent(
            id: "ding-pang-zi-kitchen-smoke", kind: .health, group: .health,
            title: "后厨油烟呛到", message: "广场餐馆后厨正值高峰，油烟和热气让你一阵头晕。",
            cashDelta: -18, healthDelta: -4,
            districtIDs: [.dingPangZiPlaza]
        ),
        GameEvent(
            id: "san-gabriel-kitchen-burn", kind: .health, group: .health,
            title: "深夜厨房烫伤", message: "圣盖博餐馆夜班忙乱，你端热汤时烫伤了手，只能去买药处理。",
            cashDelta: -45, healthDelta: -6,
            districtIDs: [.sanGabriel]
        ),
        GameEvent(
            id: "rowland-market-back-strain", kind: .health, group: .health,
            title: "闭店搬货腰伤", message: "科利马路商铺闭店后你连续搬货，腰背开始隐隐作痛。",
            cashDelta: -25, healthDelta: -5,
            districtIDs: [.rowlandHeights]
        ),
        GameEvent(
            id: "irvine-long-commute-fatigue", kind: .health, group: .health,
            title: "长途通勤透支", message: "往返尔湾的长途通勤耗掉大半天，你又付了路费又累得够呛。",
            cashDelta: -30, healthDelta: -6,
            districtIDs: [.irvine]
        ),
        GameEvent(
            id: "little-saigon-kitchen-slip", kind: .health, group: .health,
            title: "湿滑后厨摔倒", message: "小西贡餐馆后厨地面湿滑，你摔了一跤并买了简单的急救用品。",
            cashDelta: -35, healthDelta: -5,
            districtIDs: [.littleSaigon]
        )
    ]

    static let moneyEvents: [GameEvent] = [
        GameEvent(
            id: "street-cleaning-ticket", kind: .setback, group: .money,
            title: "街道清扫罚单", message: "你没看清街道清扫时段，回来时雨刷下已经夹着罚单。",
            cashDelta: -75
        ),
        GameEvent(
            id: "temporary-no-parking-tow", kind: .setback, group: .money,
            title: "临时禁停拖车", message: "拍摄和道路作业临时占用了路边车位，你付费把车领了回来。",
            cashDelta: -310,
            districtIDs: [.hollywood, .culverCity, .figueroaCorridor, .pasadenaRoseBowl]
        ),
        GameEvent(
            id: "pothole-flat", kind: .setback, group: .money,
            title: "坑洞爆胎", message: "夜里没看清路面坑洞，只能临时更换轮胎。",
            cashDelta: -165,
            districtIDs: [.figueroaCorridor, .koreatown, .inglewood, .dingPangZiPlaza, .rowlandHeights]
        ),
        GameEvent(
            id: "phone-screen-repair", kind: .setback, group: .money,
            title: "手机屏幕摔裂", message: "导航、收款和查价都离不开手机，你只能先换屏。",
            cashDelta: -120
        ),
        GameEvent(
            id: "metro-delay-rideshare", kind: .setback, group: .money,
            title: "轨道服务延误", message: "Metro 服务延误，为了赶上交易时间，你改叫了网约车。",
            cashDelta: -48,
            districtIDs: [.koreatown, .figueroaCorridor, .hollywood, .culverCity, .westwood, .santaMonica, .pasadenaRoseBowl]
        ),
        GameEvent(
            id: "beach-parking", kind: .setback, group: .money,
            title: "海边停车超时", message: "交易比预期久，停车计时已经超时。",
            cashDelta: -70,
            districtIDs: [.venice, .santaMonica]
        ),
        GameEvent(
            id: "vending-compliance", kind: .reputation, group: .money,
            title: "补齐摆摊手续", message: "你为临时摊位补办手续、准备清洁用品，花了钱但做事更正规。",
            cashDelta: -85, reputationDelta: 2,
            districtIDs: [.figueroaCorridor, .hollywood, .venice, .pasadenaRoseBowl, .dingPangZiPlaza, .littleSaigon]
        ),
        GameEvent(
            id: "ding-pang-zi-referral-shift", kind: .opportunity, group: .money,
            title: "熟客介绍短工", message: "广场熟客把你介绍给隔壁店救急，忙完当天就拿到了现金。",
            cashDelta: 110, reputationDelta: 1,
            districtIDs: [.dingPangZiPlaza]
        ),
        GameEvent(
            id: "san-gabriel-repaid-tab", kind: .opportunity, group: .money,
            title: "熟客补回欠款", message: "圣盖博的一位熟客终于把上次赊下的货款和谢礼一起送来。",
            cashDelta: 140, reputationDelta: 1,
            districtIDs: [.sanGabriel]
        ),
        GameEvent(
            id: "rowland-carpool-delivery", kind: .opportunity, group: .money,
            title: "拼车送货赚外快", message: "你顺路替几家罗兰岗商铺送货，赚到运费，但来回搬货有些累。",
            cashDelta: 125, healthDelta: -2,
            districtIDs: [.rowlandHeights]
        ),
        GameEvent(
            id: "irvine-expo-overtime", kind: .opportunity, group: .money,
            title: "科技展会加班费", message: "尔湾科技展临时延长布展时间，主办方给你补了一笔加班费。",
            cashDelta: 180, reputationDelta: 1,
            districtIDs: [.irvine]
        ),
        GameEvent(
            id: "little-saigon-wedding-tips", kind: .opportunity, group: .money,
            title: "婚宴帮工小费", message: "你在小西贡婚宴上临时帮忙传菜，散场后收到了一笔小费。",
            cashDelta: 130, reputationDelta: 1,
            districtIDs: [.littleSaigon]
        )
    ]

    static let events = marketEvents + healthEvents + moneyEvents

    static func commodity(_ id: Commodity.ID) -> Commodity {
        commodities.first(where: { $0.id == id })!
    }

    static func district(_ id: District.ID) -> District {
        districts.first(where: { $0.id == id })!
    }

    static func job(in districtID: District.ID) -> JobOpportunity {
        jobs.first(where: { $0.districtID == districtID })!
    }

    static func investment(in districtID: District.ID) -> InvestmentOpportunity {
        investments.first(where: { $0.districtID == districtID })!
    }
}
