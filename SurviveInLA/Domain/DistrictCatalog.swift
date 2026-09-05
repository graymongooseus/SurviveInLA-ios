import CoreLocation
import Foundation

enum DistrictCatalog {
    static let districts: [District] = [
        District(
            id: .koreatown,
            name: "韩国城",
            englishName: "Koreatown",
            coordinate: .init(latitude: 34.0578, longitude: -118.3009),
            transitHint: "Metro D Line",
            marketRole: "落脚点 · 国产辣条与美妆货源",
            marketBiases: [.importedSnacks: 0.78, .beautySet: 0.84, .gameConsole: 0.94, .smuggledVape: 0.88],
            characterSummary: "高密度公寓、韩餐、KTV与深夜商业交织的移民生活圈。",
            gameplayHooks: ["合租纠纷", "深夜交易", "餐馆老板人脉", "K-pop活动", "停车罚单"],
            jobHooks: ["韩式烧烤店跑堂", "KTV夜班", "外卖配送", "超市理货", "代购取货"]
        ),
        District(
            id: .pasadenaRoseBowl,
            name: "帕萨迪纳·玫瑰碗",
            englishName: "Pasadena / Rose Bowl",
            coordinate: .init(latitude: 34.1613, longitude: -118.1676),
            transitHint: "Metro A + Shuttle",
            marketRole: "跳蚤市场与赛事 · 黑胶和老酒货源",
            marketBiases: [.vinyl: 0.82, .vintageJacket: 0.84, .camera: 0.91, .concertTickets: 1.12],
            characterSummary: "大型赛事、演唱会、玫瑰花车与月度跳蚤市场组成的活动型经济。",
            gameplayHooks: ["凌晨抢货", "古董鉴定", "摊位竞争", "比赛日门票", "玫瑰花车季节任务"],
            jobHooks: ["跳蚤市场搬货", "摊主助手", "球场检票", "停车引导", "花车装饰"]
        ),
        District(
            id: .figueroaCorridor,
            name: "菲格罗亚走廊",
            englishName: "Figueroa Corridor",
            coordinate: .init(latitude: 34.0180, longitude: -118.2827),
            transitHint: "Metro E Line",
            marketRole: "校园与场馆 · 辣条、二手家具和相声门票快销",
            marketBiases: [.importedSnacks: 1.08, .sneakers: 1.10, .concertTickets: 1.14, .smuggledVape: 0.88],
            characterSummary: "以USC至Exposition Park一段为核心，学生、博物馆与体育场人流集中。",
            gameplayHooks: ["大学开学季", "比赛日经济", "校园二手交易", "博物馆活动", "Metro延误"],
            jobHooks: ["校园餐厅临工", "体育场检票", "活动撤场清洁", "展会搬运", "学生搬家"]
        ),
        District(
            id: .hollywood,
            name: "好莱坞",
            englishName: "Hollywood",
            coordinate: .init(latitude: 34.1016, longitude: -118.3269),
            transitHint: "Metro B Line",
            marketRole: "游客与演出 · 相声门票和相机需求旺",
            marketBiases: [.concertTickets: 1.24, .camera: 1.13, .vintageJacket: 1.08, .smuggledVape: 1.20],
            characterSummary: "游客、剧院、电影拍摄、首映礼、夜生活与纪念品商业高度集中。",
            gameplayHooks: ["群众演员机会", "假星探骗局", "首映礼门票", "游客消费", "剧组临时缺设备"],
            jobHooks: ["群众演员", "片场助理", "剧院引座", "旅游团助理", "酒店夜班"]
        ),
        District(
            id: .inglewood,
            name: "英格尔伍德",
            englishName: "Inglewood",
            coordinate: .init(latitude: 33.9617, longitude: -118.3531),
            transitHint: "Metro K Line",
            marketRole: "赛事经济 · 二手家具与相声门票波动大",
            marketBiases: [.sneakers: 1.19, .concertTickets: 1.18, .gameConsole: 1.04, .usedTesla: 0.86],
            characterSummary: "大型体育场馆、演唱会经济与本地社区变迁同时发生。",
            gameplayHooks: ["比赛日暴涨", "演唱会黄牛", "停车位生意", "社区改造", "租金矛盾"],
            jobHooks: ["球场餐饮", "检票引导", "赛后清洁", "停车场管理", "比赛日网约车"]
        ),
        District(
            id: .culverCity,
            name: "卡尔弗城",
            englishName: "Culver City",
            coordinate: .init(latitude: 34.0211, longitude: -118.3965),
            transitHint: "Metro E Line",
            marketRole: "影视科技 · 相机、官换iphone与二手车交易活跃",
            marketBiases: [.camera: 1.16, .gameConsole: 1.12, .concertTickets: 1.05, .usedTesla: 0.91],
            characterSummary: "影视制作、创意公司、艺术区、科技办公与精品餐饮结合。",
            gameplayHooks: ["剧组突然开工", "设备租赁", "广告项目取消", "科技公司裁员", "艺术节"],
            jobHooks: ["片场跑腿", "器材搬运", "剧组餐饮", "展览布置", "办公室IT支援"]
        ),
        District(
            id: .westwood,
            name: "西木区",
            englishName: "Westwood",
            coordinate: .init(latitude: 34.0635, longitude: -118.4455),
            transitHint: "Metro Bus",
            marketRole: "校园客群 · 官换iphone和辣条容易出手",
            marketBiases: [.gameConsole: 1.17, .importedSnacks: 1.13, .concertTickets: 1.07],
            characterSummary: "UCLA、医疗中心、学生公寓与Westwood Village形成稳定的校园经济。",
            gameplayHooks: ["开学季抢货", "期末考试", "学生搬家", "留学生家庭", "医院突发任务"],
            jobHooks: ["中文家教", "学生搬家", "校园餐饮", "医院文件配送", "留学生接送"]
        ),
        District(
            id: .venice,
            name: "威尼斯",
            englishName: "Venice",
            coordinate: .init(latitude: 33.9850, longitude: -118.4695),
            transitHint: "Big Blue Bus",
            marketRole: "海滨旅游 · 二手家具与05年茅台受欢迎",
            marketBiases: [.sneakers: 1.16, .vintageJacket: 1.19, .camera: 1.10],
            characterSummary: "海滩、滑板、冲浪、街头艺人、游客与创意产业并存。",
            gameplayHooks: ["滑板比赛", "街头演出", "海滩执法", "摊贩许可", "潮牌快闪"],
            jobHooks: ["自行车租赁", "冲浪板租赁", "海滨餐厅", "街头摄影", "活动摊位"]
        ),
        District(
            id: .santaMonica,
            name: "圣塔莫尼卡",
            englishName: "Santa Monica",
            coordinate: .init(latitude: 34.0195, longitude: -118.4912),
            transitHint: "Metro E Line",
            marketRole: "高消费终点 · 多数商品售价偏高",
            marketBiases: [.sneakers: 1.15, .camera: 1.14, .beautySet: 1.20, .importedSnacks: 1.09, .usedTesla: 1.22],
            characterSummary: "码头、酒店、海滨零售、Third Street Promenade与高消费游客集中。",
            gameplayHooks: ["旅游旺季", "酒店会议", "码头活动", "奢侈品订单", "海滩天气波动"],
            jobHooks: ["酒店服务", "码头摊位", "游乐设施员工", "精品店销售", "自行车租赁"]
        ),
        District(
            id: .dingPangZiPlaza,
            name: "丁胖子广场",
            englishName: "Ding Pang Zi Plaza",
            coordinate: .init(latitude: 34.0637, longitude: -118.1337),
            transitHint: "Metro Bus",
            marketRole: "草根华人商圈 · 零食、美妆和小商品货源",
            marketBiases: [.importedSnacks: 0.76, .beautySet: 0.86, .gameConsole: 0.94, .smuggledVape: 0.80],
            characterSummary: "以蒙特利公园Garvey商业带为原型，餐饮、超市、茶馆和小商品密集。",
            gameplayHooks: ["家庭餐馆", "现金周转", "微信群团购", "春节旺季", "熟人人情债"],
            jobHooks: ["餐馆帮工", "华人超市理货", "奶茶店夜班", "宴会帮工", "同城送货"]
        ),
        District(
            id: .sanGabriel,
            name: "圣盖博",
            englishName: "San Gabriel",
            coordinate: .init(latitude: 34.0782, longitude: -118.1021),
            transitHint: "Metro Bus",
            marketRole: "华人商业中心 · 餐饮、服务与跨境生意",
            marketBiases: [.importedSnacks: 0.82, .beautySet: 0.90, .gameConsole: 0.92, .camera: 0.96, .smuggledVape: 0.84],
            characterSummary: "Valley Boulevard沿线聚集酒楼、超市、珠宝、旅行社与专业服务。",
            gameplayHooks: ["酒楼宴席", "跨境包裹", "珠宝交易", "移民家庭", "代际观念冲突"],
            jobHooks: ["酒楼传菜", "超市仓库", "双语前台", "珠宝店保安", "文件配送"]
        ),
        District(
            id: .rowlandHeights,
            name: "罗兰岗",
            englishName: "Rowland Heights",
            coordinate: .init(latitude: 33.9734, longitude: -117.8941),
            transitHint: "Freeway + Bus",
            marketRole: "新移民商业带 · 广场经济与夜间交易",
            marketBiases: [.importedSnacks: 0.84, .gameConsole: 0.90, .sneakers: 1.08, .usedTesla: 1.10, .smuggledVape: 0.82],
            characterSummary: "东圣盖博谷的汽车型商业区，大型广场、亚洲餐饮与夜间消费突出。",
            gameplayHooks: ["深夜广场", "豪车反差", "补习班竞争", "餐馆转让", "长距离送货"],
            jobHooks: ["餐馆夜班", "奶茶店", "补习班助教", "网约车", "汽车美容"]
        ),
        District(
            id: .cityOfIndustry,
            name: "工业市",
            englishName: "City of Industry",
            coordinate: .init(latitude: 34.0025, longitude: -117.9248),
            transitHint: "Freeway + Freight Rail",
            marketRole: "物流批发枢纽 · 辣条、官换iphone和小商品低价货源",
            marketBiases: [.importedSnacks: 0.78, .gameConsole: 0.86, .beautySet: 0.91, .sneakers: 0.92],
            characterSummary: "仓库、物流、快递、批发与华人商铺超市构成的高强度工作区。",
            gameplayHooks: ["货柜到港", "仓库爆单", "60号高速堵车", "仓库失窃", "批发商清仓", "货损纠纷"],
            jobHooks: ["仓库分拣", "快递打包", "超市理货", "送货司机", "物流调度", "夜间保安", "叉车操作", "双语跟单"]
        ),
        District(
            id: .irvine,
            name: "尔湾",
            englishName: "Irvine",
            coordinate: .init(latitude: 33.6887, longitude: -117.8335),
            transitHint: "Metrolink / Car",
            marketRole: "科技与高端华人 · 特斯拉和精品溢价",
            marketBiases: [.usedTesla: 1.28, .beautySet: 1.16, .camera: 1.12, .sneakers: 1.10, .gameConsole: 1.08],
            characterSummary: "规划型社区、UCI、科技园区、高房价家庭与国际餐饮并存。",
            gameplayHooks: ["科技公司裁员", "创业项目", "二手特斯拉", "学区竞争", "房地产现金流"],
            jobHooks: ["程序外包", "数学或中文家教", "餐馆服务", "宠物照看", "搬家整理"]
        ),
        District(
            id: .littleSaigon,
            name: "威斯敏斯特·小西贡",
            englishName: "Little Saigon, Westminster",
            coordinate: .init(latitude: 33.7432, longitude: -117.9685),
            transitHint: "OC Bus / Car",
            marketRole: "越南与华裔移民商圈 · 餐饮、金行和家族生意",
            marketBiases: [.importedSnacks: 0.79, .beautySet: 0.88, .smuggledVape: 0.78, .vintageJacket: 0.93],
            characterSummary: "以Bolsa Avenue为核心的越南文化、商业、家庭商店与移民社区。",
            gameplayHooks: ["难民家庭历史", "代际冲突", "越南新年旺季", "家族店接班", "跨族裔合作"],
            jobHooks: ["越南粉店厨房", "面包店收银", "超市理货", "节庆活动搭建", "长者接送", "双语送货"]
        )
    ]

