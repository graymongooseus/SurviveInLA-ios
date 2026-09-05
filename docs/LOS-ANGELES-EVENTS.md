# 《洛杉矶浮生记》随机事件全表

> 这是事件策划核对表。把“☐”改成“☑”即可标记已确认；讨论修改时优先引用稳定 ID，避免重名或改名造成误会。

## 文件与协作约定

- 游戏实际调用的唯一代码数据源：[GameEvents.swift](../SurviveInLA/Domain/GameEvents.swift)。
- 游戏仍通过 `GameContent.events`、`marketEvents`、`healthEvents` 和 `moneyEvents` 调用，现有调用方无需修改。
- 稳定 ID 用于存档和协作定位，修改标题、文案、数值或地点时不要改 ID；新增事件时使用新的唯一 ID。
- 本表用于逐条核对。确定修改后，应同时更新代码数据源与本表，并运行事件完整性测试。

## 事件规模与触发规则

事件保留《北京浮生记》v1.2.2 的三个核心随机事件分类，并为六个扩展区域各补充三条专属事件：

- 市场事件：25 条
- 健康事件：18 条
- 钱财事件：13 条
- 合计：56 条

每次成功移动到另一个地区，系统从该地区允许发生的事件中等概率抽取一条。地区限定用于保证海滩、片场、演出和校园事件只在合理地点出现。

`figueroa-vice-sweep` 是例外：它不进入普通移动抽取池，只在菲格罗亚选择“拉皮条”时以 30% 概率独立判定。

- 市场涨跌事件会确保受影响商品出现在当日五种报价中，然后应用价格倍率，并受商品最低价和最高价限制。
- 赠送商品受剩余仓储容量限制，免费商品按零成本计入平均成本。
- 健康和钱财事件直接修改玩家状态；现金、健康和声望不会低于零。
- 出售“走私电子烟”每笔交易额外降低 5 点声望，并写入生存日记。
- 旧存档中尚未带分类和地点字段的事件仍可正常解码。

## 市场事件（25 条）

