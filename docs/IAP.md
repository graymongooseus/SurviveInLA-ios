# 奇遇商店内购配置

四项商品均为 `Consumable`（消耗型）。每次购买固定触发对应剧情，并发放明确标示的游戏存款金额。

| Reference Name | 商品 ID | Apple ID | 剧情 | 价格 | 固定到账 |
| --- | --- | --- | --- | ---: | ---: |
| Surviving LA - Adventure 01 - 3,000 Game Cash | `com.graymongooseus.SurviveInLA.adventure.vietnam` | `6809121599` | 越南女朋友雪中送炭 | $1.99 | $3,000 |
| Surviving LA - Adventure 02 - 6,000 Game Cash | `com.graymongooseus.SurviveInLA.adventure.lottery` | `6809121684` | 便利店乐透刮刮卡 | $2.99 | $6,000 |
| Surviving LA - Adventure 03 - 18,000 Game Cash | `com.graymongooseus.SurviveInLA.adventure.options` | `6809121531` | 手机发现匿名券商 | $5.99 | $18,000 |
| Surviving LA - Adventure 04 - 36,000 Game Cash | `com.graymongooseus.SurviveInLA.adventure.watch` | `6809121641` | 圣盖博车库拍卖 | $9.99 | $36,000 |

## 本地测试

Debug 构建默认使用项目根目录的 `Products.storekit` 运行完整 StoreKit 流程，以免直接发放掩盖商品加载、验证或交易恢复问题。

只有美术预览等明确需要绕过 StoreKit 时，才在 Scheme 中加入 `SURVIVE_IN_LA_DIRECT_GRANT=1`。该模式不会请求 App Store，也不会产生真实扣款。

## 上架前

1. 在 App Store Connect 为同一 Bundle ID 创建以上四个商品 ID；商品 ID 创建后不可修改。
2. 商品类型全部选择“消耗型”，并逐项填写对应剧情和固定到账金额的简体中文商店文案。
3. 完成 Paid Apps Agreement、税务和收款资料。
4. 使用 Sandbox Apple Account 在真机验证成功购买、家长批准、取消购买以及中断后的补发。
5. 随 App 版本提交四项内购审核。

发放逻辑先验证 StoreKit 2 交易，再以交易 ID 做幂等检查；剧情和游戏存款成功写入存档后才结束交易。消耗型商品不会通过“恢复购买”重复发放。
