# 系统架构

更新：2026-09-09。以下描述已经接入的代码；非程序开发者可先读 [游戏机制与文件地图](PROJECT-FILES-GUIDE.zh-CN.md)。

## 分层与依赖

```text
App → SwiftUI Views → GameStore → GameEngine → GameSession
                         │           │              ↑
                         │           └─ EventContentCatalog
                         │                ↑
                         │         Content JSON + 本地化文案
                         ├─ GamePresentation（选出当前窗口）
                         └─ ProfileRepository ↔ 本地文件 / iCloud KVS
                                  ↓
                          GameSnapshotMigration（旧档恢复）
```

| 层 | 已实现的职责 |
|---|---|
| App | 应用生命周期、档案选择与根页面 |
| UI | 地图、交易、服务、日记、世界事件、人生选择、名人交互、相册、结局、排行榜和内购展示 |
| Store | 接收玩家意图、调用规则、展示错误、协调弹窗、保存进度与排行榜/内购交付 |
| Engine | 交易、工作、地区投资、医疗、装备、回合、事件、增益与旅程清算 |
| Domain | 本局状态、数值、内容定义、组合条件、效果、人物和活动实例 |
| Resources/Content | 77 条事件、人物登记、文案、事件清单与抽取周期 |

规则层不导入 SwiftUI；美元文案格式位于 Domain/CurrencyFormatting.swift。GameSession 是一局游戏的真实状态，GameEngine 持有种子随机数与平衡参数。引擎按机制分成同一类型的扩展，Store 仍通过一个 GameEngine 调用；不需要为每个文件维护独立实例或重新传递随机数。

## 引擎内部的分工

| 文件 | 负责什么 |
|---|---|
| GameEngine.swift | 初始化引擎和新游戏、持有随机数状态 |
| GameActionRules.swift | 统一检查待处理选择、行动次数和金额 |
| Actions/TradingEngine.swift | 商品交易、银行存取款、还债和市场报价 |
| Actions/WorkEngine.swift | 打工、躺平、地区投资和工作风险 |
| Actions/CityServicesEngine.swift | 诊所、按摩、仓储升级 |
| Actions/EquipmentEngine.swift | 驾照、租房租车、工具、物业和生活费用 |
| Turns/TurnEngine.swift | 旅行、原地过周、跳过多周共用的结算流水线 |
| Events/SessionEventEngine.swift | 地点事件、人生阶段和专用事件机制的衔接 |
| Events/WorldEventScheduler.swift | 周期抽取、运气权重、世界实例激活与未读队列 |
| Events/InvestmentEventEngine.swift | 名人投资邀请与到期回款 |
| Events/CelebrityEventEngine.swift | 实际抵达时的名人合影、照片与出售 |
| Events/PlayerBuffEngine.swift | 个人增益实例、逐回合结算和到期 |
| Events/EventEffectExecutor.swift | 一次性金钱、健康、运气和市场效果 |
| JourneySettlementEngine.swift | 库存和车辆清算、机票支出、最终结局 |

跨文件共用的引擎方法采用模块内访问级别；文件内辅助函数继续 private。UI 不应直接调用这些共用方法或消耗随机数。

## 唯一的回合流水线

1. 验证是否存活、是否还有待处理选择，以及当前行动是否允许过周。
2. 保存离开本周时的世界修正，推进一周；旅行同时更新地区。
3. 依次结算旧周利息、到期投资、个人增益、装备和生活费用，重置每周行动。
4. 若健康归零，停止推进，不再抽取事件；多周跳过也在此停下。
5. 仅实际旅行调用名人抵达检查。
6. 到达最终周时，先处理剩余选择，再清算；不再抽普通世界和地点事件。
7. 非最终周更新世界事件、市场和地点遭遇，再安排人生阶段与投资邀请。

为了保持旧存档的随机序列，旅行仍然先抽地点事件再生成市场；原地过周先生成市场再抽事件；跳过周数不抽普通地点事件。三个入口共享结算步骤，不强行统一它们原本不同的玩法。

世界事件从第 5 周开始每 4 周抽取，抽取配置在 manifest 中。不同事件可以同时生效，同一事件定义生效期间排除重复。世界倍率相乘、回报上限取最严格值；个人运气和健康加成相加，工作倍率相乘，每个个人增益实例独立计时。跨周利息按离开上一周时的世界修正结算。

新增每周机制，应在这条流水线上接入一次，并覆盖旅行、原地和跳过周数的测试。新增已有类型的故事，继续使用 JSON，不修改回合流程。

## 事件、状态和弹窗

内容定义来自清单指定的文件顺序，不依赖目录枚举。EventCondition 只读资格，EventSelection 决定权重，执行器才修改数值。世界活动实例冻结修正与起止周，投资实例冻结本金、结算回合与结果，合影实例冻结选项和照片售价。

PendingInteraction.swift 统一描述当前待处理选择，优先级为人生选择、投资邀请、名人合影。普通行动与最终清算使用同一阻塞规则。

GamePresentation.swift 只选择当前展示类型，不执行效果，也不移除队列。主页面和普通 alert 都按该结果展示，底层地图和操作在弹窗期间禁用点击。当前展示顺序：

- 开场、购买奇遇、世界通知、普通/健康/选择结果通知。
- 等待旅行通知的短暂动画结束。
- 人生选择、投资回款通知/邀请、名人合影。
- 所有可读通知处理后展示结局；已结束游戏不再展示未完成的选择。

世界、投资和名人交互各自的队列保存在 GameSession 中。普通提示与当前窗口状态仍由 GameStore 管理，并非所有 UI 通知都能跨退出恢复。后续若要求保存每一条普通通知，需要另行定义通知实例与迁移规则。

## 存档与开发验证

ProfileRepository 管理三个槽的本地 JSON、原子写入、历史旅程和 iCloud KVS。GameSnapshotMigration 负责旧版本转换与缺省状态；本地、云端和 GameStore 恢复使用相同的状态恢复方法。v5 继续兼容 v1～v4，保留随机数检查点、已选记录、事件队列、照片和增益。此次结构整理不改变存档格式，也不改变事件内容版本。

较新的 updatedAt 决定云端冲突处理；删除写入云端墓碑。旅程记录独立于可覆盖的存档槽。排行榜与内购已有实现，此次没有修改它们的协议或服务端。

在 macOS 项目根目录运行 `swift test --jobs 4`，可独立测试 Domain、Engine、Store。Package.swift 排除 UI、App 和图像资源，内容加载器自动选择 SwiftPM 资源包。Xcode 继续构建完整 iOS App，并执行包括 UIImage 插图校验在内的原生测试。`python3 tools/content/validate.py` 校验事件与插图；明确传入 `--data-only` 时仅检查配置。

本次验证记录见 [架构整理记录](ARCHITECTURE-REFACTOR-2026-09-09.md)。

## 已保留的扩展边界

名人类别已包含贾跃亭投资、陈冠希合影，徐静蕾只有人物登记。完整 NPC 好感关系、任意延迟事件链、新增持续效果、主动聊天和经营机制仍按实际玩法逐步开发，不建立尚未使用的脚本运行时或插件系统。

详细内容格式见 [事件编写指南](EVENT-CONTENT-AUTHORING.md)，未来人物关系方向见 [NPC 事件设计](NPC-EVENTS-DESIGN.md)。
