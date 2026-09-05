# App Store 发布清单

最后检查：2026 年 9 月 4 日

## 已通过的本地质量门

- [x] 当前工作区可编译；Release Archive 已成功生成。
- [x] iOS 18.0 最低部署目标，仅支持 iPhone 竖屏。
- [x] iOS 18.5 模拟器兼容运行通过 40 项测试；最终代码共 42 项测试全部通过。
- [x] App 图标为 1024 × 1024 PNG，不含 alpha 通道。
- [x] App 显示名为“Surviving LA”。
- [x] Bundle ID 设置为 `com.graymongooseus.SurviveInLA`。
- [x] 不使用第三方 SDK、自有账号、广告或用户追踪；包含四项可选消耗型内购。
- [x] 不请求用户定位；MapKit 只展示公开地图。
- [x] 已声明不使用非豁免加密。

## 上传 TestFlight 前

- [x] 已注册并选用显式 Bundle ID：`com.graymongooseus.SurviveInLA`。
- [x] 已在 App Store Connect 新建 `Surviving LA`，Apple ID：`6808884445`。
- [x] TestFlight 版本号已设为 `1.0 (2)`。
- [ ] 确认当前 Apple Developer 协议均已签署。
- [ ] 决定是否在欧盟发布；若发布，先补齐 EU trader status。
- [ ] 在 Xcode Organizer 中打开已生成的 Archive，执行 Validate App，再选择 Distribute App → App Store Connect → Upload。

## App Store Connect 建议值

| 字段 | 建议 |
|---|---|
| 平台 | iOS |
| 名称 | Surviving LA |
| 主要语言 | 简体中文（Simplified Chinese） |
| Bundle ID | `com.graymongooseus.SurviveInLA` |
| SKU | `surviving-la-ios` |
| Apple ID | `6808884445` |
| 主分类 | Games |
| 子分类 | Simulation / Strategy |
| 价格 | Free |
| 隐私标签 | Gameplay Content；App Functionality；Linked to User；Not Used for Tracking |
| 隐私政策 URL | `https://github.com/graymongooseus/SurviveInLA-ios/blob/master/docs/PRIVACY.md` |
| 支持 URL | `https://github.com/graymongooseus/SurviveInLA-ios/blob/master/docs/SUPPORT.md` |

## 首发销售地区

- 选择 `Specific Countries or Regions`，首发包含其他可选市场。
- 暂不包含中国大陆：游戏在当地上架可能需要额外版号及监管资料。
- 暂不包含越南：App Store Connect 已提示游戏需提供越南游戏许可证。
- 韩国、澳大利亚等地区继续开放，并采用 App Store Connect 已生成的当地成人年龄分级；若韩国 GRAC 后续要求 RCN，再按通知补充。
- 四项游戏币内购使用与 App 相同的地区范围，避免出现 App 可下载但商品不可购买的地区差异。

## 提交 App Review 前

- [ ] 上传 1–10 张无透明通道的 iPhone 截图，首图应展示真实游戏界面。
- [ ] 完成应用描述、副标题、关键词、促销文本、版权信息和联系信息。
- [ ] 审核联系电话需使用带 `+` 国家码的国际格式；当前因缺少该号码，简体中文版本元数据尚未保存。
- [x] Age Rating 已按现有内容申报为 18+，包含频繁成人暗示、频繁烟草引用和轻度模拟博彩。
- [ ] 最终复核 Content Rights：生产 target 不包含原作代码、文本或素材；历史归档保留原 GPL-2.0 文件且不进入 App 二进制。
- [ ] 在 App Review Notes 中说明：这是虚构的单机生存/交易游戏，无真实货币、无真实交易、无账号和无自有服务器；仅有可选 iCloud 存档同步及 StoreKit 内购。
- [ ] 在至少一台真机上完成首次启动、新建存档、买卖、移动、打工、投资、城市服务和重启测试。

## 需要发布者确认的内容风险

1. “走私电子烟”是可买卖商品。即使仅为虚构游戏交易，也可能触发烟草/电子烟内容的额外审核。最稳妥的做法是改为不涉及受控商品的灰市货物；若保留，应准确完成年龄分级并在审核备注中说明无真实销售或消费。
2. 开局包含“翻过美墨边境围栏”叙事。这是作品语气与目标受众的选择，应在商店描述和年龄分级中保持一致，避免用青少年导向的宣传素材。