| 核对 | # | 稳定 ID | 事件 | 地点 | 效果 |
|:---:|---:|---|---|---|---|
| ☐ | 1 | `studio-camera-rush` | 片场临时缺设备 | 好莱坞、卡尔弗城 | 二手相机 ×1.90 |
| ☐ | 2 | `camera-estate-sale` | 相机集中入市 | 卡尔弗城、帕萨迪纳·玫瑰碗、圣塔莫尼卡 | 二手相机 ×0.55 |
| ☐ | 3 | `headline-ticket-rush` | 郭德纲相声开票 | 好莱坞、英格尔伍德 | 郭德纲相声门票 ×2.40 |
| ☐ | 4 | `extra-show-added` | 相声临时加场 | 好莱坞、英格尔伍德 | 郭德纲相声门票 ×0.45 |
| ☐ | 5 | `vinyl-pop-up` | 黑胶快闪市集 | 好莱坞、帕萨迪纳·玫瑰碗 | 黑胶唱片 ×1.85 |
| ☐ | 6 | `vinyl-reissue` | 经典专辑再版 | 好莱坞、帕萨迪纳·玫瑰碗 | 黑胶唱片 ×0.55 |
| ☐ | 7 | `vintage-stylist-rush` | 老酒收藏升温 | 帕萨迪纳·玫瑰碗、好莱坞、威尼斯 | 05年茅台 ×2.05 |
| ☐ | 8 | `vintage-rack-sale` | 藏家集中出货 | 帕萨迪纳·玫瑰碗、丁胖子广场 | 05年茅台 ×0.50 |
| ☐ | 9 | `beauty-viral` | 美妆视频走红 | 韩国城、圣塔莫尼卡、尔湾、丁胖子广场 | 美妆套装 ×2.00 |
| ☐ | 10 | `beauty-overstock` | 批发商清库存 | 韩国城、丁胖子广场、威斯敏斯特·小西贡 | 美妆套装 ×0.50 |
| ☐ | 11 | `campus-snack-rush` | 校园辣条团购 | 西木区、韩国城、菲格罗亚走廊、尔湾 | 国产辣条 ×1.75 |
| ☐ | 12 | `figueroa-vice-sweep` | Figueroa 警察扫黄 | 菲格罗亚走廊；仅拉皮条时判定 | 30% 概率触发；当周收入 ×2 |
| ☐ | 13 | `community-leftovers` | 社区活动收尾 | 菲格罗亚走廊、韩国城、西木区、圣盖博、威斯敏斯特·小西贡 | 免费获得最多 6 份国产辣条；声望 +1 |
| ☐ | 14 | `console-shortage` | 官换iphone缺货 | 卡尔弗城、西木区 | 官换iphone ×2.10 |
| ☐ | 15 | `console-refresh` | 新机发布 | 卡尔弗城、西木区 | 官换iphone ×0.55 |
| ☐ | 16 | `sneaker-game-day` | 搬家季家具热 | 英格尔伍德、威尼斯、圣塔莫尼卡 | 二手家具 ×2.15 |
| ☐ | 17 | `sneaker-restock` | 公寓集中清仓 | 菲格罗亚走廊、威尼斯、罗兰岗 | 二手家具 ×0.55 |
| ☐ | 18 | `used-ev-demand` | 二手电动车抢手 | 圣塔莫尼卡、卡尔弗城、英格尔伍德、尔湾 | 二手特斯拉 ×1.45 |
| ☐ | 19 | `vape-enforcement` | 无证货源收紧 | 所有地点 | 走私电子烟 ×2.50 |
| ☐ | 20 | `ding-pang-zi-gift-box-rush` | 辣条礼盒断货 | 丁胖子广场 | 国产辣条 ×1.85 |
| ☐ | 21 | `san-gabriel-wedding-beauty-rush` | 婚宴季美妆抢货 | 圣盖博 | 美妆套装 ×1.80 |
| ☐ | 22 | `rowland-colima-sneakers` | 新房家具抢购 | 罗兰岗 | 二手家具 ×1.95 |
| ☐ | 23 | `industry-container-clearance` | 货柜集中到仓 | 工业市 | 国产辣条 ×0.55 |
| ☐ | 24 | `irvine-tech-ev-turnover` | 科技园换车潮 | 尔湾 | 二手特斯拉 ×0.68 |
| ☐ | 25 | `little-saigon-tet-gift-rush` | Tết 辣条礼盒抢购 | 威斯敏斯特·小西贡 | 国产辣条 ×1.90 |

## 菲格罗亚高风险打工规则

| 项目 | 规则 |
|---|---|
| 常规收入 | 每周随机 $500–$700 |
| 扫黄行情 | 每次拉皮条独立有 30% 概率触发，收入翻倍为 $1,000–$1,400 |
| 连续风险 | 连续第 3 周拉皮条不结算收入，直接触发 `lapd-sting-operation` |
| 钓鱼执法 | 弹窗提示、现金 −$1,000、跳过 2 周；债务与存款照常计息 |
| 中断条件 | 倒卖、投资、离开菲格罗亚或在其他区域打工会清零连续次数 |

## 健康事件（18 条）

