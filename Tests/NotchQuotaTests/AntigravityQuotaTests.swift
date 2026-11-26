import XCTest
@testable import NotchQuota

/// Sanitized Antigravity 2.23.1 response shapes; identifiers, times and fractions are synthetic.
private enum GeminiQuotaFixture {
    static let summary = #"{"groups":[{"displayName":"Claude and GPT models","buckets":[{"displayName":"Weekly Limit Remaining","window":"weekly","remainingFraction":0.42},{"displayName":"Five Hour Limit Remaining","window":"5h","remainingFraction":1}]}]}"#
    static let models = #"""
    {
      "defaultAgentModelId":"claude-example",
      "agentModelSorts":[{"displayName":"Recommended","groups":[{"modelIds":["claude-example"]}]}],
      "tieredModelIds":{"flash":["gemini-3.8-flash-tiered"],"pro":["gemini-3.8-flash-tiered"],"flashLite":["gemini-3.5-flash-lite"]},
      "models":{
        "gemini-3.8-flash-tiered":{"modelProvider":"MODEL_PROVIDER_GOOGLE","quotaInfo":{"remainingFraction":0.95,"resetTime":"2030-01-01T06:00:00Z"}},
        "gemini-3.5-flash-lite":{"displayName":"Gemini 3.5 Flash Lite","quotaInfo":{"remainingFraction":0.95,"resetTime":"2030-01-01T06:00:00Z"}},
        "gemini-retired-alias":{"displayName":"Retired alias","quotaInfo":{"remainingFraction":0.1}},
        "chat_internal":{"isInternal":true,"quotaInfo":{"remainingFraction":1}},
        "claude-example":{"displayName":"Claude","quotaInfo":{"remainingFraction":0.42}}
      }
    }
    """#
    // Synthetic values using the current model IDs and the quota groups shown in the app.
    static let latestSummary = #"""
    {"groups":[
      {"displayName":"Gemini Models","buckets":[
        {"displayName":"Weekly Limit Remaining","window":"weekly","remainingFraction":0.8},
        {"window":"5h","remainingFraction":1}]},
      {"displayName":"Claude and GPT models","buckets":[
        {"window":"weekly","remainingFraction":0.42},{"window":"5h","remainingFraction":0}]},
      {"displayName":"Gemini 4 Argon","buckets":[
        {"displayName":"Gemini 4 Argon Weekly Limit","window":"weekly","remainingFraction":0.6,"resetTime":"2030-01-08T00:00:00Z"}]}]}
    """#
    static let latestModels = #"""
    {"defaultAgentModelId":"gemini-4-argon-medium",
     "tieredModelIds":{"flash":["gemini-3.8-flash-tiered"],"argon":["gemini-4-argon-high"]},
     "agentModelSorts":[{"groups":[{"modelIds":["gemini-4-argon-low","gemini-4-argon-medium","gemini-4-argon-high","claude-opus-5-5-medium","claude-sonnet-5-5-medium","gpt-oss-120b-medium"]}]}],
     "models":{
       "gemini-4-argon-low":{"displayName":"Gemini 4 Argon (Low)","quotaInfo":{"remainingFraction":0.6,"resetTime":"2030-01-08T00:00:00Z"}},
       "gemini-4-argon-medium":{"displayName":"Gemini 4 Argon (Medium)","quotaInfo":{"remainingFraction":0.6,"resetTime":"2030-01-08T00:00:00Z"}},
       "gemini-4-argon-high":{"quotaInfo":{"remainingFraction":0.6,"resetTime":"2030-01-08T00:00:00Z"}},
       "gemini-3.8-flash-tiered":{"quotaInfo":{"remainingFraction":1}},
       "claude-opus-5-5-medium":{"displayName":"Claude Opus 5.5 (Medium)","quotaInfo":{"remainingFraction":0.42}},
       "claude-sonnet-5-5-medium":{"displayName":"Claude Sonnet 5.5 (Medium)","quotaInfo":{"remainingFraction":0.42}},
       "gpt-oss-120b-medium":{"displayName":"GPT-OSS 120B (Medium)","quotaInfo":{"remainingFraction":0.42}},
       "gemini-hidden":{"isInternal":true,"quotaInfo":{"remainingFraction":1}}
     }}
    """#
    static func json(_ text: String) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
    }
}

final class AntigravityQuotaTests: XCTestCase {
    func testCarbonHydrogenAndSelectableGoogleOrchestrators() {
        // Synthetic API fixture using screenshot model labels, not a captured server response.
        let data = GeminiQuotaFixture.json(#"""
        {"tieredModelIds":{"carbon":["gemini-4-carbon-medium"],"hydrogen":["gemini-4-hydrogen-medium"],"flashLite":["google-auxiliary"]},
         "agentModelSorts":[{"groups":[{"modelIds":["orchestrator-carbon","orchestrator-argon","claude-opus","google-internal"]}]}],
         "models":{
           "gemini-4-carbon-medium":{"displayName":"Gemini 4 Carbon Medium","quotaInfo":{"remainingFraction":0.98}},
           "gemini-4-hydrogen-medium":{"displayName":"Gemini 4 Hydrogen Medium"},
           "orchestrator-carbon":{"displayName":"Orchestrator (Carbon)","modelProvider":"MODEL_PROVIDER_GOOGLE","quotaInfo":{"remainingFraction":0.98}},
           "orchestrator-argon":{"displayName":"Orchestrator (Argon)","modelProvider":"MODEL_PROVIDER_GOOGLE","quotaInfo":{"remainingFraction":0}},
           "claude-opus":{"displayName":"Claude Opus 5.5","quotaInfo":{"remainingFraction":0}},
           "google-internal":{"modelProvider":"MODEL_PROVIDER_GOOGLE","isInternal":true},
           "google-auxiliary":{"modelProvider":"MODEL_PROVIDER_GOOGLE"},
           "google-retired":{"modelProvider":"MODEL_PROVIDER_GOOGLE"}}}
        """#)
        let rows = QuotaParser.antigravityGeminiModels(data)
        XCTAssertEqual(rows.map(\.label), ["Gemini 4 Carbon", "Gemini 4 Hydrogen", "Orchestrator (Argon)", "Orchestrator (Carbon)"])
        XCTAssertEqual(rows.map(\.remaining), [98, nil, 0, 98])
        let summary = QuotaParser.antigravity(GeminiQuotaFixture.json(#"""
        {"groups":[{"displayName":"Gemini Models","buckets":[
          {"displayName":"Weekly limit","remainingFraction":1},
          {"displayName":"5h limit","remainingFraction":0.98}]},
          {"displayName":"Claude and GPT models","buckets":[
          {"displayName":"Weekly limit","remainingFraction":0},
          {"displayName":"5h limit","remainingFraction":1}]}]}
        """#))
        XCTAssertEqual(summary.windows.map(\.remaining), [100, 98, 0, 100])
        XCTAssertTrue(QuotaParser.antigravityMissingGeminiModels(data, summary: summary).isEmpty,
                      "Orchestrator names must not invent additional pools beside the shared Google summary")
        XCTAssertEqual(summary.remaining, 0)
    }

    // Synthetic payload using the labels in the updated Google usage panel.
    func testShortUsageLabelsKeepBothPoolsAndResetTimes() {
        let data = GeminiQuotaFixture.json(#"""
        {"response":{"groups":[
          {"displayName":"Gemini Models","buckets":[
            {"displayName":"Weekly limit","remainingFraction":0.71,"resetTime":"2030-01-08T00:00:00Z"},
            {"displayName":"5h limit","remaining":{"remainingFraction":0.15,"resetsAt":"2030-01-01T05:00:00Z"}}]},
          {"displayName":"Claude and GPT models","buckets":[
            {"displayName":"Weekly limit","remainingFraction":1},
            {"displayName":"5h limit","remainingFraction":1}]}]}}
        """#)
        let snapshot = QuotaParser.antigravity(data)
        XCTAssertEqual(snapshot.windows.map(\.label), ["Gemini · 每周", "Gemini · 5 小时", "Claude / GPT · 每周", "Claude / GPT · 5 小时"])
        XCTAssertEqual(snapshot.windows.map(\.remaining), [71, 15, 100, 100])
        XCTAssertEqual(snapshot.windows[0].reset, QuotaParser.date("2030-01-08T00:00:00Z"))
        XCTAssertEqual(snapshot.windows[1].reset, QuotaParser.date("2030-01-01T05:00:00Z"))
        XCTAssertNil(snapshot.windows[2].reset)
        XCTAssertEqual(QuotaSummary(snapshot.windows).fiveHour?.remaining, 15)
    }

    func testHourLabelsDoNotMisclassifyOtherDurationsOrUnknownQuota() {
        for label in ["5h", "5h limit", "5 hour limit", "Five Hour Limit Remaining", "five-hour limit"] {
            let snapshot = QuotaParser.antigravity(["groups": [["displayName": "Gemini Models", "buckets": [["displayName": label], ["displayName": label, "remainingFraction": 0]]]]])
            XCTAssertEqual(snapshot.windows.map(\.label), ["Gemini · 5 小时", "Gemini · 5 小时"])
            XCTAssertNil(snapshot.windows[0].remaining)
            XCTAssertEqual(snapshot.windows[1].remaining, 0)
        }
        for label in ["15h limit", "25h", "fifteen hours", "five models"] {
            let snapshot = QuotaParser.antigravity(["groups": [["displayName": "Gemini Models", "buckets": [["displayName": label]]]]])
            XCTAssertEqual(snapshot.windows.first?.label, "Gemini · " + label)
        }
    }

    func testClientIdentityTracksInstalledVersionWithoutInventingHubForLegacyApps() {
        let hub = Data("'--subclient_type', 'hub'".utf8)
        XCTAssertEqual(Installation.antigravityUserAgent(from: hub, version: "2.24.0"), "antigravity/hub/2.24.0 (os_type=darwin; arch=arm64)")
        XCTAssertEqual(Installation.antigravityUserAgent(from: Data(), version: "1.99.0"), "antigravity/1.99.0 (os_type=darwin; arch=arm64)")
        XCTAssertEqual(Installation.antigravityUserAgent(from: Data("'--subclient_type', 'ide'".utf8), version: "2.25.1"), "antigravity/2.25.1 (os_type=darwin; arch=arm64)")
        for version in [nil, "", "2.24.0\r\nX-Injected: yes"] as [String?] {
            XCTAssertEqual(Installation.antigravityUserAgent(from: hub, version: version), "antigravity")
        }
    }

    func testLatestSummaryKeepsIndependentArgonAndSharedClaude55Pools() throws {
        let summary = QuotaParser.antigravity(GeminiQuotaFixture.json(GeminiQuotaFixture.latestSummary))
        XCTAssertEqual(summary.windows.map(\.label), ["Gemini · 每周", "Gemini · 5 小时", "Claude / GPT · 每周", "Claude / GPT · 5 小时", "Gemini 4 Argon · 每周"])
        XCTAssertEqual(summary.windows.map(\.remaining), [80, 100, 42, 0, 60])
        XCTAssertEqual(summary.windows.last?.reset, QuotaParser.date("2030-01-08T00:00:00Z"))
        XCTAssertTrue(QuotaParser.antigravityMissingGeminiModels(GeminiQuotaFixture.json(GeminiQuotaFixture.latestModels), summary: summary).isEmpty)
    }

    func testCurrentGoogleUsagePanelKeepsAllFivePoolsIncludingExhaustedArgon() {
        // Sanitized mirror of the current Google usage panel; account details and real timestamps are excluded.
        let data = GeminiQuotaFixture.json(#"""
        {"groups":[
          {"displayName":"Gemini Models","buckets":[
            {"displayName":"Weekly Limit Remaining","remainingFraction":0.93,"resetTime":"2030-01-04T09:00:00Z"},
            {"displayName":"Five Hour Limit Remaining","remainingFraction":1}]},
          {"displayName":"Claude and GPT models","buckets":[
            {"displayName":"Weekly Limit Remaining","remainingFraction":0.47,"resetTime":"2030-01-07T17:00:00Z"},
            {"displayName":"Five Hour Limit Remaining","remainingFraction":1}]},
          {"displayName":"Gemini 4 Argon","buckets":[
            {"displayName":"Gemini 4 Argon Weekly Limit","remainingFraction":0,"resetTime":"2030-01-04T09:00:00Z"}]}]}
        """#)
        let snapshot = QuotaParser.antigravity(data)
        XCTAssertEqual(snapshot.windows.map(\.label), ["Gemini · 每周", "Gemini · 5 小时", "Claude / GPT · 每周", "Claude / GPT · 5 小时", "Gemini 4 Argon · 每周"])
        XCTAssertEqual(snapshot.windows.map(\.remaining), [93, 100, 47, 100, 0])
        XCTAssertEqual(snapshot.windows[0].reset, QuotaParser.date("2030-01-04T09:00:00Z"))
        XCTAssertEqual(snapshot.windows[2].reset, QuotaParser.date("2030-01-07T17:00:00Z"))
        XCTAssertEqual(snapshot.windows[4].reset, QuotaParser.date("2030-01-04T09:00:00Z"))
        XCTAssertEqual(snapshot.remaining, 0, "An exhausted Argon pool must remain a real zero, not unknown or omitted")
    }

    func testNestedRemainingAndResetTimeParsing() {
        let json: [String: Any] = [
            "groups": [
                [
                    "displayName": "Claude and GPT models",
                    "buckets": [
                        [
                            "displayName": "Weekly Limit Remaining",
                            "window": "weekly",
                            "remaining": ["remainingFraction": 0.84, "resetTime": "2030-01-08T00:00:00Z"]
                        ]
                    ]
                ]
            ]
        ]
        let snapshot = QuotaParser.antigravity(json)
        XCTAssertEqual(snapshot.windows.first?.remaining, 84)
        XCTAssertEqual(snapshot.windows.first?.reset, QuotaParser.date("2030-01-08T00:00:00Z"))
    }

    func testPartialSummariesOnlySuppressTheirOwnPools() {
        let models = GeminiQuotaFixture.json(GeminiQuotaFixture.latestModels)
        let full = QuotaParser.antigravity(GeminiQuotaFixture.json(GeminiQuotaFixture.latestSummary))
        let sharedOnly = Snapshot(windows: Array(full.windows.prefix(4)))
        XCTAssertEqual(QuotaParser.antigravityMissingGeminiModels(models, summary: sharedOnly).map(\.label), ["Gemini 4 Argon"])
        let argonOnly = Snapshot(windows: Array(full.windows.suffix(1)))
        XCTAssertEqual(QuotaParser.antigravityMissingGeminiModels(models, summary: argonOnly).map(\.label), ["Gemini 3.8 Flash"])
        var unknown = full
        unknown.windows[4].remaining = nil
        XCTAssertTrue(QuotaParser.antigravityMissingGeminiModels(models, summary: unknown).isEmpty, "An unknown authoritative quota must not be replaced with a fallback percentage")
    }

    func testReasoningVariantsCollapseOnlyWhenQuotaAndResetAgree() {
        var data = GeminiQuotaFixture.json(GeminiQuotaFixture.latestModels)
        let rows = QuotaParser.antigravityGeminiModels(data)
        XCTAssertEqual(rows.map(\.label), ["Gemini 3.8 Flash", "Gemini 4 Argon"])
        XCTAssertEqual(rows.last?.id, "gemini-model-gemini-4-argon")
        var models = data["models"] as! [String: [String: Any]]
        models["gemini-4-argon-low"]?["quotaInfo"] = ["remainingFraction": 0]
        data["models"] = models
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(data).count, 4)
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(data).first { $0.label.contains("Low") }?.remaining, 0)
        data["agentModelSorts"] = []
        data["defaultAgentModelId"] = "claude-opus-5-5-medium"
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(data).map(\.label), ["Gemini 3.8 Flash", "Gemini 4 Argon"], "Argon is also discoverable through a main model tier")
    }

    func testTieredGeminiMissingFromSummaryIsRestoredWithoutAliases() throws {
        let summary = QuotaParser.antigravity(GeminiQuotaFixture.json(GeminiQuotaFixture.summary))
        XCTAssertFalse(QuotaParser.hasGeminiQuota(summary))
        let rows = QuotaParser.antigravityGeminiModels(GeminiQuotaFixture.json(GeminiQuotaFixture.models))
        XCTAssertEqual(rows.map(\.label), ["Gemini 3.8 Flash"])
        XCTAssertEqual(rows.count, 1, "Exclude auxiliary flashLite and deduplicate the pro/flash main model")
        XCTAssertEqual(rows[0].remaining, 95)
        XCTAssertEqual(rows[0].reset, QuotaParser.date("2030-01-01T06:00:00Z"))
        XCTAssertEqual(summary.windows.map(\.remaining), [42, 100], "Third-party windows stay separate")
    }

    func testLiteIsRetainedWhenExplicitlySelectableRatherThanVersionBlocked() {
        var data = GeminiQuotaFixture.json(GeminiQuotaFixture.models)
        data["agentModelSorts"] = [["groups": [["modelIds": ["gemini-3.5-flash-lite"]]]]]
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(data).map(\.label), ["Gemini 3.5 Flash Lite", "Gemini 3.8 Flash"])
        data["agentModelSorts"] = []
        data["defaultAgentModelId"] = "gemini-3.5-flash-lite"
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(data).count, 2)
    }

    func testAuxiliaryTierDoesNotBecomeQuotaJustBecauseOtherTiersAreMissing() {
        var data = GeminiQuotaFixture.json(GeminiQuotaFixture.models)
        data["tieredModelIds"] = ["flashLite": ["gemini-3.5-flash-lite"]]
        XCTAssertTrue(QuotaParser.antigravityGeminiModels(data).isEmpty)
    }

    func testUnknownFractionsStayUnknownAndTrueZeroSurvives() {
        for value: Any in [NSNull(), true, -0.1, 1.1, "0.5"] {
            let data: [String: Any] = ["models": ["gemini-example": ["quotaInfo": ["remainingFraction": value]]]]
            XCTAssertNil(QuotaParser.antigravityGeminiModels(data).first?.remaining)
        }
        let missing: [String: Any] = ["models": ["gemini-example": [:]]]
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(missing).count, 1)
        XCTAssertNil(QuotaParser.antigravityGeminiModels(missing)[0].remaining)
        let zero: [String: Any] = ["models": ["gemini-example": ["quotaInfo": ["remainingFraction": 0]]]]
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(zero)[0].remaining, 0)
    }

    func testFutureDefaultModelAndStableIDs() throws {
        let data = GeminiQuotaFixture.json(GeminiQuotaFixture.models)
        let rows = QuotaParser.antigravityGeminiModels(data)
        XCTAssertEqual(rows.map(\.id), QuotaParser.antigravityGeminiModels(["response": data]).map(\.id))
        let future: [String: Any] = ["defaultAgentModelId": "gemini-4-example", "agentModelSorts": [],
                                  "models": ["gemini-4-example": ["displayName": "Gemini Future", "quotaInfo": ["remainingFraction": 0.7]],
                                             "gemini-hidden": ["isInternal": true, "quotaInfo": ["remainingFraction": 1]]]]
        XCTAssertEqual(QuotaParser.antigravityGeminiModels(future).map(\.label), ["Gemini Future"])
        XCTAssertTrue(QuotaParser.hasGeminiQuota(QuotaParser.antigravity(["groups": [["displayName": "Gemini Models", "buckets": [["remainingFraction": 0.5]]]]])))
    }

    func testNeonTierXHighExtraLowCollapseAndUnknownVsRealZero() {
        let reset = "2030-01-08T00:00:00Z"
        let basePayload = GeminiQuotaFixture.json(#"""
        {
          "tieredModelIds": {
            "neon": ["gemini-4-neon-low", "gemini-4-neon-medium", "gemini-4-neon-high", "gemini-4-neon-xhigh"],
            "hydrogen": ["gemini-4-hydrogen-tiered-high", "gemini-4-hydrogen-tiered-xhigh"],
            "flash": ["gemini-3.8-flash-tiered", "gemini-3.5-flash-extra-low"]
          },
          "agentModelSorts": [
            {"groups": [{"modelIds": ["orchestrator-neon"]}]}
          ],
          "models": {
            "gemini-4-neon-low": {"displayName": "Gemini 4 Neon (Low)", "quotaInfo": {"remainingFraction": 1, "resetTime": "2030-01-08T00:00:00Z"}},
            "gemini-4-neon-medium": {"displayName": "Gemini 4 Neon (Medium)", "quotaInfo": {"remainingFraction": 1, "resetTime": "2030-01-08T00:00:00Z"}},
            "gemini-4-neon-high": {"displayName": "Gemini 4 Neon (High)", "quotaInfo": {"remainingFraction": 1, "resetTime": "2030-01-08T00:00:00Z"}},
            "gemini-4-neon-xhigh": {"displayName": "Gemini 4 Neon (XHigh)", "quotaInfo": {"remainingFraction": 1, "resetTime": "2030-01-08T00:00:00Z"}},
            "gemini-4-hydrogen-tiered-high": {"quotaInfo": {"remainingFraction": 0.5, "resetTime": "2030-01-08T00:00:00Z"}},
            "gemini-4-hydrogen-tiered-xhigh": {"quotaInfo": {"remainingFraction": 0.5, "resetTime": "2030-01-08T00:00:00Z"}},
            "gemini-3.8-flash-tiered": {"quotaInfo": {"remainingFraction": 0.9}},
            "gemini-3.5-flash-extra-low": {"quotaInfo": {"remainingFraction": 0.8, "resetTime": "2030-01-08T00:00:00Z"}},
            "orchestrator-neon": {"displayName": "Orchestrator (Neon)", "modelProvider": "MODEL_PROVIDER_GOOGLE", "quotaInfo": {"remainingFraction": 1, "resetTime": "2030-01-08T00:00:00Z"}}
          }
        }
        """#)
        let collapsed = QuotaParser.antigravityGeminiModels(basePayload)
        XCTAssertEqual(collapsed.map(\.label), ["Gemini 3.5 Flash", "Gemini 3.8 Flash", "Gemini 4 Hydrogen", "Gemini 4 Neon", "Orchestrator (Neon)"])
        XCTAssertEqual(collapsed.map(\.id), [
            "gemini-model-gemini-3.5-flash",
            "gemini-model-gemini-3.8-flash-tiered",
            "gemini-model-gemini-4-hydrogen",
            "gemini-model-gemini-4-neon",
            "gemini-model-orchestrator-neon"
        ])
        XCTAssertEqual(collapsed.first { $0.label == "Gemini 4 Neon" }?.remaining, 100)
        XCTAssertEqual(collapsed.first { $0.label == "Gemini 4 Hydrogen" }?.reset, QuotaParser.date(reset))

        var diverged = basePayload
        var models = diverged["models"] as! [String: [String: Any]]
        models["gemini-4-neon-xhigh"]?["quotaInfo"] = ["remainingFraction": 0, "resetTime": reset]
        models["gemini-4-hydrogen-tiered-xhigh"]?["quotaInfo"] = ["remainingFraction": NSNull(), "resetTime": reset]
        diverged["models"] = models
        let split = QuotaParser.antigravityGeminiModels(diverged)
        XCTAssertEqual(split.first { $0.label == "Gemini 4 Neon (XHigh)" }?.remaining, 0)
        XCTAssertEqual(split.first { $0.label == "Gemini 4 Neon (High)" }?.remaining, 100)
        XCTAssertEqual(split.first { $0.label == "Gemini 4 Hydrogen High" }?.remaining, 50)
        XCTAssertNil(split.first { $0.label == "Gemini 4 Hydrogen Xhigh" }?.remaining, "Unknown xhigh quota must remain nil rather than collapsing or becoming 0%")
    }

    func testSummarySkipsDisabledBucketsAndFallsBackToTopLevelBuckets() {
        let grouped = GeminiQuotaFixture.json(#"""
        {
          "groups": [
            {"displayName": "Gemini Models", "buckets": [
              {"displayName": "Weekly Limit Remaining", "window": "weekly", "remainingFraction": 0},
              {"displayName": "Disabled Bucket", "window": "5h", "disabled": true, "remainingFraction": 0.9}
            ]},
            {"displayName": "Claude and GPT models", "buckets": [
              {"displayName": "Five Hour Limit Remaining", "window": "5h", "remainingFraction": null}
            ]}
          ]
        }
        """#)
        let summary = QuotaParser.antigravity(grouped)
        XCTAssertEqual(summary.windows.map(\.label), ["Gemini · 每周", "Claude / GPT · 5 小时"])
        XCTAssertEqual(summary.windows[0].remaining, 0, "Real 0 remainingFraction must remain 0")
        XCTAssertNil(summary.windows[1].remaining, "Null remainingFraction must remain nil/unknown")

        let topLevel = GeminiQuotaFixture.json(#"""
        {
          "response": {
            "buckets": [
              {"displayName": "Weekly Limit Remaining", "window": "weekly", "remainingFraction": 0.65, "resetTime": "2030-01-08T00:00:00Z"},
              {"displayName": "Retired Limit", "window": "5h", "disabled": true, "remainingFraction": 0}
            ]
          }
        }
        """#)
        let fallback = QuotaParser.antigravity(topLevel)
        XCTAssertEqual(fallback.windows.map(\.label), ["模型组 · 每周"])
        XCTAssertEqual(fallback.windows.map(\.remaining), [65])
        XCTAssertEqual(fallback.windows.first?.reset, QuotaParser.date("2030-01-08T00:00:00Z"))
    }
}

private final class GeminiQuotaProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        let access = request.value(forHTTPHeaderField: "Authorization") ?? ""
        // Real 2.24.0 behavior: this account receives Argon only for the desktop hub client.
        let hub = request.value(forHTTPHeaderField: "User-Agent") == "antigravity/hub/2.25.1 (os_type=darwin; arch=arm64)"
        let latest = access.contains("latest") || (access.contains("client-gated") && hub)
        var code = 200
        let body: String
        if url.host == "openidconnect.googleapis.com" { body = #"{"sub":"fixture-subject"}"# }
        else if url.host != "daily-cloudcode-pa.googleapis.com" { code = 400; body = "{}" }
        else if url.path.contains("loadCodeAssist") { body = #"{"cloudaicompanionProject":"fixture-project"}"# }
        else if url.path.contains("retrieveUserQuotaSummary") {
            if latest {
                var data = GeminiQuotaFixture.json(GeminiQuotaFixture.latestSummary)
                let groups = data["groups"] as! [[String: Any]]
                if access.contains("shared") { data["groups"] = Array(groups.prefix(2)) }
                if access.contains("argon") { data["groups"] = Array(groups.suffix(1)) }
                body = String(decoding: try! JSONSerialization.data(withJSONObject: data), as: UTF8.self)
            } else { body = GeminiQuotaFixture.summary }
        }
        else if url.path.contains("fetchAvailableModels") {
            if access.contains("failure") { code = 503 }
            body = latest ? GeminiQuotaFixture.latestModels : GeminiQuotaFixture.models
        } else { code = 400; body = "{}" }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class AntigravityGeminiReaderTests: XCTestCase {
    func testInstalledHubClientReceivesIndependentArgonQuota() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Fixture.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/Resources"), withIntermediateDirectories: true)
        try Data("'--subclient_type',\n 'hub', '--cloud_code_endpoint', 'https://daily-cloudcode-pa.googleapis.com'".utf8).write(to: app.appendingPathComponent("Contents/Resources/app.asar"))
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleShortVersionString": "2.25.1"], format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        let credential = root.appendingPathComponent("fixture.json")
        try JSONSerialization.data(withJSONObject: ["token": ["access_token": "fixture-client-gated", "refresh_token": "fixture", "expiry": "2099-01-01T00:00:00Z"]]).write(to: credential)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [GeminiQuotaProtocol.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let instance = AntigravityInstance(appPath: app.path, credentialPath: credential.path, name: "Fixture", manual: true)
        let reader = QuotaReader(googleInstance: instance, session: session)
        let snapshot = try await reader.fetch(.antigravity, expectedGoogleSubject: "fixture-subject")
        XCTAssertEqual(snapshot.windows.count, 5)
        XCTAssertEqual(snapshot.windows.last?.label, "Gemini 4 Argon · 每周")
        XCTAssertEqual(snapshot.windows.last?.remaining, 60)
    }

    func testReaderCombinesSameEnvironmentSourcesAndPropagatesModelFailure() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("Fixture.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/Resources"), withIntermediateDirectories: true)
        try Data("--cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com".utf8).write(to: app.appendingPathComponent("Contents/Resources/app.asar"))
        let credential = root.appendingPathComponent("fixture.json")
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [GeminiQuotaProtocol.self]
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let instance = AntigravityInstance(appPath: app.path, credentialPath: credential.path, name: "Fixture", manual: true)
        for access in ["fixture-success", "fixture-failure", "fixture-latest", "fixture-latest-shared", "fixture-latest-argon", "fixture-latest-failure"] {
            try JSONSerialization.data(withJSONObject: ["token": ["access_token": access, "refresh_token": "fixture", "expiry": "2099-01-01T00:00:00Z"]]).write(to: credential)
            let reader = QuotaReader(googleInstance: instance, session: session)
            do {
                let snapshot = try await reader.fetch(.antigravity, expectedGoogleSubject: "fixture-subject")
                XCTAssertFalse(access.contains("failure"), "A failed Gemini lookup must not silently hide its rows")
                if access.contains("latest") {
                    XCTAssertEqual(snapshot.windows.count, access.contains("argon") ? 2 : 5)
                    XCTAssertEqual(snapshot.windows.filter { $0.label.contains("Argon") }.count, 1)
                    XCTAssertTrue(snapshot.windows.contains { $0.label == "Gemini 3.8 Flash" || $0.label == "Gemini · 每周" })
                    continue
                }
                XCTAssertEqual(snapshot.windows.count, 3)
                XCTAssertEqual(snapshot.windows.first?.remaining, 95)
                XCTAssertEqual(snapshot.windows.last?.label, "Claude / GPT · 5 小时")
            } catch {
                XCTAssertTrue(access.contains("failure"), "Both reads must use the installed endpoint")
            }
        }
    }
}
