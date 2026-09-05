# Surviving LA 1.0 (2) 变更记录

记录日期：2026 年 9 月 4 日

## 本次构建范围

- 正式显示名称统一为 `Surviving LA`，Bundle ID 保持 `com.graymongooseus.SurviveInLA`。
- 版本设为 `1.0`，Build 设为 `2`。
- 初始现金统一调整为 `$1,000`，初始债务保持 `$5,000`。
- 明确每周赚钱规则：倒卖、打工、投资只能选择一种；打工与投资每周各只能执行一次；倒卖允许同周多笔买卖，前往新地点后进入下一周。
- `GameStore` 与 `ProfileRepository` 统一负责完成旅程的历史归档和排行榜读取。
- 加入并接通结算页、旅程记录、冒险商店、StoreKit 商品模型与对应视图。
- 更新冒险商品命名和表现，包括“便利店乐透刮刮卡”与匿名手机券商平台。
- 新增七类世界事件、事件弹层、全局数值修正及配套图片资源。
- 更新首页、商店、档案选择和城市服务界面。
- 更新 App Store 元数据、隐私政策、支持文档、内购文档和发布清单。
- 明确独立 Swift App 与 GPL-2.0 历史源码归档之间的许可边界。

## 验证记录

- `xcodebuild test`
- 设备：iPhone 17 Pro Simulator，iOS 26.3.1
- 结果：35 项测试通过，0 失败
- 覆盖重点：初始资金、每周行动互斥、投资单周限制、市场交易、结算、存档与旅程历史、世界事件。
- `xcodebuild archive`：Release Archive 成功，Bundle ID 为 `com.graymongooseus.SurviveInLA`，版本为 `1.0 (2)`。

## 上传前仍需人工完成

- 在 Xcode Organizer 中执行 Validate App 和 App Store Connect Upload。
- 在 App Store Connect 创建并审核四项消耗型内购。
- 补齐截图、版权人与 App Review 联系信息。
- 在至少一台真机完成完整冒烟测试。
