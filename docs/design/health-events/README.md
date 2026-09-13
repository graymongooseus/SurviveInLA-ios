# 健康事件油画卡片

18 个事件已接入原生 `HealthEventOverlay`，目前包括 17 个健康事件，以及改为钱财事件的“高速堵死”。插图采用确认的深海军蓝／炭黑／珊瑚光印象派油画模板，标题、基础效果、剧情和“知道了”按钮均为原生 SwiftUI。

- [全部卡片截图](gallery.html)
- [事件与数值清单](manifest.json)
- [确认稿与实现对照](comparison-final.jpg)
- [生成提示词 A](prompts-a.md) · [生成提示词 B](prompts-b.md) · [生成提示词 C](prompts-c.md)

## 素材与数据

`art/` 保留 18 张独立生成的 1536×1024 PNG；`references/` 保留用户确认的前三个完整弹窗方案。模板原文件未修改。全部素材通过 built-in ImageGen 生成。

游戏中的 `Assets.xcassets/Event_<稳定事件ID>.imageset` 使用 1536×1024、88% JPEG（共约 10 MB），避免把原始大 PNG 全部放进安装包。每张图片只负责场景；不会将文字或按钮烘焙进游戏图片。

插图映射由稳定事件 ID 计算，不增加存档必填字段。健康／现金基础值及剧情仍来自 `LocationEventCatalog.events`，地点和触发概率保持原规则。现金没有变化的两条事件明确显示“无变化”。

“高速堵死”现为误闯 Express Lane 后收到 $250 罚单，健康不变；沿用高速油画，卡片显示“钱财事件”和单列现金 −$250。画廊截图与原始绘画提示词保留制作时的版本。

## 通知行为

- 普通移动触发健康事件：保留移动后的短暂延迟，再显示完整卡片。
- 与世界事件同周触发：先展示世界事件，点击“知道了”后展示健康卡片，不重复结算。
- 健康归零：先展示导致归零的健康卡片，关闭后显示终局。
- 第 52 周直接结算不会重播上一周的健康事件。
- 大字号／较短视窗下正文区可滚动，“知道了”按钮固定在卡片底部。

## 原生预览

Debug 构建可设置环境变量 `HEALTH_EVENT_PREVIEW` 为清单中的事件 ID，启动即显示对应卡片。此预览使用无 Profile 的临时 GameStore，不写入玩家存档。Release 构建不包含该入口。

```sh
SIMCTL_CHILD_HEALTH_EVENT_PREVIEW=extreme-heat xcrun simctl launch --terminate-running-process <SIMULATOR_ID> com.graymongooseus.SurviveInLA
```

正常游戏无需任何环境变量；事件仍由旅行流程随机触发。
