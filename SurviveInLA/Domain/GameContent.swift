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
            id: .fashionDistrict,
            name: "时尚区",
            englishName: "Fashion District",
            coordinate: .init(latitude: 34.0364, longitude: -118.2540),
            transitHint: "Metro + Bus",
            marketRole: "批发源头 · 服装与美妆走量",
            marketBiases: [.vintageJacket: 0.76, .beautySet: 0.88, .sneakers: 0.93]
        ),
        District(
            id: .boyleHeights,
            name: "博伊尔高地",
            englishName: "Boyle Heights",
            coordinate: .init(latitude: 34.0437, longitude: -118.2104),
            transitHint: "Metro E Line",
            marketRole: "社区集市 · 唱片与日用品价格亲民",
            marketBiases: [.vinyl: 0.80, .vintageJacket: 0.88, .importedSnacks: 0.91, .smuggledVape: 0.82]
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
        )
    ]

    static let marketEvents: [GameEvent] = [
        GameEvent(
            id: "studio-camera-rush", kind: .opportunity, group: .market,
            title: "片场临时缺设备", message: "附近剧组临时补拍，二手相机被迅速扫货，今天价格明显上涨。",
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
            districtIDs: [.silverLake, .boyleHeights]
        ),
        GameEvent(
            id: "vinyl-reissue", kind: .setback, group: .market,
            title: "经典专辑再版", message: "唱片公司补发再版，原本稀缺的黑胶唱片价格下跌。",
            affectedCommodityID: .vinyl, marketPriceMultiplier: 0.55,
            districtIDs: [.silverLake, .boyleHeights]
        ),
        GameEvent(
            id: "vintage-stylist-rush", kind: .opportunity, group: .market,
            title: "造型师集中扫货", message: "颁奖季和拍摄需求碰在一起，复古夹克被造型师批量收走。",
            affectedCommodityID: .vintageJacket, marketPriceMultiplier: 2.05,
            districtIDs: [.fashionDistrict, .hollywood, .venice]
        ),
        GameEvent(
            id: "vintage-rack-sale", kind: .setback, group: .market,
            title: "仓库清架", message: "服装仓库腾位置，大批复古夹克折价流入市场。",
            affectedCommodityID: .vintageJacket, marketPriceMultiplier: 0.50,
            districtIDs: [.fashionDistrict, .boyleHeights]
        ),
        GameEvent(
            id: "beauty-viral", kind: .opportunity, group: .market,
            title: "美妆视频走红", message: "本地创作者的试妆视频突然走红，美妆套装需求上升。",
            affectedCommodityID: .beautySet, marketPriceMultiplier: 2.00,
            districtIDs: [.koreatown, .fashionDistrict, .santaMonica]
        ),
        GameEvent(
            id: "beauty-overstock", kind: .setback, group: .market,
            title: "批发商清库存", message: "批发商集中清理旧包装，美妆套装售价被压低。",
            affectedCommodityID: .beautySet, marketPriceMultiplier: 0.50,
            districtIDs: [.koreatown, .fashionDistrict]
        ),
        GameEvent(
            id: "campus-snack-rush", kind: .opportunity, group: .market,
            title: "校园团购", message: "学生社团组织团购，进口零食很快售罄。",
            affectedCommodityID: .importedSnacks, marketPriceMultiplier: 1.75,
            districtIDs: [.westwood, .koreatown, .boyleHeights]
        ),
        GameEvent(
            id: "community-leftovers", kind: .opportunity, group: .market,
            title: "社区活动收尾", message: "你帮忙收拾社区活动，组织者把未拆封的进口零食送给了你。",
            reputationDelta: 1, affectedCommodityID: .importedSnacks, grantedQuantity: 6,
            districtIDs: [.boyleHeights, .koreatown, .westwood]
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
            districtIDs: [.fashionDistrict, .venice]
        ),
        GameEvent(
            id: "used-ev-demand", kind: .opportunity, group: .market,
            title: "二手电动车抢手", message: "通勤成本成为热门话题，车况透明的二手特斯拉更受关注。",
            affectedCommodityID: .usedTesla, marketPriceMultiplier: 1.45,
            districtIDs: [.santaMonica, .culverCity, .inglewood]
        ),
        GameEvent(
            id: "vape-enforcement", kind: .opportunity, group: .market,
            title: "无证货源收紧", message: "执法检查让无证电子烟货源收缩，黑市报价短暂上升。",
            affectedCommodityID: .smuggledVape, marketPriceMultiplier: 2.50
        )
    ]

    static let healthEvents: [GameEvent] = [
        GameEvent(
            id: "extreme-heat", kind: .health, group: .health,
            title: "高温警报", message: "内陆街区气温持续升高，你买了水并提前结束了户外奔波。",
            cashDelta: -12, healthDelta: -8,
            districtIDs: [.koreatown, .fashionDistrict, .boyleHeights, .hollywood, .silverLake, .inglewood, .culverCity, .westwood]
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
            districtIDs: [.hollywood, .silverLake]
        ),
        GameEvent(
            id: "cooler-failure", kind: .health, group: .health,
            title: "冷藏箱断电", message: "露天活动的冷藏箱断了电，你吃坏肚子并买了药。",
            cashDelta: -45, healthDelta: -7,
            districtIDs: [.fashionDistrict, .hollywood, .inglewood]
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
            districtIDs: [.hollywood, .culverCity, .fashionDistrict]
        ),
        GameEvent(
            id: "pothole-flat", kind: .setback, group: .money,
            title: "坑洞爆胎", message: "夜里没看清路面坑洞，只能临时更换轮胎。",
            cashDelta: -165,
            districtIDs: [.boyleHeights, .fashionDistrict, .koreatown, .inglewood]
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
            districtIDs: [.koreatown, .boyleHeights, .hollywood, .culverCity, .westwood, .santaMonica]
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
            districtIDs: [.fashionDistrict, .boyleHeights, .hollywood, .venice]
        )
    ]

    static let events = marketEvents + healthEvents + moneyEvents

    static func commodity(_ id: Commodity.ID) -> Commodity {
        commodities.first(where: { $0.id == id })!
    }

    static func district(_ id: District.ID) -> District {
        districts.first(where: { $0.id == id })!
    }
}
