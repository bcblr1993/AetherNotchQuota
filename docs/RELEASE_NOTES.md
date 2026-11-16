# AetherNotchQuota 0.1.37

- 支持 Claude 最新 `limits[]` 额度格式，显示 5 小时、全局每周和按模型或入口拆分的周额度。
- 保持 Codex 最新周额度兼容，并复核 Gemini、Claude / GPT 双周期与独立 Argon 额度显示。
- 补充 Gemini Carbon、Hydrogen 模型层级和接口标记为 Google 的 Orchestrator 模型识别；共享额度优先，避免重复显示。
- 兼容新版 Antigravity 通过常量配置额度服务地址，继续严格校验允许的服务来源。
- 旧格式继续兼容；未知、停用和真实零额度保持严格区分。

适用于 macOS 13+、Apple Silicon。通过应用内“检查更新”升级，或下载安装包。
