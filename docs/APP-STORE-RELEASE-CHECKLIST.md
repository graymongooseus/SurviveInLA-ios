# TestFlight / App Store 发布清单

最后检查：2026 年 9 月 4 日

## 已通过的本地质量门

- [x] 使用 Xcode 26.2 / iOS 26.2 SDK 编译。
- [x] 最低部署目标为 iOS 17.0，仅支持 iPhone 竖屏。
- [x] 36 项游戏引擎、存档、终局与内购发奖测试全部通过。
- [x] Release 模拟器构建支持 iOS 17；未使用仅 iOS 26 可用的运行时 API。
- [x] Release 真机 Archive 构建成功，产物为 arm64，隐私清单已打包。
- [x] App 图标为 1024 × 1024 PNG，不含 alpha 通道。
- [x] App 显示名为“洛杉矶浮生记”。
- [x] Bundle ID 为 `com.graymongooseus.SurviveInLA`。
- [x] 版本号为 `1.0.0 (3)`。
- [x] 已加入隐私清单，声明 `UserDefaults` 的 app-only 使用原因。
- [x] 不使用第三方 SDK、广告、分析或用户追踪。
- [x] 不请求用户定位；MapKit 只展示公开地图。
- [x] 已声明不使用非豁免加密。

## 上传 TestFlight 前的账号配置

- [ ] 在 Xcode → Settings → Accounts 重新登录可访问 Team `5HL85C4694` 的 Apple Developer 账号；当前钥匙串凭据无效，IPA 导出因此失败。
- [ ] 在 Apple Developer 后台注册显式 Bundle ID：`com.graymongooseus.SurviveInLA`。
- [ ] 为该 App ID 启用 iCloud Key-value storage；确认 provisioning profile 包含相应 entitlement。
- [ ] 在 App Store Connect 新建独立 App 记录，不要上传到 `D·Diary: Life Coordinates`。
- [ ] 确认 App Store Connect 中不存在更高的 Build 号；若 Build 3 已用，继续递增。
- [ ] 确认 Apple Developer 协议均已签署。
- [ ] 完成 Paid Apps Agreement、税务和收款资料，否则内购无法完整测试或销售。
- [ ] 决定是否在欧盟发布；若发布，先补齐 EU trader status。

## App 内购买配置

- [ ] 按 [IAP.md](IAP.md) 建立四个 `Consumable` 商品，Product ID 必须逐字一致。
- [ ] 为每个商品填写简体中文显示名、说明、价格档位和审核截图。
- [ ] 确认商品在目标地区可售，并完成税务类别设置。
- [ ] 在真机 Sandbox 环境验证成功、取消、待批准、失败及中断后补发。
- [ ] 确认同一交易 ID 不会重复发奖。

## App Store Connect 建议值

| 字段 | 建议 |
|---|---|
| 平台 | iOS |
| 名称 | 洛杉矶浮生记 |
| 主要语言 | Chinese (Simplified) |
| Bundle ID | `com.graymongooseus.SurviveInLA` |
| SKU | `survive-in-la-ios` |
| 版本 | `1.0.0` |
| 主分类 | Games |
| 子分类 | Simulation / Strategy |
| 价格 | Free（包含可选消耗型内购） |
| 数据收集 | 开发者不收集数据；存档仅本地或由用户选择通过 Apple iCloud 同步 |
| 隐私政策 URL | `https://github.com/graymongooseus/SurviveInLA-ios/blob/master/docs/PRIVACY.md` |
| 支持 URL | `https://github.com/graymongooseus/SurviveInLA-ios/blob/master/docs/SUPPORT.md` |

## Archive、验证与上传

- [x] 使用 Release 配置对 `Any iOS Device (arm64)` 执行 Archive。
- [ ] 在 Xcode Organizer 中执行 Validate App，解决全部错误及重要警告。
- [ ] 选择 Distribute App → App Store Connect → Upload。
- [ ] 等待 App Store Connect 完成 Build Processing，并检查合规提示。
- [ ] 在 TestFlight 填写 What to Test、反馈邮箱和出口合规信息。
- [ ] 先分发给内部测试员；外部测试需要 Beta App Review。

## TestFlight 冒烟测试

- [ ] 全新安装：首次启动、三个 Profile、新建游戏和序章。
- [ ] 核心循环：买卖、移动、打工、投资、银行、诊所、仓储和还债。
- [ ] 终局：健康归零与第 52 周结算、排行榜和重新开始。
- [ ] 本地存档：杀进程、重启 App、删除 Profile。
- [ ] iCloud：关闭同步、开启同步、另一台同账号设备同步、冲突和删除同步。
- [ ] 内购：四个商品均能取得真实 Sandbox 价格并正确发奖。
- [ ] 异常交易：取消、Ask to Buy / pending、中断后重启补发、重复交易 ID。
- [ ] 在至少一台 iOS 17–18 真机和一台当前系统真机上检查布局与性能。

## 提交 App Review 前

- [ ] 上传 1–10 张无透明通道的 iPhone 截图，首图应展示真实游戏界面。
- [ ] 完成应用描述、副标题、关键词、促销文本、版权信息和联系信息。
- [ ] 完成新版 Age Rating 问卷，如实申报边境、黑市交易、电子烟、赌博/彩票与成人主题。
- [ ] 确认 Content Rights：项目依 GPL-2.0 派生，保留许可、对应源码和原作者信息。
- [ ] 在 App Review Notes 中说明虚构内容、消耗型内购、可选 iCloud 同步、无账号和无开发者后端。
- [ ] 将四项内购随首个 App 版本提交审核。

## 需要发布者确认的内容风险

1. “走私电子烟”是可买卖商品，可能触发烟草/电子烟内容的额外审核；若保留，应准确完成年龄分级。
2. 开局包含翻越美墨边境围栏、拘留和遣返叙事，应在商店描述和年龄分级中保持一致。
3. “CVS 彩票”和“Robinhood 末日期权”涉及真实品牌及赌博/高风险金融叙事，建议发布前确认品牌使用和年龄分级表述。
4. `$1.99` 的“越南女朋友”商品会让玩家损失游戏币。商品页面必须清楚说明结果，避免被认为具有误导性。
