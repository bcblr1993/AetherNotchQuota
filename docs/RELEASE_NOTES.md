# AetherNotchQuota 0.1.32 · 修复 Argon 额度缺失

- 修复升级 0.1.31 后仍未显示 Gemini 4 Argon 的问题。
- 额度请求自动读取所选 Antigravity 安装包的真实版本与桌面 hub 客户端标识，使服务返回完整的 Gemini、Claude / GPT 和 Argon 独立周额度。
- 保留旧版兼容、账号与服务环境隔离，以及未知额度与真实 0% 的区别。

支持 Apple Silicon、macOS 13 及以上。通过应用内“检查更新”升级，或下载安装 DMG。

<!-- aethernative
{"summary":{"zh":"修复升级后仍缺少 Gemini 4 Argon 额度的问题，自动匹配 Antigravity 桌面客户端标识。","en":"Fix missing Gemini 4 Argon quotas after upgrading by matching the installed Antigravity desktop client identity."},"notes":[{"title":{"zh":"Argon 额度修复","en":"Argon quota fix"},"items":[{"zh":"从所选安装包读取真实版本与 hub 标识，正确获取 Argon 独立周额度。","en":"Read the actual version and hub identity from the selected installation to retrieve independent Argon weekly quotas."},{"zh":"保留旧版本兼容、账号与服务环境隔离，以及未知额度与真实零额度的区别。","en":"Preserve legacy compatibility, account and service isolation, and the distinction between unknown and zero quota."}]}]}
-->
