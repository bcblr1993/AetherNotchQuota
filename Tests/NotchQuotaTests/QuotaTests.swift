import XCTest
@testable import NotchQuota

final class QuotaTests: XCTestCase {
    private func json(_ text: String) -> [String: Any] { try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any] }
    func testQuotaParsingAndIdleBoundaries() {
        let codex = QuotaParser.codex(json(#"{"rate_limit":{"primary_window":{"used_percent":18,"limit_window_seconds":604800,"reset_at":1789435604},"secondary_window":null},"additional_rate_limits":[{"limit_name":"Spark","rate_limit":{"primary_window":{"used_percent":0,"limit_window_seconds":18000}}}]}"#))
        XCTAssert(codex.remaining == 82, "Codex 使用比例转换为剩余比例")
        XCTAssert(codex.windows[0].label == "每周", "Codex 单周窗口不误标五小时")
        XCTAssert(codex.windows.count == 2 && codex.windows[1].remaining == 100, "额外模型限额与零使用量")
        let claude = QuotaParser.claude(json(#"{"five_hour":{"utilization":0,"resets_at":null},"seven_day":{"utilization":40,"resets_at":"2026-09-10T18:00:00.404Z"},"seven_day_opus":null}"#))
        XCTAssert(claude.remaining == 60 && claude.windows[0].remaining == 100, "Claude session/weekly 独立解析")
        XCTAssert(claude.windows[1].reset != nil, "带毫秒的重置时间")
        let anti = QuotaParser.antigravity(json(#"{"groups":[{"displayName":"Gemini Models","buckets":[{"displayName":"Weekly Limit Remaining","remainingFraction":0.91447425},{"displayName":"Five Hour Limit Remaining","remainingFraction":1}]}]}"#))
        XCTAssert(abs((anti.remaining ?? 0) - 91.447425) < 0.0001, "Antigravity 直接远程响应比例")
        XCTAssert(anti.windows[1].label == "Gemini · 5 小时", "Antigravity 紧凑中文周期")
        let unknown = QuotaParser.antigravity(json(#"{"response":{"groups":[{"buckets":[{"remaining":{}},{"remainingFraction":null},{"remainingFraction":true},{"remainingFraction":2}]}]}}"#))
        XCTAssert(unknown.remaining == nil, "缺失、null、布尔值和非法比例均不冒充额度")
        let zero = QuotaParser.antigravity(json(#"{"groups":[{"buckets":[{"remaining":{"remainingFraction":0}}]}]}"#))
        XCTAssert(zero.remaining == 0, "真实耗尽保持为零")
        XCTAssert(QuotaTint.color(50) == QuotaTint.color(20), "黄色区间包含 20 和 50")
        XCTAssert(QuotaTint.color(19) != QuotaTint.color(20) && QuotaTint.color(51) != QuotaTint.color(50), "红黄绿边界")
        var idle = IdleState(); idle.interact(at: 100)
        XCTAssert(!idle.tick(at: 114.99), "15 秒之前保持显示")
        XCTAssert(idle.tick(at: 115) && !idle.active, "15 秒结束交互")
        XCTAssert(!idle.tick(at: 130), "空闲后不重复触发")
        idle.interact(at: 131); XCTAssert(idle.active && !idle.tick(at: 145), "再次操作重新计时")
        XCTAssert(idle.tick(at: 146), "重新操作后完整 15 秒")
        XCTAssert(Provider.codex.next.next.next == .codex, "三图标循环")
        let stale = DisplayState(snapshot: Snapshot(windows: codex.windows, fetchedAt: Date().addingTimeInterval(-601)))
        XCTAssert(stale.stale, "旧读数有过期标记")
    }

    func testLatestClaudeLimitsFallbackAndScopedWindows() {
        // Sanitized mirror of the current Claude desktop usage contract.
        let payload = json(#"{"five_hour":null,"seven_day":null,"seven_day_opus":null,"limits":[{"kind":"session","group":"session","percent":20,"resets_at":"2030-01-01T05:00:00Z","scope":null},{"kind":"weekly_all","group":"weekly","percent":35,"resets_at":"2030-01-08T00:00:00Z","scope":null},{"kind":"weekly_scoped","group":"weekly","percent":0,"resets_at":"2030-01-08T00:00:00Z","scope":{"model":{"display_name":"Fable"}}},{"kind":"weekly_scoped","percent":42,"scope":{"surface":{"display_name":"Claude Code"}},"is_active":false},{}]}"#)
        let snapshot = QuotaParser.claude(payload)
        XCTAssertEqual(snapshot.windows.map(\.label), ["5 小时", "每周", "Fable · 每周"])
        XCTAssertEqual(snapshot.windows.map(\.remaining), [80, 65, 100])
        XCTAssertEqual(snapshot.windows[0].reset, QuotaParser.date("2030-01-01T05:00:00Z"))
    }

    func testClaudeFlatWindowsWinAndUnknownDoesNotBecomeZero() {
        let payload = json(#"{"five_hour":{"utilization":5,"resets_at":null},"seven_day":{"utilization":null,"resets_at":"2030-01-08T00:00:00Z"},"limits":[{"kind":"session","percent":99,"resets_at":"2030-01-01T05:00:00Z","scope":null},{"kind":"weekly_all","percent":null,"scope":null},{"kind":"weekly_scoped","percent":"0","scope":{"model":{"display_name":"Future"}}}]}"#)
        let snapshot = QuotaParser.claude(payload)
        XCTAssertEqual(snapshot.windows.map(\.label), ["5 小时"])
        XCTAssertEqual(snapshot.windows.first?.remaining, 95)
        XCTAssertNil(snapshot.windows.first?.reset)
    }

    func testCodexCodeReviewSubHourWindowsAndFeatureFallback() {
        let payload = json(#"""
        {"rate_limit":{"primary_window":{"used_percent":74,"limit_window_seconds":18000,"reset_at":1893456000},"secondary_window":{"used_percent":100,"limit_window_seconds":604800,"reset_at":1894060800}},"code_review_rate_limit":{"primary_window":{"used_percent":null,"limit_window_seconds":604800}},"additional_rate_limits":[{"limit_name":"GPT-Reserve","rate_limit":{"primary_window":{"used_percent":0,"limit_window_seconds":900}}},{"limit_name":"   ","metered_feature":"codex_bench","rate_limit":{"primary_window":{"used_percent":25,"limit_window_seconds":60}}},{"rate_limit":{"primary_window":{"used_percent":50,"limit_window_seconds":300}}}]}
        """#)
        let snapshot = QuotaParser.codex(payload)
        XCTAssertEqual(snapshot.windows.map(\.label), [
            "5 小时",
            "每周",
            "代码审查 · 每周",
            "GPT-Reserve · 15 分钟",
            "codex_bench · 1 分钟",
            "附加 · 5 分钟"
        ])
        XCTAssertEqual(snapshot.windows[0].remaining, 26)
        XCTAssertEqual(snapshot.windows[1].remaining, 0)
        XCTAssertNil(snapshot.windows[2].remaining, "null used_percent in code_review_rate_limit must stay nil/unknown, never 0%")
        XCTAssertEqual(snapshot.windows[3].remaining, 100)
        XCTAssertEqual(snapshot.windows[4].remaining, 75)
        XCTAssertEqual(snapshot.windows[5].remaining, 50)
        XCTAssertEqual(snapshot.remaining, 0, "Real exhausted window keeps snapshot remaining at 0")

        let reviewZero = QuotaParser.codex(json(#"{"code_review_rate_limit":{"primary_window":{"used_percent":0,"limit_window_seconds":604800}}}"#))
        XCTAssertEqual(reviewZero.windows.map(\.label), ["代码审查 · 每周"])
        XCTAssertEqual(reviewZero.windows.first?.remaining, 100)
    }

    func testClaudeCoworkAndOAuthAppsPreserveUnknownVsRealZero() {
        let payload = json(#"""
        {"five_hour":{"utilization":0,"resets_at":"2030-01-01T05:00:00Z"},"seven_day":{"utilization":null,"resets_at":null},"seven_day_sonnet":{"utilization":100,"resets_at":"2030-01-08T00:00:00Z"},"seven_day_cowork":{"utilization":25,"resets_at":"2030-01-08T00:00:00Z"},"seven_day_oauth_apps":{"utilization":0,"resets_at":"2030-01-08T00:00:00Z"},"limits":[]}
        """#)
        let snapshot = QuotaParser.claude(payload)
        XCTAssertEqual(snapshot.windows.map(\.label), ["5 小时", "Sonnet · 每周", "Cowork · 每周", "OAuth 应用 · 每周"])
        XCTAssertEqual(snapshot.windows.map(\.remaining), [100, 0, 75, 100])
        XCTAssertEqual(snapshot.remaining, 0)

        let nullOptional = QuotaParser.claude(json(#"{"seven_day_cowork":{"utilization":null,"resets_at":"2030-01-08T00:00:00Z"},"seven_day_oauth_apps":null}"#))
        XCTAssertTrue(nullOptional.windows.isEmpty, "Null utilization/object must be omitted rather than coerced to 0%")
    }

    func testCodexSessionFallbackIncludesBundledChatGPTPaths() {
        let home = URL(fileURLWithPath: "/Users/example")
        let paths = CodexSession.executablePaths(home: home, codexApp: nil)
        XCTAssertEqual(paths, [
            "/opt/homebrew/bin/codex",
            "/Users/example/.local/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/bin/codex",
            "/Users/example/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Users/example/Applications/ChatGPT.app/Contents/Resources/bin/codex"
        ])
    }
}

final class EndpointTests: XCTestCase {
    func testHubConstantEndpointAndStrictOriginValidation() throws {
        // Sanitized source shape from the installed hub's argument-builder module.
        let fixture = "exports.LS_CLOUD_CODE_ENDPOINT = 'https://daily-cloudcode-pa.googleapis.com';\n['--cloud_code_endpoint', exports.LS_CLOUD_CODE_ENDPOINT,];"
        XCTAssertEqual(try Installation.endpoint(from: Data(fixture.utf8)), "https://daily-cloudcode-pa.googleapis.com/v1internal:")
        for origin in ["https://daily-cloudcode-pa.googleapis.com.evil.example", "https://evil.example", "https://daily-cloudcode-pa.googleapis.com/path"] {
            XCTAssertThrowsError(try Installation.endpoint(from: Data(fixture.replacingOccurrences(of: "https://daily-cloudcode-pa.googleapis.com", with: origin).utf8)))
            XCTAssertThrowsError(try Installation.endpoint(from: Data("--cloud_code_endpoint \(origin)".utf8)))
        }
        XCTAssertThrowsError(try Installation.endpoint(from: Data("['--cloud_code_endpoint', exports.LS_CLOUD_CODE_ENDPOINT,];".utf8)))
        XCTAssertThrowsError(try Installation.endpoint(from: Data(("exports.LS_CLOUD_CODE_ENDPOINT = 'https://cloudcode-pa.googleapis.com';" + fixture).utf8)))
        XCTAssertEqual(try Installation.endpoint(from: Data("--cloud_code_endpoint https://daily-cloudcode-pa.sandbox.googleapis.com".utf8)), "https://daily-cloudcode-pa.sandbox.googleapis.com/v1internal:")
    }
    func testUsesInstalledEndpointRatherThanOtherQuotaPool() throws {
        let sample = Data("['--cloud_code_endpoint', 'https://daily-cloudcode-pa.googleapis.com']".utf8)
        XCTAssertEqual(try Installation.endpoint(from: sample), "https://daily-cloudcode-pa.googleapis.com/v1internal:")
    }
    func testUntrustedOrMissingEndpointIsRejected() {
        XCTAssertThrowsError(try Installation.endpoint(from: Data("--cloud_code_endpoint https://attacker.googleapis.com".utf8)))
        XCTAssertThrowsError(try Installation.endpoint(from: Data("--cloud_code_endpoint https://example.com".utf8)))
        XCTAssertThrowsError(try Installation.endpoint(from: Data()))
    }
}

final class ProviderSelectionTests: XCTestCase {
    func testAllInstallationCombinations() {
        for mask in 0..<8 {
            let available = Provider.allCases.enumerated().compactMap { index, provider in
                mask & (1 << index) != 0 ? provider : nil
            }
            let selection = ProviderSelection(installed: available)
            for preferred in Provider.allCases {
                XCTAssertEqual(selection.selected(preferred: preferred), available.contains(preferred) ? preferred : available.first)
                if available.isEmpty { XCTAssertNil(selection.next(after: preferred)) }
                else { XCTAssertTrue(available.contains(selection.next(after: preferred)!)) }
            }
            if let first = available.first {
                var current = first
                for _ in available { current = selection.next(after: current)! }
                XCTAssertEqual(current, first)
            }
        }
    }
    func testUninstallSelectedAppFallsBackAndSingleAppDoesNotSwitch() {
        let selection = ProviderSelection(installed: [.claude])
        XCTAssertEqual(selection.selected(preferred: .codex), .claude)
        XCTAssertEqual(selection.next(after: .claude), .claude)
    }
}

final class DefaultProviderTests: XCTestCase {
    func testPriorityIsIndependentOfSelectedAppAndDetectionOrder() {
        XCTAssertEqual(ProviderSelection(installed: [.antigravity, .claude, .codex]).defaultProvider, .codex)
        XCTAssertEqual(ProviderSelection(installed: [.antigravity, .claude]).defaultProvider, .claude)
        XCTAssertEqual(ProviderSelection(installed: [.antigravity]).defaultProvider, .antigravity)
        XCTAssertNil(ProviderSelection(installed: []).defaultProvider)
    }
    @MainActor func testIconsShareSmallVisualBounds() {
        for provider in Provider.allCases {
            XCTAssertEqual(max(provider.icon.size.width, provider.icon.size.height), 16, accuracy: 0.01)
        }
    }
}

final class LoginItemTests: XCTestCase {
    func testEnabledAndPendingHaveDifferentDisplayStates() {
        XCTAssertEqual(LoginItemState.enabled.checkmark, .on)
        XCTAssertEqual(LoginItemState.requiresApproval.checkmark, .mixed)
        XCTAssertEqual(LoginItemState.disabled.checkmark, .off)
        XCTAssertEqual(LoginItemState.requiresApproval.title, L10n.text("开机自动启动（待系统允许）"))
    }
    func testToggleAllowsDisablingPendingRegistration() {
        XCTAssertFalse(LoginItemState.enabled.shouldEnableOnToggle)
        XCTAssertFalse(LoginItemState.requiresApproval.shouldEnableOnToggle)
        XCTAssertTrue(LoginItemState.disabled.shouldEnableOnToggle)
        XCTAssertTrue(LoginItemState.unavailable.shouldEnableOnToggle)
    }
}
