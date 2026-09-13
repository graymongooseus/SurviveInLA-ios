# 洛杉矶浮生记：游戏机制与文件地图

这份说明面向不写程序的项目策划者。阅读时先关注“我要改变什么体验”，再查对应文件，不需要先学会 Swift。

更新：2026-09-10。本次已落实全局架构整理：统一回合流水线、按玩法拆分引擎、统一弹窗顺序和旧档恢复。新增吴宇森片场邀约、两个龙套角色、群演盒饭与 10 周后分红。名人合影与投资仍保留；徐静蕾目前只有人物登记。

## 1. 先理解六种分工

| 分工 | 生活中的比喻 | 在游戏里做什么 |
| --- | --- | --- |
| 内容配置 | 剧本和数值表 | 写有哪些事件、发生条件、故事、选项和参数 |
| 规则与数据定义 | 表格的栏目和填写规则 | 规定事件、条件、效果、角色状态可以怎样表示 |
| 引擎 | 按规则主持游戏的人 | 推进回合、抽取事件、扣钱、加健康、结算到期投资 |
| 游戏状态 | 本局账本 | 记住玩家现在的钱、健康、地点、已做选择、仍在生效的事件 |
| 界面 | 玩家看到的窗口和按钮 | 显示故事、接收金额、展示结果 |
| 存档与检查 | 保存账本和核对账目 | 退出后恢复进度，检查配置和机制是否正确 |

JSON 是适合保存配置的文本格式；Swift 是实现程序行为的语言；Markdown（.md）是说明文档；Python（.py）在这里用来运行配置检查工具。

## 2. 文件树：现有文件与已确认的规划

下面的树以项目根目录为起点，仅列游戏机制和事件相关的重要文件。未标注状态的条目是现有文件；标注“待新增／待迁移／待设计”的条目是已确认的目录规划，尚未接入游戏。

