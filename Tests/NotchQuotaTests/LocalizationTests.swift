import XCTest
@testable import NotchQuota

final class LocalizationTests: XCTestCase {
    func testSupportedLanguagesResolveRegionsAndUnsupportedLanguages() {
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["fr-FR", "ja-JP"]), .japanese)
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["zh-TW", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["en_GB"]), .english)
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["de-DE"]), .english)
        XCTAssertEqual(AppLanguage.resolve(.japanese, preferred: ["en-US"]), .japanese)
        XCTAssertEqual(AppLanguage.restored("not-a-language"), .system)
    }
    func testLanguagePreferencePersistsAndSystemRemovesOnlyAppOverride() {
        let suite = "NotchQuotaTests.Language." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("untouched", forKey: "accountAlias")
        AppLanguage.save(.japanese, to: defaults)
        XCTAssertEqual(AppLanguage.restored(defaults.string(forKey: AppLanguage.preferenceKey)), .japanese)
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["ja"])
        AppLanguage.save(.system, to: defaults)
        XCTAssertNil(defaults.persistentDomain(forName: suite)?["AppleLanguages"])
        XCTAssertEqual(defaults.string(forKey: "accountAlias"), "untouched")
    }
    func testEveryCatalogHasCompleteKeysAndMatchingInterpolationSlots() {
        let source = L10n.catalogs[.simplifiedChinese]!
        XCTAssertGreaterThan(source.count, 180)
        let regex = try! NSRegularExpression(pattern: #"\{\d+\}"#)
        func slots(_ text: String) -> [String] {
            let string = text as NSString
            return regex.matches(in: text, range: NSRange(location: 0, length: string.length)).map { string.substring(with: $0.range) }.sorted()
        }
        for language in AppLanguage.supported {
            let catalog = L10n.catalogs[language]!
            XCTAssertEqual(Set(catalog.keys), Set(source.keys))
            for (key, value) in catalog {
                XCTAssertFalse(value.isEmpty, key)
                XCTAssertEqual(slots(key), slots(value), key)
            }
        }
        XCTAssertEqual(L10n.text("刷新额度", language: .english), "Refresh Quota")
        XCTAssertEqual(L10n.text("刷新额度", language: .japanese), "利用枠を更新")
        XCTAssertEqual(L10n.text("missing-key", language: .english), "missing-key")
    }
    func testFormattingDoesNotInterpretPercentSignsOrInterpolateArgumentContents() {
        XCTAssertEqual(L10n.format("剩余{0}%", "0", language: .english), "0% remaining")
        XCTAssertEqual(L10n.render("{1} — {0}", arguments: ["literal {1}", "second"]), "second — literal {1}")
        XCTAssertEqual(L10n.format("额度服务暂不可用（{0}）", "403", language: .english), "Quota service unavailable (403)")
    }
    func testPresentationTranslatesCachedLabelsAndErrorsWithoutChangingDetection() {
        let snapshot = Snapshot(windows: [.init(id: "seven_day", label: "每周", remaining: 0)])
        let restored = Snapshot(windows: [.init(id: "seven_day", label: "每周", remaining: 100)])
        for language in AppLanguage.supported {
            XCTAssertEqual(L10n.quotaLabel("Gemini · 每周", language: language), "Gemini · " + L10n.text("每周", language: language))
            XCTAssertEqual(QuotaSummary(snapshot.windows).weekly?.remaining, 0)
            XCTAssertEqual(QuotaRecoveryDetector.restoredWindows(previous: snapshot, current: restored), ["每周"])
        }
        XCTAssertEqual(L10n.quotaLabel("Acme Model · 12 小时", language: .english), "Acme Model · 12 hours")
        XCTAssertEqual(L10n.quotaLabel("Custom Model", language: .japanese), "Custom Model")
        XCTAssertEqual(L10n.message("Codex 额度服务暂不可用（401）", language: .english), "Codex quota service unavailable (401)")
        XCTAssertEqual(L10n.message("Unknown provider error", language: .japanese), "Unknown provider error")
    }
}