    static let jobs: [JobOpportunity] = [
        JobOpportunity(districtID: .koreatown, title: "韩餐馆夜班", detail: "深夜客人多，下班时天已经快亮了。", wage: 370, healthCost: 5),
        JobOpportunity(districtID: .pasadenaRoseBowl, title: "跳蚤市场搭摊", detail: "天不亮就进场，帮摊主搬货摆货。", wage: 390, healthCost: 5),
        JobOpportunity(districtID: .figueroaCorridor, title: "拉皮条", detail: "你在菲格罗亚街头替性交易招揽客人，收入高，但连续做下去会迅速引来执法风险。", wage: 600, healthCost: 6),
        JobOpportunity(districtID: .hollywood, title: "片场临时群演", detail: "等候时间比上镜时间长得多。", wage: 480, healthCost: 4),
        JobOpportunity(districtID: .inglewood, title: "赛事场馆装卸", detail: "赶在观众入场前把设备全部归位。", wage: 460, healthCost: 6),
        JobOpportunity(districtID: .culverCity, title: "剧组制片助理", detail: "送文件、买咖啡、盯器材，什么都做。", wage: 520, healthCost: 6),
        JobOpportunity(districtID: .westwood, title: "校园跑腿配送", detail: "订单不大，但宿舍楼之间来回很费腿。", wage: 350, healthCost: 4),
        JobOpportunity(districtID: .venice, title: "海边租赁摊帮工", detail: "搬单车、擦滑板，还要回答游客问题。", wage: 390, healthCost: 5),
        JobOpportunity(districtID: .santaMonica, title: "酒店宴会临工", detail: "换场速度快，结束后能拿到一笔小费。", wage: 450, healthCost: 5),
        JobOpportunity(districtID: .dingPangZiPlaza, title: "广场餐馆帮工", detail: "洗菜、打包、送外卖，现金当天结。", wage: 320, healthCost: 4),
        JobOpportunity(districtID: .sanGabriel, title: "华人超市理货", detail: "凌晨补货，忙完正好赶上早市。", wage: 380, healthCost: 5),
        JobOpportunity(districtID: .rowlandHeights, title: "夜市摊位帮手", detail: "搭棚、收摊，再帮老板看一会儿货。", wage: 420, healthCost: 5),
        JobOpportunity(districtID: .cityOfIndustry, title: "快递仓库分拣", detail: "传送带不停，赶在货车发班前把包裹全部分区。", wage: 470, healthCost: 7),
        JobOpportunity(districtID: .irvine, title: "科技展会临工", detail: "替参展公司布置展台、搬运设备。", wage: 560, healthCost: 5),
        JobOpportunity(districtID: .littleSaigon, title: "家族餐馆外场", detail: "午市翻台快，小费全靠手脚麻利。", wage: 360, healthCost: 4)
    ]

