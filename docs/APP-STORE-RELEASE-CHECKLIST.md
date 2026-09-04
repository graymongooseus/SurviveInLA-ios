# App Store 发布清单

最后检查：2026 年 9 月 3 日

## 已通过的本地质量门

- [x] Xcode 26.2 / iOS 26.2 SDK 可编译。
- [x] iOS 17.0 最低部署目标，仅支持 iPhone 竖屏。
- [x] 19 项游戏引擎与存档测试全部通过。
- [x] Release 真机 Archive 构建成功并通过 Xcode Store 本地校验。
- [x] App 图标为 1024 × 1024 PNG，不含 alpha 通道。
- [x] App 显示名为“洛杉矶浮生记”。
- [x] Bundle ID 设置为 `com.graymongooseus.SurviveInLA`。
- [x] 不使用第三方 SDK、账号、内购、广告或用户追踪。
- [x] 不请求用户定位；MapKit 只展示公开地图。
- [x] 已声明不使用非豁免加密。

## 上传 TestFlight 前

- [ ] 在 Apple Developer 后台注册显式 Bundle ID：`com.graymongooseus.SurviveInLA`。
- [ ] 在 App Store Connect 新建独立 App 记录，不要上传到 `D·Diary: Life Coordinates`。
- [ ] 确认版本号：当前 `0.1.0 (1)`；正式首发建议改为 `1.0.0 (1)`。
- [ ] 确认当前 Apple Developer 协议均已签署。
- [ ] 决定是否在欧盟发布；若发布，先补齐 EU trader status。
- [ ] 用 Xcode Organizer 执行 Validate App，再 Distribute App → App Store Connect → Upload。

## App Store Connect 建议值

| 字段 | 建议 |
|---|---|
| 平台 | iOS |
| 名称 | 洛杉矶浮生记 |
| 主要语言 | Chinese (Simplified) |
| Bundle ID | `com.graymongooseus.SurviveInLA` |
| SKU | `survive-in-la-ios` |
| 主分类 | Games |
| 子分类 | Simulation / Strategy |
| 价格 | Free |
| 数据收集 | No, we do not collect data from this app |
| 隐私政策 URL | `https://github.com/graymongooseus/SurviveInLA-ios/blob/master/docs/PRIVACY.md` |
| 支持 URL | `https://github.com/graymongooseus/SurviveInLA-ios/blob/master/docs/SUPPORT.md` |

## 提交 App Review 前

- [ ] 上传 1–10 张无透明通道的 iPhone 截图，首图应展示真实游戏界面。
- [ ] 完成应用描述、副标题、关键词、促销文本、版权信息和联系信息。
- [ ] 完成新版 Age Rating 问卷，如实申报边境、黑市交易和电子烟相关内容。
- [ ] 确认 Content Rights：项目依 GPL-2.0 派生，保留许可、对应源码和原作者信息。
- [ ] 在 App Review Notes 中说明：这是虚构的单机生存/交易游戏，无真实货币、无真实交易、无账号和无网络后端。
- [ ] 在至少一台真机上完成首次启动、新建存档、买卖、移动、打工、投资、城市服务和重启测试。

## 需要发布者确认的内容风险

1. “走私电子烟”是可买卖商品。即使仅为虚构游戏交易，也可能触发烟草/电子烟内容的额外审核。最稳妥的做法是改为不涉及受控商品的灰市货物；若保留，应准确完成年龄分级并在审核备注中说明无真实销售或消费。
2. 开局包含“翻过美墨边境围栏”叙事。这是作品语气与目标受众的选择，应在商店描述和年龄分级中保持一致，避免用青少年导向的宣传素材。
