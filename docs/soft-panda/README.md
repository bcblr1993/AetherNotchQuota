# C 风格熊猫首版 · 0.1.26

本目录保存原创生成素材及裁切记录。`source-drink.png` 和 `source-music.png` 是源图，`scripts/compile-soft-panda.swift` 按连通轮廓和脚底基准统一缩放、打包为运行时使用的 4×4 透明图集。没有使用参考项目的角色或动画素材。

正式入口是侧栏的“糯米熊猫”：拖离屏幕边缘、收起后单击播放两段动作，双击查看额度。其他八种外观沿用公开版。CLI 样片仅供隔离检查，交互方式不等同于正式侧栏。

## 可重复验证

```sh
swift test
scripts/build-app.sh
scripts/check-release.sh
NOTCHQUOTA_SMOKE_DIR="$PWD/build/panda-release" build/AetherNotchQuota.app/Contents/MacOS/NotchQuota --sidebar-test --panda-release-test
python3 scripts/measure-soft-panda.py
```

2026-10-12 首版候选验证：61 个单元测试、12 项熊猫集成检查、64 项通用 UI 检查、203 项侧栏检查及中英日三种本地化检查通过。正式侧栏的 presentation layer 截图存于 `docs/images/panda-drink-026.png` 和 `panda-music-026.png`，分别可见杯子抬至嘴边和耳机佩戴状态。

运行时每段图集 16 张 256×256 RGBA 帧，两段解码缓存合计 8 MiB；采用有限时长 Core Animation，静止不运行帧计时器。性能脚本只测隔离熊猫窗口的应用进程，不包括 WindowServer/GPU、整机耗电和真实账号后台刷新，不用于宣称全产品性能。

本版尚未提供吃竹子、睡觉等其他 C 风格动作。两段动作的道具在场景交接时切换，后续可继续完善过渡。
