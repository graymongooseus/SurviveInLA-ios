# 事件库开发指南

当前内容版本：`2026.09.06.2`。以下是已实现的格式；`EVENT-LIBRARY-DESIGN.md` 中的早期示意不是可直接加载的格式。

## 从哪里改内容

```text
SurviveInLA/Resources/Content/
├── manifest.json                     内容文件顺序、世界抽取周期、人生阶段
├── events/
│   ├── locations/market.json          市场事件
│   ├── locations/health.json          健康事件
│   ├── locations/money.json           钱财事件
│   ├── world/economy.json             世界事件及持续修正
│   ├── life-choices/choices.json      人生选择
│   └── npcs/ff-investment.json        人物投资邀请与延迟回款
└── localisation/zh-Hans.json          中文文本
```

75 条既有事件已迁移到这些文件，另新增 1 条 FF 人物投资事件。数组顺序由 manifest 和文件内容决定；文件名不决定触发顺序。新增主题可以增加文件并登记到对应清单，不能复制同一个 ID。

已发布的世界事件下架时，将 `selection.baseWeight` 设为 0，并保留定义、文本和素材，以便旧存档仍能显示活动事件与历史通知。删除或重命名已发布 ID 需要另写迁移，不能直接移除。

市场/健康/钱财目前保留旧分类以兼容展示；同一事件可以通过 `effects` 同时改变多个属性。世界事件是单独的持续效果类型；地点限制与事件分类是不同维度。

## 世界事件如何抽取

manifest 中当前配置：

```json
{
  "worldSchedule": {
    "firstWeek": 5,
    "intervalWeeks": 4,
    "occurrenceChance": 1,
    "luckScale": 3
  }
}
```

第 5、9、13……49 周抽取。每个触发周判定一次；即使没有候选或概率未通过，也会记录本周已检查，读档或重复调用不会再抽。同一事件持续期间不重复进入候选；不同事件可以重叠。进入第 52 周后执行既有终局规则，不新增事件。

`occurrenceChance` 是整个池是否发生事件的概率，目前为 1。`selection` 是通过条件后各事件的相对权重：

```json
{
  "selection": {
    "baseWeight": 1,
    "favorability": "favorable",
    "strength": 3
  }
}
```

`favorability` 为策划给出的 `favorable`（有利）、`mixed`（混合）、`unfavorable`（不利）；`strength` 为 1～3。它是整体收益评级，不能把所有倍率机械相加。初始评级在世界事件 JSON 与生成的总表中，可根据试玩调整。

运行时先排除未满足条件和正在持续的事件，再按以下公式计算权重并抽取一个：

```text
运气位置 = (限制到 0～100 的运气 - 50) / 50
方向 = 有利 +1，混合 0，不利 -1
权重 = baseWeight × luckScale ^ (方向 × strength × 运气位置)
候选内概率 = 该事件权重 / 合格候选权重之和
```

运气 50 时权重等于基础权重；运气 100 时三级有利事件权重是 27，一级有利事件为 3；运气 0 则反向偏向负面事件。混合事件权重不直接随运气变化，但其归一化后的份额仍会受其他候选权重影响。基础权重为 0 的事件不会被抽到。

实际结算继续使用原有八个统计项。多个活动事件的同类倍率相乘，投资回报上限取最严格的上限；在原有计算阶段取整。工资修正不作用于罚款，利息修正不直接改变本金。活动实例保存当次修正值，后续调整 JSON 不会改写已经生效的那次修正。

已确认的产品要求是“多个事件与增益共存，弹窗展示，各种增益叠加”。当前世界通知按队列逐个展示；效果在事件激活时参与结算，关闭弹窗只确认已读，不会重新施加效果，也不会移除仍在持续的增益。以上倍率相乘和同一事件不重复抽取描述当前代码；百分比合并方式及同种增益重复获得策略仍待进一步确认。

例如净收入 300，世界修正分别 ×1.20、×0.85，合并后入账 306。一个事件第 5 周触发、持续 4 周，则第 5～8 周有效，第 9 周开始失效。跨周利息仍按离开上一周时的修正结算。

## 条件是只读的组合

地点、世界、人生选择都支持可选 `condition`。不填写即没有额外限制。以下完整条件表示：运气至少 60，且有住处：

```json
{
  "all": {
    "conditions": [
      {"metric": {"name": "luck", "comparison": "atLeast", "value": 60}},
      {"equipment": {"item": "housing"}}
    ]
  }
}
```

词表：

| 条件 | 参数 |
|---|---|
| `all` / `any` | `conditions` 数组 |
| `not` | `condition` 对象 |
| `metric` | `name`、`comparison`、整数 `value` |
| `district` | 地点 `id`，判断事件所处地点 |
| `equipment` | `item` |
| `worldEventActive` | 世界事件 `id` |
| `choiceResolved` | 人生选择 `id` |
| `choiceSelected` | `eventID` 与 `optionID` |

数值可选 `week/cash/bank/debt/health/luck/availableCapacity`；比较可选 `equal/atLeast/atMost`；装备状态可选 `housing/vehicle/activeDriversLicense/tools/property/hope`。有效驾照会考虑丢失后的恢复周数。

