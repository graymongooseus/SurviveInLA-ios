# 游戏币充值内购配置

四项商品均为 `Consumable`（消耗型）。每次成功购买固定发放明确标示的游戏现金，不含抽奖、随机结果、赔率或中奖机制。

| 商品 ID | 建议价格 | 固定到账 |
| --- | ---: | ---: |
| `com.graymongooseus.SurviveInLA.currency.starter` | $1.99 | $3,000 游戏现金 |
| `com.graymongooseus.SurviveInLA.currency.survivor` | $2.99 | $6,000 游戏现金 |
| `com.graymongooseus.SurviveInLA.currency.builder` | $5.99 | $18,000 游戏现金 |
| `com.graymongooseus.SurviveInLA.currency.dream` | $9.99 | $36,000 游戏现金 |

## 本地测试

Debug 构建默认使用直接发放模式：进入游戏后打开“游戏币商店”，点击任一商品会直接把对应固定金额写入当前存档，不请求 App Store，也不产生真实扣款。

如需在 Debug 构建中测试完整 StoreKit 流程，在 Scheme 的环境变量中加入 `SURVIVE_IN_LA_USE_STOREKIT=1`。共享 Scheme 已关联项目根目录的 `Products.storekit`。

## 上架前

1. 在 App Store Connect 为同一 Bundle ID 创建以上四个商品 ID；商品 ID 创建后不可修改。
2. 商品类型全部选择“消耗型”，并逐项填写与固定到账金额一致的简体中文商店文案。
3. 完成 Paid Apps Agreement、税务和收款资料。
4. 使用 Sandbox Apple Account 在真机验证成功购买、家长批准、取消购买以及中断后的补发。
5. 随 App 版本提交四项内购审核。

发放逻辑先验证 StoreKit 2 交易，再以交易 ID 做幂等检查；固定游戏现金成功写入存档后才结束交易。消耗型商品不会通过“恢复购买”重复发放。