```text
SurviveInLA/
├── Resources/Content/                 事件内容与文案
│   ├── manifest.json                 内容文件清单、世界事件抽取配置
│   ├── characters/                   人物资料
│   │   └── celebrities.json          名人名册：贾跃亭、徐静蕾、陈冠希、吴宇森
│   ├── events/
│   │   ├── locations/
│   │   │   ├── market.json           地点相关的市场事件
│   │   │   ├── health.json           地点相关的健康事件
│   │   │   └── money.json            地点相关的金钱事件
│   │   ├── world/economy.json        世界经济事件
│   │   ├── life-choices/choices.json 阶段性人生选择
│   │   └── celebrities/             名人交互事件
│   │       ├── jia-yueting.json      贾跃亭：罗兰岗 FF 投资
│   │       ├── xu-jinglei.json       【待设计】徐静蕾，确定首个故事后创建
│   │       ├── chen-guanxi.json      陈冠希：Santa Monica 合影、增益、售照
│   │       └── wu-yu-sen.json        吴宇森：Hollywood 片场、盒饭和票房分红
│   └── localisation/zh-Hans.json     简体中文故事与选项文案
├── Domain/                            数据结构与规则定义
│   ├── GameModels.swift              本局状态、玩家状态等基础数据
│   ├── CurrencyFormatting.swift      故事与界面共用的美元显示格式
│   ├── GameContent.swift             基础游戏内容入口
│   ├── DistrictCatalog.swift         地区内容入口
│   ├── LocationEvents.swift          地点事件衔接入口
│   ├── WorldEvents.swift             世界事件衔接入口
│   ├── JourneyResult.swift           旅程结算相关数据
│   └── Events/
│       ├── EventModels.swift         普通事件和选择等事件数据结构
│       ├── PendingInteraction.swift  当前必须先处理哪种选择
│       ├── EventCondition.swift      触发条件及条件组合
│       ├── EventEffect.swift         引擎支持哪些事件效果
│       ├── EventSelection.swift      事件候选的选择规则
│       ├── EventContentCatalog.swift 加载、查找和校验内容库
│       ├── WorldEventModels.swift    世界事件、收益倾向及持续影响的数据
│       ├── InvestmentEventModels.swift 投资邀请、待结算投资的数据
│       ├── CelebrityEventModels.swift 名人、交互阶段、合影选项与照片
│       ├── CelebrityActingModels.swift 片场身份、冻结片酬与待发分红
│       └── PlayerBuffModels.swift    个人限时增益的定义与活动实例
├── Engine/                            实际执行游戏规则
│   ├── GameEngine.swift              创建新局、持有平衡参数与随机数
│   ├── GameActionRules.swift         动作前置检查、行动次数及共用计算
│   ├── JourneySettlementEngine.swift 旅程结束、资产清算与结局
│   ├── SeededRandomNumberGenerator.swift 可复现的随机数来源
│   ├── Turns/
│   │   └── TurnEngine.swift          所有跨回合结算的唯一入口
│   ├── Actions/
│   │   ├── TradingEngine.swift       商品买卖、银行、还债和报价
│   │   ├── WorkEngine.swift          打工、躺平、地区投资和工作风险
│   │   ├── CityServicesEngine.swift  诊所、按摩与仓储升级
│   │   └── EquipmentEngine.swift     驾照、住房、车辆、工具、物业与每周费用
│   └── Events/
│       ├── SessionEventEngine.swift  地点事件、人生选择和各事件引擎的衔接
│       ├── EventEffectExecutor.swift 执行金钱、健康、运气、价格等效果
│       ├── WorldEventScheduler.swift 决定何时抽取世界事件、如何按权重选择
│       ├── InvestmentEventEngine.swift 投资邀请、接受或拒绝、到期结算
│       ├── CelebrityEventEngine.swift 抵达时遇见名人、合影和出售
│       ├── CelebrityActingEngine.swift 片场邀约、角色选择与上映结算
│       └── PlayerBuffEngine.swift    增益叠加、逐回合恢复和到期
├── Store/                             连接界面、游戏状态和存档
│   ├── GameStore.swift               接收操作、更新显示、保存进度
│   ├── GamePresentation.swift        决定当前只展示哪一个弹窗
│   ├── GameSnapshotMigration.swift   统一补齐旧档字段与版本转换
│   ├── ProfileManager.swift          管理玩家档案
│   └── ProfilePersistence.swift      保存、读取与 iCloud 同步
└── UI/                                玩家看到和操作的界面
    ├── Home/
    │   ├── GameHomeView.swift         游戏主界面及弹窗组合入口
    │   ├── CityMapView.swift          地图界面
    │   ├── StatusStripView.swift      状态栏
    │   ├── WorldEventOverlay.swift    世界事件弹窗
    │   ├── HealthEventOverlay.swift   健康事件弹窗
    │   ├── InvestmentEventOverlay.swift 投资故事、金额输入、回应和结果
    │   ├── CelebrityEventOverlay.swift 合影三步弹窗，以及合照与增益相册
    │   ├── CelebrityActingOverlay.swift 龙套／群演三选一与上映结果
    │   ├── SupportViews.swift         主界面辅助视图
    │   └── GameResultView.swift       旅程结果界面
    └── Market/
        ├── MarketPanelView.swift     市场列表
        └── TradeSheetView.swift      买卖操作界面

SurviveInLATests/
├── ArchitectureIntegrationTests.swift 跨回合、弹窗、阻塞和旧档的联动检查
├── ArchitectureReplayTests.swift      与重构前固定种子结果对照
├── GameEngineTests.swift              基础游戏机制检查
├── EventLibraryTests.swift            事件库及规则检查
├── InvestmentEventTests.swift         投资流程、延迟结算与存档检查
├── CelebrityEventTests.swift          合影触发、售价、重复领取、增益与存档检查
└── CelebrityActingTests.swift         龙套、盒饭、十周分红与旧档恢复检查

Package.swift                         不启动界面即可运行核心测试
tools/content/validate.py              检查配置错误、引用、ID 等
docs/                                 设计说明与编写指南（节选）
├── PROJECT-FILES-GUIDE.zh-CN.md       本文件：机制与文件地图
├── CELEBRITY-INTERACTIONS-DESIGN.md    名人分类、人物名单与实施边界
└── CHEN-SANTA-MONICA-EVENT.md          陈冠希事件故事、数值和验证结果
```

