# 2026-09-09 架构整理记录

本次把已实现的游戏机制整理到新的文件树，并修复事件增多时暴露出的联动问题。故事、人物、事件 ID、收益参数、运气阈值和 v5 存档字段保持原样。

## 已完成

- GameEngine 从集中实现整理为初始化入口，加上交易、工作、服务、装备、事件、回合和结局的扩展文件。Xcode 的 Domain/Events、Engine/Events、Engine/Actions、Engine/Turns 分组与磁盘一致。
- TurnEngine 收拢三处重复的跨周结算，所有跨周都处理利息、到期投资、个人增益和装备费用。
- PendingInteraction 统一动作阻塞。仓储升级也必须等待当前选择完成；最终清算会等待所有待处理选择。
- 多周跳过遇到人生选择后停止，并重置旧周行动；持续减益导致健康归零后停止后续推进和抽取。
- GamePresentation 统一主界面与 alert 的展示顺序，保证同一时刻只有一种阻塞弹窗，已有事件队列继续逐个显示。
- GameSnapshotMigration 统一旧档恢复、世界修正冻结和服务随机种子缺省值。
- 美元格式从 SwiftUI 主题移到 Domain，核心规则不再依赖 UI 文件。
- Package.swift 提供无需加载 App 界面的核心测试入口；不引入第三方依赖。

## 如何验证

```sh
swift test --jobs 4
python3 tools/content/validate.py
```

如果仅检查内容配置，可明确使用 `python3 tools/content/validate.py --data-only`；该模式不验证插图。

本次实际结果：

- 147 项核心测试：145 项通过，2 项跳过，0 项失败。跳过的是需显式开启的真实排行榜服务测试，以及 macOS 不支持的 UIKit 插图测试；iOS 目标中的插图断言保留。
- 新增 8 项跨机制测试与 1 项固定种子回放测试。三组种子对照重构前的市场报价、事件结果、资金、健康、运气和随机数检查点，一致。
- 全部 App Swift 源码通过 Swift 6 / iOS 18 模拟器目标类型检查。
- 77 条事件、256 条文本引用通过配置校验；Content 下文件逐字节保持原样。
- Xcode 工程语法、Swift 文件引用和编译成员检查通过，每个源文件恰好登记一次。

Google Drive 仍有未下载的源文件及图片占位项。本次使用与本地元数据核对一致的源代码副本，在独立目录执行测试，再将改动写回项目。未进行完整 iOS 打包、插图校验或模拟器点击验收；这些需要资源下载恢复后在 Xcode 完成。核心测试通过不代表这些项目已经验证。

## 后续设计

扩展现有事件时，优先修改 JSON 与文案。新增每回合结算机制时，在 TurnEngine 接入一次；新增交互时，为它定义存档状态，并在 PendingInteraction 与 GamePresentation 中登记。完整 NPC 好感关系和通用事件链仍未实现。

文件用途和实际目录见 [机制与文件地图](PROJECT-FILES-GUIDE.zh-CN.md)。
