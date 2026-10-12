# 绘本手绘小伙伴侧栏与提醒气泡

0.1.24 采用用户选定的 B「绘本手绘」方案。九张透明插画由内置 image_gen 生成，提示词保存在 `STORYBOOK-ASSET-PROMPTS.json`，发布素材位于 `Sources/NotchQuota/Resources/storybook-*.png`。

侧栏图标、详情背景和提醒卡片跟随当前小伙伴。保留原有外观偏好值、账号选择、缓存和刷新行为。

| 小伙伴 | 主题与卡片装饰 | 弹出节奏 |
| --- | --- | --- |
| 糯米熊猫 | 奶油白、竹叶绿、竹叶 | 轻轻落稳，380 ms |
| 奶油小兔 | 草莓粉、长耳花瓣、胡萝卜 | 轻跳回弹，360 ms |
| 枫糖小狐 | 枫糖橙、枫叶、蓬松尾巴 | 轻摇弹出，340 ms |
| 抹茶小龟 | 抹茶绿、龟壳六边形 | 缓慢探出，440 ms |
| 小幽灵 | 星光紫、星芒 | 轻盈漂入，460 ms |
| 云朵团子 | 天空蓝、云团 | 柔和漂入，500 ms |
| 蜂蜜小熊 | 蜂蜜金、蜂巢 | 柔软回弹，400 ms |
| 橘子小猫 | 蜜桃橙、爪印 | 轻快侧摇，320 ms |
| 冰蓝企鹅 | 冰蓝、雪花、蓝围巾 | 小幅摇摆，420 ms |

卡片窗口从 292 × 186 缩小为 268 × 166 点，面积减少约 18%。提供商、账号、额度、额度窗口和重置时间分层展示；未知额度仍显示 `—`。恢复提醒沿用同一主题，保留原有提示语义与显示时长。

## 动效与资源约束

- 缓存的透明 PNG 插画、原生 CALayer / CAShapeLayer 静态装饰及渐变，无新运行时依赖、实时模糊、粒子系统或逐帧定时器。
- 展开只为可见账号运行一次分批入场；折叠清理隐藏账号上的动画。
- 小伙伴回归的轻跳、摇摆、星光在 500 ms 内清理；静止不循环播放。
- 提醒引导点依次出现，卡片按角色节奏弹出；退出使用 180 ms 淡出及轻缩放。鼠标返回会取消正在进行的退出。
- 隐藏、切换外观、休眠与关闭动态效果时清理动画；低电量和系统减少动态效果沿用现有降级机制，退出也遵守该机制。
- 卡片阴影指定静态 shadowPath；小伙伴本体仅一个图片图层。384px 发布素材按需解码至最多 256px，九张图片缓存预算为 2.25 MiB，并由侧栏、菜单及提醒共用。

## 验证与测量

```sh
swift test
scripts/build-app.sh
scripts/check-release.sh
mkdir -p build/ui-review
NOTCHQUOTA_SMOKE_DIR="$PWD/build/ui-review" build/AetherNotchQuota.app/Contents/MacOS/NotchQuota --ui-smoke
mkdir -p .build/performance
xcrun swiftc -O scripts/performance-probe.swift -o .build/performance/probe
python3 scripts/test-sidebar.py --output build/sidebar-review
scripts/test-localization.sh
```

先创建截图输出目录。侧栏回归包含九套主题的静态提醒和恢复提醒截图、左右贴边、快速反转、隐藏清理、无动画模式及鼠标返回取消退出。

性能脚本使用七个缓存账号进行短时空闲和 120 次切换采样。CPU 以单核 100% 为基准；物理内存 footprint 与 RSS 分开记录；账号选择耗时是主线程执行时间，不能替代实际呈现帧率或 GPU 数据。

采样器已修正 Apple Silicon 的 Mach 时钟换算。`proc_pid_rusage` 的 CPU 计数需要乘以 `mach_timebase_info` 的 numer/denom，原脚本直接除以 1e9 会低估 CPU。依据：[Apple XNU fill_task_rusage](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c)。单核忙循环验证应接近 100%。旧采样如需比较，应保留原文件并另存换算后的结果。
