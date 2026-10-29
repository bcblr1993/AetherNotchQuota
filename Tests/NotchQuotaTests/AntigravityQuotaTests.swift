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
