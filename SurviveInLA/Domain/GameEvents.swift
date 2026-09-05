// 此文件是游戏随机事件的唯一代码数据源。
// 面向策划核对的表格见 docs/LOS-ANGELES-EVENTS.md。

extension GameContent {
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
            districtIDs: [.culverCity, .pasadenaRoseBowl, .santaMonica]
        ),
        GameEvent(
            id: "headline-ticket-rush", kind: .opportunity, group: .market,
            title: "郭德纲相声开票", message: "郭德纲相声公布演出场次，附近的门票需求猛增。",
            affectedCommodityID: .concertTickets, marketPriceMultiplier: 2.40,
            districtIDs: [.hollywood, .inglewood]
        ),
        GameEvent(
            id: "extra-show-added", kind: .setback, group: .market,
            title: "相声临时加场", message: "主办方临时增加场次，二级市场上的郭德纲相声门票价格回落。",
            affectedCommodityID: .concertTickets, marketPriceMultiplier: 0.45,
            districtIDs: [.hollywood, .inglewood]
        ),
        GameEvent(
            id: "vinyl-pop-up", kind: .opportunity, group: .market,
            title: "黑胶快闪市集", message: "独立唱片快闪活动带来人流，黑胶唱片突然变得抢手。",
            affectedCommodityID: .vinyl, marketPriceMultiplier: 1.85,
            districtIDs: [.hollywood, .pasadenaRoseBowl]
        ),
        GameEvent(
            id: "vinyl-reissue", kind: .setback, group: .market,
            title: "经典专辑再版", message: "唱片公司补发再版，原本稀缺的黑胶唱片价格下跌。",
            affectedCommodityID: .vinyl, marketPriceMultiplier: 0.55,
            districtIDs: [.hollywood, .pasadenaRoseBowl]
        ),
        GameEvent(
            id: "vintage-stylist-rush", kind: .opportunity, group: .market,
            title: "老酒收藏升温", message: "收藏圈开始集中寻找老酒，05年茅台被藏家批量收走。",
            affectedCommodityID: .vintageJacket, marketPriceMultiplier: 2.05,
            districtIDs: [.pasadenaRoseBowl, .hollywood, .venice]
        ),
        GameEvent(
            id: "vintage-rack-sale", kind: .setback, group: .market,
            title: "藏家集中出货", message: "一批藏家同时出货，05年茅台的市场价格短暂回落。",
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
            title: "校园辣条团购", message: "学生社团组织团购，国产辣条很快售罄。",
            affectedCommodityID: .importedSnacks, marketPriceMultiplier: 1.75,
            districtIDs: [.westwood, .koreatown, .figueroaCorridor, .irvine]
        ),
        GameEvent(
            id: "figueroa-vice-sweep", kind: .opportunity, group: .market,
            title: "Figueroa 警察扫黄", message: "LAPD 在菲格罗亚展开扫黄，街头同行突然减少，拉皮条的当周收入翻倍。",
            districtIDs: [.figueroaCorridor],
            triggerChance: 0.30, workIncomeMultiplier: 2
        ),
        GameEvent(
            id: "community-leftovers", kind: .opportunity, group: .market,
            title: "社区活动收尾", message: "你帮忙收拾社区活动，组织者把未拆封的国产辣条送给了你。",
            reputationDelta: 1, affectedCommodityID: .importedSnacks, grantedQuantity: 6,
            districtIDs: [.figueroaCorridor, .koreatown, .westwood, .sanGabriel, .littleSaigon]
        ),
        GameEvent(
            id: "console-shortage", kind: .opportunity, group: .market,
            title: "官换iphone缺货", message: "换机需求突然增加，附近商店的官换iphone很快卖空。",
            affectedCommodityID: .gameConsole, marketPriceMultiplier: 2.10,
            districtIDs: [.culverCity, .westwood]
        ),
        GameEvent(
            id: "console-refresh", kind: .setback, group: .market,
            title: "新机发布", message: "苹果公布新一代机型，现有官换iphone的价格回落。",
            affectedCommodityID: .gameConsole, marketPriceMultiplier: 0.55,
            districtIDs: [.culverCity, .westwood]
        ),
        GameEvent(
            id: "sneaker-game-day", kind: .opportunity, group: .market,
            title: "搬家季家具热", message: "搬家旺季和租房换约碰在一起，二手家具的询价不断。",
            affectedCommodityID: .sneakers, marketPriceMultiplier: 2.15,
            districtIDs: [.inglewood, .venice, .santaMonica]
        ),
        GameEvent(
            id: "sneaker-restock", kind: .setback, group: .market,
            title: "公寓集中清仓", message: "多栋公寓同时清仓，大批二手家具进入市场，价格迅速回落。",
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
            title: "辣条礼盒断货", message: "丁胖子广场的商家赶着补货，国产辣条礼盒很快被扫空。",
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
            title: "新房家具抢购", message: "科利马路附近集中交房，附近居民开始抢购二手家具。",
            affectedCommodityID: .sneakers, marketPriceMultiplier: 1.95,
            districtIDs: [.rowlandHeights]
        ),
        GameEvent(
            id: "industry-container-clearance", kind: .setback, group: .market,
            title: "货柜集中到仓", message: "几批进口货同时完成入仓，批发商急着腾库位，国产辣条价格被压低。",
            affectedCommodityID: .importedSnacks, marketPriceMultiplier: 0.55,
            districtIDs: [.cityOfIndustry]
        ),
        GameEvent(
            id: "irvine-tech-ev-turnover", kind: .setback, group: .market,
            title: "科技园换车潮", message: "科技园区一批通勤车集中进入二手市场，二手特斯拉价格回落。",
            affectedCommodityID: .usedTesla, marketPriceMultiplier: 0.68,
            districtIDs: [.irvine]
        ),
        GameEvent(
            id: "little-saigon-tet-gift-rush", kind: .opportunity, group: .market,
            title: "Tết 辣条礼盒抢购", message: "小西贡商圈开始为越南新年备货，国产辣条礼盒需求快速上升。",
            affectedCommodityID: .importedSnacks, marketPriceMultiplier: 1.90,
            districtIDs: [.littleSaigon]
        )
    ]

    static let healthEvents: [GameEvent] = [
        GameEvent(
            id: "extreme-heat", kind: .health, group: .health,
            title: "高温警报", message: "内陆街区气温持续升高，你买了水并提前结束了户外奔波。",
            cashDelta: -12, healthDelta: -8,
            districtIDs: [.koreatown, .pasadenaRoseBowl, .figueroaCorridor, .hollywood, .inglewood, .culverCity, .westwood, .dingPangZiPlaza, .sanGabriel, .rowlandHeights, .cityOfIndustry, .irvine, .littleSaigon]
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
            districtIDs: [.hollywood, .pasadenaRoseBowl]
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
            id: "industry-warehouse-rush-strain", kind: .health, group: .health,
            title: "爆单分拣拉伤", message: "快递仓库突然爆单，你连续搬箱分拣，收工时腰背已经抬不起来。",
            cashDelta: -30, healthDelta: -7,
            districtIDs: [.cityOfIndustry]
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
            id: "industry-damaged-shipment", kind: .setback, group: .money,
            title: "运输货损赔偿", message: "货车堵在60号高速，卸货又出了差错，你不得不承担一部分货损。",
            cashDelta: -190, reputationDelta: -1,
            districtIDs: [.cityOfIndustry]
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
}
