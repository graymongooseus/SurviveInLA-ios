# App Store 元数据草稿

## 基本信息

- 名称：洛杉矶浮生记
- 副标题：在南加州用 52 周翻身
- 主分类：游戏
- 子分类：模拟、策略
- 关键词：洛杉矶,生存,模拟,策略,交易,经营,单机,地图,买卖,人生

## 促销文本

从丁胖子广场出发，在 52 周内穿梭南加州，靠交易、打工与投资还清债务，写下属于你的洛杉矶生存日记。

## 应用描述

《洛杉矶浮生记》是一款虚构的单机生存与交易策略游戏。

你将在 52 周内穿梭于洛杉矶及南加州的 15 个地点，观察不同市场的价格变化，在倒卖、打工和投资之间做出选择。现金、债务、健康、库存和随机事件会共同改变每一局的走向。

游戏特色：

- 15 个具有不同价格倾向的南加州地点
- 倒卖、打工、投资三种每周行动
- 银行、诊所、仓储和主动还债等城市服务
- 随机事件与可回看的生存日记
- 三个独立的本地存档
- 可选 iCloud 存档同步
- 四种可选的消耗型“奇遇”内购
- 无广告、无开发者账号，核心游戏可离线游玩

本作所有交易、货币和情节均为虚构游戏内容，不代表真实商品交易或财务建议。

## App Review Notes

This is a fictional, single-player survival and trading strategy game. It contains optional consumable in-app purchases that trigger one fictional in-game event per purchase. It has no developer accounts, ads, analytics, tracking, or developer-operated backend. Saves are stored locally by default; players can opt in to sync saves through Apple's iCloud key-value store. MapKit displays a public map and the app does not request or use the user's location.

To begin testing, select any of the three profile cards, create a new game, and use the bottom action bar to switch among Market, Work, and Investment. City services are available from the Services button. The sparkle button opens the Adventure Shop. No developer sign-in or review account is required.

The source code and GPL-2.0 license information are available at:
https://github.com/graymongooseus/SurviveInLA-ios

## TestFlight — What to Test

请重点测试：

1. 新建三个 Profile、退出后继续游戏以及删除存档。
2. 买卖、移动、打工、投资和城市服务是否正确消耗每周行动。
3. 开启 iCloud 同步后，同一 Apple Account 的另一台设备能否取得最新存档。
4. 奇遇商店四个消耗型商品的 Sandbox 价格、成功发奖、取消、待批准和重启后补发。
5. 健康归零与第 52 周结局、排行榜、历次旅程以及重新开始。

反馈时请附上 iPhone 型号、iOS 版本、App 版本 `1.1 (2)` 和复现步骤。

## 提交前仍需填写

- 版权：请由账号持有人确认法定名称后填写，例如 `2026 [权利人名称]`。
- 隐私政策 URL：发布仓库更新后使用 `docs/PRIVACY.md` 的公开链接。
- 支持 URL：发布仓库更新后使用 `docs/SUPPORT.md` 的公开链接。
- 联系人姓名、电话和邮箱：填写能及时回复 App Review 的真实联系方式。
- 年龄分级：根据最终保留的商品、事件和边境叙事如实回答新版问卷。
- App 内购买：在 App Store Connect 建立并配置 `docs/IAP.md` 列出的四个消耗型商品。
