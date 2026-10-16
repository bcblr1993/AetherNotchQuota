# AetherNotchQuota 0.1.29 · 恢复 Antigravity Gemini 额度

修复新版 Antigravity 额度详情只显示 Claude / GPT、没有 Gemini 自身额度的问题。

- 补充读取当前可用 Gemini 模型，包括 Gemini 3.8 Flash 的剩余比例和重置时间。
- 同一模型的多个档位去重，过滤后台模型与未列入当前选择列表的旧别名。
- 保留 Claude / GPT 周期额度、旧版 Gemini 分组兼容和账号隔离；查询失败保留旧数据并显示错误。
- 沿用现有刷新频率、界面和小伙伴动效。

支持 Apple Silicon、macOS 13 及以上。通过应用内“检查更新”升级，或下载安装 DMG。

<!-- aethernative
{"summary":{"zh":"修复新版 Antigravity 遗漏 Gemini 额度的问题，恢复 Gemini 3.8 Flash 等可用模型的剩余比例与重置时间。","en":"Restore missing Gemini quotas in newer Antigravity builds, including Gemini 3.8 Flash and its reset time."},"notes":[{"title":{"zh":"Gemini 额度修复","en":"Gemini quota fix"},"items":[{"zh":"从当前模型列表补充 Gemini 额度，同时保留 Claude / GPT 周期额度。","en":"Read Gemini quotas from the current model list while retaining Claude / GPT quota windows."},{"zh":"过滤后台模型与旧别名，去重重复档位；保留账号隔离与未知额度状态。","en":"Filter internal models and retired aliases, deduplicate repeated tiers, and preserve account isolation and unknown quota states."}]}]}
-->
