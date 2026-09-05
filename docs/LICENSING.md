# 许可边界与 App Store 发布说明

最后核对：2026 年 9 月 4 日

## 当前项目边界

- 开发者确认 `SurviveInLA/` 的 Swift 代码为独立重写。
- Xcode 生产 target 不包含、编译或链接 `archive/beijing-fusheng-v1.2.2/` 中的 Windows/MFC 代码、可执行文件和资源。
- 新版可以参考“移动、倒卖、负债、随机事件”等玩法思想；应避免复制原作的源代码、独创文本、图像、音频或其他具体表达。
- 原版快照继续保留原有 GPL-2.0 许可。若修改或单独分发该归档，仍需遵守 GPL-2.0。
- 除另有说明外，独立 Swift 实现目前未授予开源许可，保留所有权利。

## 为什么这个边界重要

美国版权局明确说明，版权保护具体表达，不保护思想、程序逻辑、算法、系统或操作方法。因此，仅采用相似的游戏机制，通常不会自动使独立重写的代码成为 GPL 衍生作品；复制具体代码、文本或素材则可能改变结论。

GPL-2.0 允许商业销售，也不禁止内购盈利。但如果 App 本身是 GPL-2.0 衍生作品，分发二进制时需要提供对应源代码，并允许接收者复制、修改和再分发，且不能施加额外限制。Apple 的 App Store/TestFlight 使用条款包含不可转让以及限制复制、修改、逆向和再分发的条款，因此把整个 App 作为 GPL-2.0 软件发布存在现实的许可冲突风险。

## 本项目的发布策略

1. 保持 Swift App 与历史归档完全分离。
2. 不把归档中的源码、图片、音频、可执行文件或原作文案加入 Xcode target。
3. App Review Notes 不把新版描述为 GPL App；如被询问，说明它是独立 Swift 实现，历史源代码仅作为未打包的参考归档。
4. 上线前对游戏文案和素材再做一次来源核对；无法确认独立创作的内容应重写或替换。
5. 如果未来决定直接采用任何 GPL 原代码，优先向原版权人取得可用于 App Store 的额外商业/双重许可。

## 官方参考

- 美国版权局：<https://www.copyright.gov/register/tx-programs.html>
- GPL-2.0 正文：<https://www.gnu.org/licenses/gpl-2.0.html>
- GPL-2.0 FAQ：<https://www.gnu.org/licenses/old-licenses/gpl-2.0-faq.en.html>
- Apple 标准 EULA：<https://www.apple.com/legal/internet-services/itunes/dev/stdeula/>
- Apple TestFlight 条款：<https://www.apple.com/legal/internet-services/itunes/testflight/>
- Apple App Review Guidelines：<https://developer.apple.com/app-store/review/guidelines/>

本文是项目风险记录，不构成针对具体司法辖区的法律意见。
