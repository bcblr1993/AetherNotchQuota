# AetherNotchQuota 0.1.30 · 修正 Gemini 模型显示

修正 0.1.29 把接口中的后台 flashLite 档位误当成可选主模型、额外显示 Gemini 3.5 Flash Lite 的问题。

- 保留 Gemini 3.8 Flash 的剩余额度与重置时间，以及 Claude / GPT 的周期额度。
- 按档位用途过滤后台模型，不硬编码屏蔽特定版本；Lite 模型若明确出现在可选菜单或默认选择中，仍可正常显示。
- 补充隐藏档位、明确可选 Lite 模型和完整额度读取回归测试。

支持 Apple Silicon、macOS 13 及以上。通过应用内“检查更新”升级，或下载安装 DMG。

<!-- aethernative
{"summary":{"zh":"修正后台 flashLite 档位导致多显示 Gemini 3.5 Flash Lite 的问题。","en":"Fix an auxiliary flashLite tier incorrectly appearing as Gemini 3.5 Flash Lite in quota details."},"notes":[{"title":{"zh":"模型显示修正","en":"Model visibility fix"},"items":[{"zh":"不再把后台 Lite 路由档位自动当成可选主模型，保留 Gemini 3.8 Flash 和 Claude / GPT 额度。","en":"Exclude auxiliary Lite routing tiers while retaining Gemini 3.8 Flash and Claude / GPT quotas."},{"zh":"明确出现在可选菜单或默认选择中的 Lite 模型仍可显示，不按版本号硬编码过滤。","en":"Lite models explicitly listed in the selector or as the default remain eligible, without a version-specific blocklist."}]}]}
-->
