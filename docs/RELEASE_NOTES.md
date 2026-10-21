# AetherNotchQuota 0.1.31 · 最新 Antigravity 模型额度

- 适配 Gemini 4 Argon 的独立额度，兼容 Gemini 3.8 Flash 和 Claude Opus / Sonnet 5.5。
- 按额度组补查缺失模型，修复已有 Gemini 汇总时可能遗漏 Argon、只有 Argon 时可能遗漏 Flash 的问题。
- 合并额度和重置时间一致的推理档位；Claude / GPT 继续显示共享周期额度，避免重复计数。
- 保留未知额度与真实 0% 的区别，以及后台 Lite 档位过滤、账号与服务环境隔离。

支持 Apple Silicon、macOS 13 及以上。通过应用内“检查更新”升级，或下载安装 DMG。模型和额度以当前账号接口返回为准。

<!-- aethernative
{"summary":{"zh":"适配 Gemini 4 Argon 独立额度及最新 Antigravity 模型，修复漏查与重复显示。","en":"Support independent Gemini 4 Argon quotas and current Antigravity models, with missing-pool recovery and deduplication."},"notes":[{"title":{"zh":"最新模型额度","en":"Current model quotas"},"items":[{"zh":"兼容 Gemini 4 Argon、Gemini 3.8 Flash 与 Claude Opus / Sonnet 5.5，按账号返回的额度组显示。","en":"Handle Gemini 4 Argon, Gemini 3.8 Flash and Claude Opus / Sonnet 5.5 using the quota pools returned for each account."},{"zh":"补查缺失额度组，合并相同推理档位，保留未知额度与真实零额度。","en":"Recover missing pools, combine matching reasoning variants and preserve unknown versus zero quota."}]}]}
-->