| 核对 | # | 稳定 ID | 事件 | 地点 | 效果 |
|:---:|---:|---|---|---|---|
| ☐ | 1 | `extreme-heat` | 高温警报 | 除威尼斯、圣塔莫尼卡外 | 现金 −12，健康 −8 |
| ☐ | 2 | `wildfire-smoke` | 山火烟尘 | 所有地点 | 现金 −18，健康 −7 |
| ☐ | 3 | `unhealthy-air` | 空气质量变差 | 所有地点 | 现金 −10，健康 −4 |
| ☐ | 4 | `metro-hard-stop` | 列车急停 | 所有地点 | 健康 −3 |
| ☐ | 5 | `freeway-gridlock` | 高速堵死 | 所有地点 | 现金 −24，健康 −2 |
| ☐ | 6 | `hillside-dehydration` | 山坡脱水 | 好莱坞、帕萨迪纳·玫瑰碗 | 现金 −8，健康 −6 |
| ☐ | 7 | `cooler-failure` | 冷藏箱断电 | 帕萨迪纳·玫瑰碗、菲格罗亚走廊、好莱坞、英格尔伍德 | 现金 −45，健康 −7 |
| ☐ | 8 | `bike-path-fall` | 自行车道摔倒 | 威尼斯、圣塔莫尼卡、卡尔弗城 | 现金 −35，健康 −6 |
| ☐ | 9 | `rip-current` | 离岸流 | 威尼斯、圣塔莫尼卡 | 健康 −12 |
| ☐ | 10 | `earthquake-jolt` | 地震晃动 | 所有地点 | 现金 −25，健康 −5 |
| ☐ | 11 | `sleep-debt` | 连续缺觉 | 所有地点 | 现金 −7，健康 −4 |
| ☐ | 12 | `seasonal-flu` | 季节性流感 | 所有地点 | 现金 −28，健康 −5 |
| ☐ | 13 | `ding-pang-zi-kitchen-smoke` | 后厨油烟呛到 | 丁胖子广场 | 现金 −18，健康 −4 |
| ☐ | 14 | `san-gabriel-kitchen-burn` | 深夜厨房烫伤 | 圣盖博 | 现金 −45，健康 −6 |
| ☐ | 15 | `rowland-market-back-strain` | 闭店搬货腰伤 | 罗兰岗 | 现金 −25，健康 −5 |
| ☐ | 16 | `industry-warehouse-rush-strain` | 爆单分拣拉伤 | 工业市 | 现金 −30，健康 −7 |
| ☐ | 17 | `irvine-long-commute-fatigue` | 长途通勤透支 | 尔湾 | 现金 −30，健康 −6 |
| ☐ | 18 | `little-saigon-kitchen-slip` | 湿滑后厨摔倒 | 威斯敏斯特·小西贡 | 现金 −35，健康 −5 |

## 钱财事件（13 条）

| 核对 | # | 稳定 ID | 事件 | 地点 | 效果 |
|:---:|---:|---|---|---|---|
| ☐ | 1 | `street-cleaning-ticket` | 街道清扫罚单 | 所有地点 | 现金 −75 |
| ☐ | 2 | `temporary-no-parking-tow` | 临时禁停拖车 | 好莱坞、卡尔弗城、菲格罗亚走廊、帕萨迪纳·玫瑰碗 | 现金 −310 |
| ☐ | 3 | `pothole-flat` | 坑洞爆胎 | 菲格罗亚走廊、韩国城、英格尔伍德、丁胖子广场、罗兰岗 | 现金 −165 |
| ☐ | 4 | `phone-screen-repair` | 手机屏幕摔裂 | 所有地点 | 现金 −120 |
| ☐ | 5 | `metro-delay-rideshare` | 轨道服务延误 | 韩国城、菲格罗亚走廊、好莱坞、卡尔弗城、西木区、圣塔莫尼卡、帕萨迪纳·玫瑰碗 | 现金 −48 |
| ☐ | 6 | `beach-parking` | 海边停车超时 | 威尼斯、圣塔莫尼卡 | 现金 −70 |
| ☐ | 7 | `vending-compliance` | 补齐摆摊手续 | 菲格罗亚走廊、好莱坞、威尼斯、帕萨迪纳·玫瑰碗、丁胖子广场、威斯敏斯特·小西贡 | 现金 −85，声望 +2 |
| ☐ | 8 | `ding-pang-zi-referral-shift` | 熟客介绍短工 | 丁胖子广场 | 现金 +110，声望 +1 |
| ☐ | 9 | `san-gabriel-repaid-tab` | 熟客补回欠款 | 圣盖博 | 现金 +140，声望 +1 |
| ☐ | 10 | `rowland-carpool-delivery` | 拼车送货赚外快 | 罗兰岗 | 现金 +125，健康 −2 |
| ☐ | 11 | `industry-damaged-shipment` | 运输货损赔偿 | 工业市 | 现金 −190，声望 −1 |
| ☐ | 12 | `irvine-expo-overtime` | 科技展会加班费 | 尔湾 | 现金 +180，声望 +1 |
| ☐ | 13 | `little-saigon-wedding-tips` | 婚宴帮工小费 | 威斯敏斯特·小西贡 | 现金 +130，声望 +1 |

