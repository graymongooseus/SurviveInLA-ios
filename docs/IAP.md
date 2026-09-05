# 奇遇商店内购配置

四项商品均为 `Consumable`（消耗型），每次成功购买触发一次对应事件。

| 商品 ID | 价格 | 游戏内结果 |
| --- | ---: | ---: |
| `com.graymongooseus.SurviveInLA.adventure.vietnam` | $1.99 | -$3,000 |
| `com.graymongooseus.SurviveInLA.adventure.lottery` | $2.99 | +$6,000 |
| `com.graymongooseus.SurviveInLA.adventure.options` | $5.99 | +$18,000 |
| `com.graymongooseus.SurviveInLA.adventure.watch` | $9.99 | +$36,000 |

## 本地测试

共享 Scheme 已关联项目根目录的 `Products.storekit`。在 Xcode 运行应用，进入游戏后点顶部黄色闪光按钮即可打开商店。购买会使用 StoreKit 测试环境，不产生真实扣款。

## 上架前

1. 在 App Store Connect 为同一 Bundle ID 创建以上四个商品 ID。
2. 商品类型全部选择消耗型，并为每项设置价格档位和商店文案。
3. 完成 Paid Apps Agreement、税务和收款资料。
4. 使用 Sandbox Apple Account 在真机验证购买、待批准交易、取消购买和中断后补发。
5. 随 App 版本提交四项内购审核。

发奖逻辑会先验证 StoreKit 2 交易，再以交易 ID 做幂等检查；奖励成功写入存档后才结束交易。消耗型商品不会通过“恢复购买”重复发奖。
