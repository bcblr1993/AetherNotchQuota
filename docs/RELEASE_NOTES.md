# AetherNotchQuota 0.1.38

- 扩展 Codex 额度解析与续期路径：支持 `code_review_rate_limit` 代码审查窗口、分钟级短周期显示及 `metered_feature` 名称回退；自动兼容 ChatGPT 桌面端内置 Codex CLI 登录续期。
- 新增 Claude `seven_day_cowork`（Cowork · 每周）与 `seven_day_oauth_apps`（OAuth 应用 · 每周）窗口展示，继续严格区分未知值与真实零额度。
- 完善 Google Antigravity 模型与分组兼容：新增 `neon` 层级与 `xhigh`/`extra-low`/`extra-high` 档位同额度同重置合并，跳过已停用分组并支持顶层 `buckets` 回退读取。
- 灵动岛展开详情最多显示 8 行窗口，并同步补全简体中文、英文、日文三语词条。

适用于 macOS 13+、Apple Silicon。通过应用内“检查更新”升级，或下载安装包。
