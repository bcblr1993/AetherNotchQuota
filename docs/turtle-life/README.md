# 抹茶小龟的日常 · 0.1.27

基于 0.1.26 主干，保留用户提供的手绘小乌龟造型。已接入正式侧栏；熊猫和其他伙伴的行为不变。本次升级仅针对小乌龟，其他伙伴保持既有行为。

- 散步：交替迈动四肢，原生小窗口实际移动；活动围绕用户放置的位置，在左右约 96 pt 范围内，不跨屏，不写回位置偏好。
- 回家：先爬回用户放置的位置，再打哈欠、缩进自己的壳里打盹，随后探头出来。
- 阅读：打开书、低头阅读、抬脚翻页、合上书。
- 喝水：前脚扶住杯子，伸脖子低头啜饮，再抬头。
- 河里游泳：先爬到附近的河岸，再下水划动四肢、转身游回岸边、爬上岸，最后走回出发位置。河面只在游泳时显现，取消动作立即收起。

拖离边缘并收起后默认自动活动，每轮覆盖五种日常，相邻动作不重复；动作之间休息 10–18 秒。单击触发下一项日常，双击查看额度；右键设置可单独选动作或关闭“乌龟自动日常”。悬停暂停、拖动重设家，查看额度、隐藏、休眠、低电量和减少动态效果会停止活动。

## 性能边界

动作帧由有限时长 Core Animation 播放；仅在真实爬行时启用 30 Hz 窗口位置计时器，停止后释放。每次最多缓存两段 16×256×256 RGBA 动作，加一张静止帧，解码上限约 8.25 MiB；不是五套图集全常驻。后台额度刷新不重启动作，不新增账户或网络请求。

## 验证及本地体验

```sh
swift test
scripts/build-app.sh
scripts/check-release.sh
mkdir -p build/turtle-review
NOTCHQUOTA_SMOKE_DIR="$PWD/build/turtle-review" build/AetherNotchQuota.app/Contents/MacOS/NotchQuota --sidebar-test --turtle-test --turtle-record
python3 scripts/measure-turtle.py
build/AetherNotchQuota.app/Contents/MacOS/NotchQuota --turtle-demo
```

体验入口使用正式侧栏控制器和演示账号，不替换 `/Applications` 的公开版。`--turtle-record` 录制实际 presentation layer，并按原生窗口的真实位置绘制录像，产出五个 GIF。

生成工具、参考图、提示词在 [PROMPTS.md](PROMPTS.md)。源图保存在本目录，`scripts/compile-turtle.swift` 只做连通轮廓提取、透明边缘保留、统一缩放和落地对齐；运行时图集在 `Sources/NotchQuota/Resources/turtle-*.png`。本版道具在动作开始和结束时用短淡入淡出衔接，未实现跨场景拾取、收纳道具。

## 本机验证记录（2026-10-13）

`swift test` 65 项通过；构建与 release layout 检查通过；侧栏全量 224 条 PASS（含完成标记）、乌龟实际场景 18 条检查通过。游泳录像验证了从出发点到河岸、下水、上岸和返回原点，隐藏、悬停、双击展开及减少动态效果均取消活动。

短时采样使用正式侧栏和演示账号，不抓帧。CPU 按单个核心 100% 计：

| 场景 | 平均 CPU | 采样数 |
|---|---:|---:|
| 爬行 | 1.720% | 6 |
| 阅读与喝水 | 0.192% | 13 |
| 到河边游泳及返回 | 1.504% | 33 |
| 静止 | 0.009% | 7 |

本次进程物理内存峰值约 37.3 MiB。只代表本机短时应用进程测量，不包含 WindowServer/GPU，不作为全产品能耗或帧率保证。原始结果位于 `build/turtle-review/performance`，五组实际播放 GIF 位于 `build/turtle-review`。
