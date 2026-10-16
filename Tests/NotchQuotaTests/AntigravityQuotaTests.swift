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
    static func json(_ text: String) -> [String: Any] {
        try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any]
    }
}

final class AntigravityQuotaTests: XCTestCase {
    func testTieredGeminiMissingFromSummaryIsRestoredWithoutAliases() throws {
        let summary = QuotaParser.antigravity(GeminiQuotaFixture.json(GeminiQuotaFixture.summary))
        XCTAssertFalse(QuotaParser.hasGeminiQuota(summary))
        let rows = QuotaParser.antigravityGeminiModels(GeminiQuotaFixture.json(GeminiQuotaFixture.models))
        XCTAssertEqual(rows.map(\.label), ["Gemini 3.5 Flash Lite", "Gemini 3.8 Flash"])
        XCTAssertEqual(rows.count, 2, "The same model in pro and flash tiers is shown once")
        XCTAssertEqual(rows[1].remaining, 95)
        XCTAssertEqual(rows[1].reset, QuotaParser.date("2030-01-01T06:00:00Z"))
        XCTAssertEqual(summary.windows.map(\.remaining), [42, 100], "Third-party windows stay separate")
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
        var code = 200
        let body: String
        if url.host == "openidconnect.googleapis.com" { body = #"{"sub":"fixture-subject"}"# }
        else if url.host != "daily-cloudcode-pa.googleapis.com" { code = 400; body = "{}" }
        else if url.path.contains("loadCodeAssist") { body = #"{"cloudaicompanionProject":"fixture-project"}"# }
        else if url.path.contains("retrieveUserQuotaSummary") { body = GeminiQuotaFixture.summary }
        else if url.path.contains("fetchAvailableModels") {
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-failure" { code = 503 }
            body = GeminiQuotaFixture.models
        } else { code = 400; body = "{}" }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class AntigravityGeminiReaderTests: XCTestCase {
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
        for access in ["fixture-success", "fixture-failure"] {
            try JSONSerialization.data(withJSONObject: ["token": ["access_token": access, "refresh_token": "fixture", "expiry": "2099-01-01T00:00:00Z"]]).write(to: credential)
            let reader = QuotaReader(googleInstance: instance, session: session)
            do {
                let snapshot = try await reader.fetch(.antigravity, expectedGoogleSubject: "fixture-subject")
                XCTAssertEqual(access, "fixture-success", "A failed Gemini lookup must not silently hide its rows")
                XCTAssertEqual(snapshot.windows.count, 4)
                XCTAssertEqual(snapshot.windows.first?.remaining, 95)
                XCTAssertEqual(snapshot.windows.last?.label, "Claude / GPT · 5 小时")
            } catch {
                XCTAssertEqual(access, "fixture-failure", "Both reads must use the installed endpoint")
            }
        }
    }
}