文件夹的分组不等于互斥的游戏类别。比如健康事件可以同时受到地点限制，所以 health.json 放在 locations 下并不矛盾。市场事件也可以按地点触发。

新增的名人分支有两个分工：characters/celebrities.json 管理“有哪些人物”；events/celebrities/ 下的文件管理“每位人物有哪些故事”。投资只是名人交互的一种玩法，同一人物以后可以有多个不同玩法的事件。

原 npcs/ff-investment.json 已迁至 celebrities/jia-yueting.json，加载清单同步更新，保留原事件编号与存档兼容。

## 3. 内容配置中，几个容易混淆的文件

### manifest.json：告诉游戏到哪里找内容

它相当于书的目录。只有把新的内容文件加入加载清单，游戏才知道应该读取它。往一个已经登记的事件文件中添加事件，通常不需要再修改清单。世界事件的抽取周期等配置也从这里进入。

### 各类事件 JSON：告诉游戏有哪些故事和参数

例如 jia-yueting.json 负责描述贾跃亭事件的地点限制、邀请参数、投资下限、结算间隔，以及使用哪几段故事文本。它通过当前已经支持的字段表达玩法。

JSON 本身不会扣钱，也不会自动创造一个新机制。它写出的规则，需要引擎认识并执行。

### zh-Hans.json：告诉游戏向玩家说什么

故事标题、正文、选项等文本集中放在这里。事件通过稳定的文本编号引用文案。只润色故事、保持编号不变，通常可以只改这一个文件。

运行所需的隐藏数值与玩家文案分开。例如投资结算的抽取参数属于事件配置，不应自动写进玩家的故事描述。

### EventContentCatalog.swift：真正把文件读进游戏

清单描述“读哪些文件”，内容加载器负责“去读这些文件、找到文案、检查引用并供其他代码查询”。两者分工不同，因此都需要存在。

## 4. 用一次贾跃亭投资解释完整流程

1. **玩家在罗兰岗推进回合。** TurnEngine.swift 更新本局状态，再由 SessionEventEngine.swift 调用事件机制。
2. **检查是否能遇到邀请。** InvestmentEventEngine.swift 读取 jia-yueting.json 对应的已加载定义，检查地点、触发机会、是否遇到过及剩余回合等要求。可组合的附加条件使用 EventCondition.swift。
3. **邀请等待玩家处理。** GameModels.swift 所表示的本局状态记住待处理邀请；GamePresentation.swift 统一安排它与其他弹窗的显示顺序。
4. **玩家看到故事并输入金额。** InvestmentEventOverlay.swift 显示 zh-Hans.json 中的文案，接收投资或拒绝操作。
5. **引擎验证并记账。** 投资机制检查金额是否合法；接受时扣除本金，记录未来结算时间及已经确定的结果。拒绝也会被记录，避免同一邀请反复出现。
6. **投资后的第 10 个回合结算。** 即使玩家已经离开罗兰岗，引擎仍处理到期投资，返还相应金额并加入结果通知队列。
7. **退出再进入仍能接着玩。** 存档保存邀请、待结算投资和未读通知，避免重复扣钱或重复领取。

这条投资流程有专门的 InvestmentEventEngine.swift。目前不应把它理解成“所有事件都已经支持任意延迟、任意选项、任意结果”的通用事件链系统。

## 5. 各种游戏机制主要去哪里看