条件判断不抽随机数、不扣款、不改变状态。全体地点候选均不合格时，返回平静的一周，不崩溃。地点池默认保留原有“运气决定好/坏/混合类别，再在类别中抽取”的行为；个别事件可再设置 `selectionWeight`，格式同世界事件的 `selection`。

旧字段 `triggerChance` 只供现有菲格罗亚打工事件专用入口使用，不能用来定义新地点随机事件的概率。新地点事件使用 `condition` 和 `selectionWeight`；新的动作触发入口需要在引擎中明确接入。

从本版本开始，人生选项的实际 ID 会写入存档，可以被后续条件引用。旧存档中未记录的选项不根据故事文字推测补写。既有选项 ID 保留，调整选项排列时不能重命名它。

## 一次性效果

既有事件的 `cashDelta` 等字段继续兼容。新地点事件可使用 `effects` 数组，依次执行多个效果：

```json
[
  {"cash": {"amount": 100}},
  {"health": {"amount": -3}},
  {"luck": {"amount": 2}},
  {"grantCommodity": {"commodityID": "camera", "quantity": 1}},
  {"marketPrice": {"commodityID": "camera", "multiplier": 1.2}}
]
```

采用显式 `effects` 时，把兼容必填字段 `cashDelta/healthDelta/reputationDelta` 设为 0，不再混写旧商品效果；同时指定 `encounterTone`。这些零值是现有存档/卡片模型的兼容边界，实际执行与提示都以 `effects` 为准。

`marketPrice` 调整当前市场已有的商品报价；商品不在当前市场时跳过，不自动补货。显式效果不能混写打工收入或跳周元数据；这些特殊动作仍由各自入口结算。

现金损失仍会扣到零，健康与运气限制在 0～100，赠品受仓储容量约束。此处现金损失不是“必须有足够现金才能选”的支付条件；通用选项代价、随机选项结果和个人持续修正尚未实现，不应把它们伪装成一次性现金效果。

## 文本、图片与验证

事件使用 `titleKey/messageKey`；人生选择使用 `titleKey/storyKey`，选项使用 `titleKey/resultKey`。实际文字只放在 `localisation/zh-Hans.json`，加载后生成玩家看到的卡片。新增语言和动态占位符替换尚未接入。

世界图片通过 `imageName` 引用 Asset Catalog。既有健康卡片继续使用 `Event_<事件ID>` 的资源约定，保证原图和旧存档兼容。

每次 Xcode 构建会先执行内容校验，也可以手动运行：

```sh
python3 tools/content/validate.py
python3 tools/content/validate.py --export-catalog
python3 tools/content/validate.py --world-weights 80
```

权重报告假设所有事件合格且没有活动事件，并明确说明这个前提。生成的 `docs/generated/event-catalog.md` 用来查阅；请修改 JSON 后重新生成，避免人工维护两套数值。

构建校验检查重复 JSON Key/ID、未知字段、文本、图片、条件引用、枚举 ID、权重与数值。Swift 加载器负责类型解析、语义约束和跨内容引用检查。缺失内容会使开发构建明确失败，不会静默换成空事件库。

## 代码职责与扩展边界

| 位置 | 职责 |
|---|---|
| `Domain/Events/EventModels.swift` | 兼容旧存档的事件卡片与人生选择模型 |
| `Domain/Events/EventEffect.swift` | 一次性效果词表、旧字段适配、效果提示 |
| `Domain/Events/EventCondition.swift` | 各类事件共用的只读条件 |
| `Domain/Events/EventSelection.swift` | 策划收益评级与通用权重抽取 |
| `Domain/Events/EventContentCatalog.swift` | 内容加载、校验与按 ID 查询 |
| `Engine/Events/EventEffectExecutor.swift` | 效果执行、边界与实际变化记录 |
| `Engine/Events/WorldEventScheduler.swift` | 世界事件周期、资格、重复限制与激活 |

新增现有词表能表达的事件只需修改内容文件；新增机制才扩展类型、执行器、校验和测试。NPC 方向已确认：阶段、运气和与具体人物的关系共同影响协助或困扰事件；扩展规格见 [NPC、关系与阶段事件](NPC-EVENTS-DESIGN.md)，完整 NPC 关系玩法尚未接入。当前已加入带 `sourceNPCID` 的人物投资事件：`investmentEventFiles` 登记内容文件，支持地点限定、金额选择和延迟回款；具体规则见 [FF 投资事件](FF-INVESTMENT-EVENT.md)。长期任务和新的时间单位继续按具体玩法需求确定。

快照已升级到 v4，兼容读取 v1～v3。投资邀请、已回应记录、待回款和未读通知均存档；赔率和结算时间不自动生成到邀请文案中。旧 `activeWorldEvent` 存档键保存最新事件，`additionalWorldEvents` 保存其余事件；运行时统一通过 `activeWorldEvents` 访问，不在两个字段中复制同一个实例。未读世界通知会存档，读档只恢复通知，不重复施加效果。快照还记录生成时的内容版本，不能仅凭这个版本号声称可以跨版本完全重放。