## 新增区域覆盖

| 区域 | 市场事件 | 健康事件 | 钱财事件 |
|---|---|---|---|
| 丁胖子广场 | 节庆礼盒断货 | 后厨油烟呛到 | 熟客介绍短工 |
| 圣盖博 | 婚宴季美妆抢货 | 深夜厨房烫伤 | 熟客补回欠款 |
| 罗兰岗 | 新房家具抢购 | 闭店搬货腰伤 | 拼车送货赚外快 |
| 工业市 | 货柜集中到仓 | 爆单分拣拉伤 | 运输货损赔偿 |
| 尔湾 | 科技园换车潮 | 长途通勤透支 | 科技展会加班费 |
| 威斯敏斯特·小西贡 | Tết 礼盒抢购 | 湿滑后厨摔倒 | 婚宴帮工小费 |

## 洛杉矶现实依据

事件不对应某一天的实时新闻，而是根据洛杉矶长期存在的生活与经营场景创作：

- 洛杉矶县公共卫生部门将极端高温列为明确健康风险，并提供降温中心信息。
- South Coast AQMD 持续发布空气质量、山火烟尘与飞灰健康建议。
- LA Metro 提供实时服务提醒、事故报告和乘车安全指引。
- 加州地震预警系统会通过 MyShake、Android 和无线紧急警报发送预警。
- 洛杉矶县海滩提示离岸流、礁石、码头结构等风险，并建议在救生员附近活动。
- 洛杉矶市的街头及公园售卖需要相应商业、税务和卫生许可。
- FilmLA 持续统计大洛杉矶地区的外景拍摄活动，因此片场临时需求适合作为好莱坞和卡尔弗城的市场事件。
- 洛杉矶县规划文件将科利马路列为罗兰岗的商业走廊，适合承载商铺补货、送货和闭店搬运事件。
- 尔湾市将医疗科技、创新技术和清洁能源列为重点行业，同时通勤交通是当地长期经营场景。
- 圣盖博长期举办含餐饮、购物和表演摊位的新年活动；威斯敏斯特的小西贡则有明确的 Tết 游行与越南裔商业文化背景。
- 工业市以仓储、批发配送、运输物流和电商为主要就业产业，适合物流爆单、货柜清仓和运输货损事件。

参考资料：

- [Los Angeles County Department of Public Health — Extreme Heat](https://publichealth.lacounty.gov/eh/safety/extreme-heat.htm)
- [South Coast AQMD — Wildfire Smoke & Health](https://www.aqmd.gov/home/air-quality/wildfire-health-info-smoke-tips)
- [LA Metro — Rider Guide](https://www.metro.net/safety-support/rider-guide/)
- [California Earthquake Early Warning](https://www.earthquake.ca.gov/)
- [LA County Beaches & Harbors — Beach Rules](https://beaches.lacounty.gov/la-county-beach-rules/)
- [StreetsLA — Sidewalk Vending Permit Guide](https://www.streetsla.lacity.org/sites/default/files/vending_program_brochure_english_20240411.pdf)
- [FilmLA — Research](https://filmla.com/research/)
- [LA County Planning — East San Gabriel Valley Area Plan: Rowland Heights](https://planning.lacounty.gov/wp-content/uploads/2023/03/RowlandHeights.pdf)
- [City of Irvine — Irvine Navigator Program](https://cityofirvine.org/economic-development/irvine-navigator-program)
- [City of San Gabriel — Winter Events](https://www.sangabrielcity.com/1400/Winter-Events)
- [City of Westminster — Little Saigon Tết Parade](https://www.westminster-ca.gov/Home/Components/Calendar/Event/2192/558)
- [City of Industry — Employment Base](https://www.cityofindustry.org/235/Employment-Base)