    static let investments: [InvestmentOpportunity] = [
        InvestmentOpportunity(districtID: .koreatown, title: "美妆直播拼货", detail: "主播准备测试一批新的本地货盘。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .pasadenaRoseBowl, title: "古董摊联合收货", detail: "几位摊主准备吃下一整仓旧物。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .figueroaCorridor, title: "比赛日零食摊", detail: "学生社团押注本周末的主场人流。", risk: .low, minimumInvestment: 100),
        InvestmentOpportunity(districtID: .hollywood, title: "独立短片众筹", detail: "导演说只差这一周就能开机。", risk: .high, minimumInvestment: 300),
        InvestmentOpportunity(districtID: .inglewood, title: "赛事停车联营", detail: "车位已经谈妥，只等比赛日客流。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .culverCity, title: "独立游戏原型", detail: "三个人的团队需要撑过最后一个冲刺周。", risk: .high, minimumInvestment: 300),
        InvestmentOpportunity(districtID: .westwood, title: "校园二手书周转", detail: "开学季需求稳定，利润不算惊人。", risk: .low, minimumInvestment: 100),
        InvestmentOpportunity(districtID: .venice, title: "街头品牌快闪", detail: "主理人把全部希望押在周末天气上。", risk: .high, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .santaMonica, title: "旅游纪念品补货", detail: "码头商店为周末游客提前备货。", risk: .low, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .dingPangZiPlaza, title: "广场团购拼单", detail: "几家小店一起进一批节庆礼盒。", risk: .low, minimumInvestment: 100),
        InvestmentOpportunity(districtID: .sanGabriel, title: "新餐馆试营业", detail: "朋友缺最后一笔食材周转金。", risk: .medium, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .rowlandHeights, title: "夜市快闪摊", detail: "网红摊主要押一周末的人流。", risk: .high, minimumInvestment: 200),
        InvestmentOpportunity(districtID: .cityOfIndustry, title: "货柜尾货拼单", detail: "一批进口尾货急着出仓，利润取决于货损比例。", risk: .medium, minimumInvestment: 300),
        InvestmentOpportunity(districtID: .irvine, title: "华人创业应用", detail: "一支小团队正在抢发布前的窗口期。", risk: .high, minimumInvestment: 500),
        InvestmentOpportunity(districtID: .littleSaigon, title: "家族金行代购", detail: "短单周转快，但金价一天一个样。", risk: .medium, minimumInvestment: 200)
    ]

    static func district(_ id: District.ID) -> District {
        districts.first(where: { $0.id == id })!
    }
}