| 想理解或调整的功能 | 首先查看 | 同时可能涉及 |
| --- | --- | --- |
| 地点、地区内容 | Domain/DistrictCatalog.swift | 地图界面、地点事件条件 |
| 商品、基础内容 | Domain/GameContent.swift | TradingEngine.swift、市场界面 |
| 交易、银行、报价 | Engine/Actions/TradingEngine.swift | GameModels.swift、市场界面 |
| 打工、躺平、地区投资 | Engine/Actions/WorkEngine.swift | 地区工作配置、增益 |
| 诊所、按摩、仓储 | Engine/Actions/CityServicesEngine.swift | GameBalance 数值 |
| 住房、车辆、物业、驾照 | Engine/Actions/EquipmentEngine.swift | GameBalance、LifeEquipment |
| 推进回合、结算到期效果 | Engine/Turns/TurnEngine.swift | 各专用机制引擎 |
| 结束游戏、资产结算 | JourneySettlementEngine.swift | JourneyResult.swift |
| 某个健康或金钱事件的数值 | 对应 locations/*.json | zh-Hans.json |
| 增加已有类型的世界事件 | world/economy.json | zh-Hans.json、内容检查工具 |
| 世界事件隔多久抽一次 | manifest.json | WorldEventScheduler.swift |
| 运气如何偏向好事或坏事 | EventSelection.swift、WorldEventScheduler.swift | 事件倾向、强度及权重配置 |
| 多个世界事件共同影响工资或价格 | WorldEventModels.swift、SessionEventEngine.swift | WorkEngine.swift、TradingEngine.swift |
| 某事件是否满足复杂条件 | EventCondition.swift | 事件 JSON 中配置的条件 |
| 普通事件如何加钱、扣健康或改价格 | EventEffect.swift、EventEffectExecutor.swift | 事件 JSON |
| 投资多少、何时结算 | jia-yueting.json、InvestmentEventEngine.swift | InvestmentEventModels.swift |
| 弹窗出现顺序 | GamePresentation.swift | GameStore.swift、各种 Overlay.swift |
| 关闭游戏后能否继续 | ProfilePersistence.swift、GameSnapshotMigration.swift | GameModels.swift、相关机制测试 |

“普通事件改变价格”和“世界事件持续影响经济”目前属于不同执行路径。它们都影响玩家体验，但不能假定修改一个效果文件就会改变全部机制。

## 6. 已实现与未来设计的边界

已经实现的基础包括：配置化事件内容、独立中文文案、组合条件、类型明确的普通效果、世界事件周期抽取与运气权重、多个不同世界事件同时生效、通知队列，以及名人投资延迟结算、抵达时的确定性合影、个人限时增益和合照相册。

以下仍需要后续设计和开发：

- 完整 NPC 关系状态，以及关系和运气共同影响协助或困扰。
- 把已实现的个人限时增益接入更多事件类型，并按需求增加新的效果种类。
- 任意事件安排未来事件、跨多个选项推进的通用故事链。
- 主动聊天、送礼、请求帮助等 NPC 交互界面。

当前多个世界事件的相关倍率采用相乘方式合并；同一个世界事件定义在生效期间不会再次抽中。个人增益目前按独立实例计时：运气和每回合健康相加、工资倍率相乘。以后新增属性时仍需明确自己的叠加规则。

名人名册和投资、合影、片场三种交互玩法已实现，完整 NPC 关系系统仍未实现。

## 7. 以后我们如何一起改

每次先用日常语言回答四件事：

1. **什么时候发生？** 例如“只在罗兰岗、第三阶段以后、与这个人关系好时”。
2. **玩家能做什么？** 例如“接受帮助、支付一笔钱，或者拒绝”。
3. **会留下什么结果？** 例如“当场加钱、连续三回合多拿工资，或者十回合后再来消息”。
4. **多次发生怎么处理？** 例如“每次都叠加、只延长时间，还是一局只发生一次”。

然后再决定需要改哪层：

| 改动举例 | 通常改动范围 |
| --- | --- |
| 把烤串故事写得更有趣 | 文案 |
| 调整现有投资事件的结算间隔或回报参数 | 内容配置；检查待结算记录的兼容行为 |
| 在已有条件体系内限定地点、回合、运气 | 内容配置 |
| 新增一种带独立行为的效果 | 效果定义、执行器、内容校验与相关测试 |
| 新增“关系值”并据此触发帮助 | 状态、条件、关系更新机制、内容、存档；需要展示时再增加界面 |
| 新增持续三回合且能叠加的个人增益 | 已支持运气、逐回合健康与打工倍率；新属性仍需扩展类型与执行机制 |

我们先落实玩家会经历什么，再把确定下来的规则落到相应文件。不要仅因为新增一个故事，就先增加一种新的引擎。

## 8. 文档入口

- EVENT-CONTENT-AUTHORING.md：当前事件配置支持什么、怎样编写。
- ARCHITECTURE.md：现有程序各层如何连接。
- WORLD-EVENTS.md：世界事件规则。
- FF-INVESTMENT-EVENT.md：贾跃亭事件的具体实现和边界。
- CELEBRITY-INTERACTIONS-DESIGN.md：名人交互类别、人物名单及实施状态。
- CHEN-SANTA-MONICA-EVENT.md：陈冠希合影、增益、售价与验证范围。
- NPC-EVENTS-DESIGN.md：NPC 系统设计；包含尚未实现的部分。
- EVENT-LIBRARY-DESIGN.md：事件库整体设计；阅读时注意实施状态与目标设计的区别。
- generated/event-catalog.md：生成的事件目录，用于查阅；事件修改应回到源配置。

文档描述规则与意图；游戏实际运行读取的是内容配置和程序代码。只修改设计文档不会改变游戏行为。

## 9. 新确认的分类：名人交互事件（2026-09-08）

用户确认：贾跃亭投资应归入“名人交互事件”类别，徐静蕾、陈冠希也将加入此类别。一个人物可以有多个故事，投资只是其中一种玩法。

人物名册、事件类别和交互玩法需要分别管理。例如“名人交互／贾跃亭／投资”表达了三个不同信息，未来徐静蕾和陈冠希不必复用投资玩法。

具体设计与目标目录记录在 CELEBRITY-INTERACTIONS-DESIGN.md。第 2 节文件树已更新为实施后的结构：名册、贾跃亭投资和陈冠希合影已接入，徐静蕾的故事文件仍待设计。

## 10. 这次整理后，新增机制放在哪里

把一回合想成一次统一结账：先把周次推进，再结算利息、到期投资、电影分红、个人增益和生活费用，最后抽取这一周的新事件。以前旅行、原地过周、跳过几周各有一段类似代码；现在这些都经过 TurnEngine.swift。将来增加“每回合扣学习费”，只需在这条流水线接入一次，三种推进方式就都会执行。

事件生效与弹窗展示是两件事。多个增益仍然同时生效，但窗口一次展示一个。GamePresentation.swift 负责选出当前窗口，关闭后再读取下一个待处理事件。待选剧情会阻止交易、过周、服务消费与最终清算；普通已结算通知不会重复发放奖励。

以后新增一个同类型的名人合影，主要编辑人物故事 JSON 和中文文案；新增一种完全不同的交互，例如“共同经营店铺”，才需要定义店铺状态、经营结算和对应界面。完整 NPC 好感度与任意事件链仍是后续项目，不会因为这次拆分自动出现。

开发者可以在项目根目录运行 `swift test --jobs 4` 检查核心规则；原生 iOS 界面和插图仍通过 Xcode 检查。详细验证范围见 [本次架构整理记录](ARCHITECTURE-REFACTOR-2026-09-09.md)。


## 11. 吴宇森的事件放在哪里

参见 [吴宇森片场事件](WU-YU-SEN-HOLLYWOOD-EVENT.md)。`wu-yu-sen.json` 是剧本参数表，`CelebrityActingEngine.swift` 负责发片酬、扣体力和登记未来分红，`TurnEngine.swift` 每次过周检查是否上映，`CelebrityActingOverlay.swift` 只负责让玩家选角色、读消息。片酬不会因为多打开一次窗口就再发一遍。
