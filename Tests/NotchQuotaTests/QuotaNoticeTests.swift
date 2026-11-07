import XCTest
@testable import NotchQuota

final class QuotaNoticeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func snapshot(_ value: Double?, at date: Date, reset: Date? = nil) -> Snapshot {
        Snapshot(windows: [.init(id: "weekly", label: "每周", remaining: value, reset: reset)], fetchedAt: date)
    }
    private var enabled: QuotaNoticePreferences {
        var value = QuotaNoticePreferences(); value.enabled = true; value.quietEnabled = false; value.recovery = true; return value
    }
    func testNewCycleAfterRestartAndIdentityChangeDoNotReuseBaselines() {
        var tracker = QuotaNoticeTracker()
        let reset = now.addingTimeInterval(300)
        _ = tracker.observe(account: "a", snapshot: snapshot(50, at: now, reset: reset), preferences: enabled, now: now)
        let first = now.addingTimeInterval(60)
        XCTAssertEqual(tracker.observe(account: "a", snapshot: snapshot(10, at: first, reset: reset), preferences: enabled, now: first).count, 1)
        var restarted = QuotaNoticeTracker(); restarted.delivered = tracker.delivered
        let next = now.addingTimeInterval(400), newReset = reset.addingTimeInterval(3600)
        _ = restarted.observe(account: "a", snapshot: snapshot(50, at: next, reset: newReset), preferences: enabled, now: next)
        let crossed = next.addingTimeInterval(60)
        XCTAssertEqual(restarted.observe(account: "a", snapshot: snapshot(10, at: crossed, reset: newReset), preferences: enabled, now: crossed).count, 1)
        restarted.forget(account: "a")
        let changed = crossed.addingTimeInterval(60)
        XCTAssertTrue(restarted.observe(account: "a", snapshot: snapshot(100, at: changed, reset: newReset), preferences: enabled, now: changed).isEmpty)
    }
    @MainActor func testDiagnosticSummaryNeverIncludesRawErrorsIdentityPathsOrQuotaValues() {
        let app = AppDelegate()
        app.visibleTargets = [.codex]
        app.accountNames["codex"] = "private@example.test"
        app.states[.codex] = DisplayState(snapshot: snapshot(37, at: now), error: "secret-token /private/path")
        let summary = app.diagnosticSummary()
        XCTAssertFalse(summary.contains("private")); XCTAssertFalse(summary.contains("secret")); XCTAssertFalse(summary.contains("37"))
        XCTAssertTrue(summary.contains("error=true")); XCTAssertTrue(summary.contains("windows=1"))
    }
    func testFirstReadUnknownStaleAndDuplicateCannotNotify() {
        var tracker = QuotaNoticeTracker()
        XCTAssertTrue(tracker.observe(account: "a", snapshot: snapshot(5, at: now), preferences: enabled, now: now).isEmpty)
        XCTAssertTrue(tracker.observe(account: "a", snapshot: snapshot(nil, at: now.addingTimeInterval(60)), preferences: enabled, now: now.addingTimeInterval(60)).isEmpty)
        XCTAssertTrue(tracker.observe(account: "a", snapshot: snapshot(100, at: now.addingTimeInterval(-1000)), preferences: enabled, now: now).isEmpty)
        XCTAssertTrue(tracker.observe(account: "a", snapshot: snapshot(100, at: now), preferences: enabled, now: now).isEmpty)
    }
    func testCrossingDeduplicationRecoveryAndAccountIsolation() {
        var tracker = QuotaNoticeTracker()
        func observe(_ value: Double, _ time: Double, account: String = "a") -> [QuotaNoticeTracker.Event] {
            let date = now.addingTimeInterval(time)
            return tracker.observe(account: account, snapshot: snapshot(value, at: date), preferences: enabled, now: date)
        }
        XCTAssertTrue(observe(50, 0).isEmpty)
        XCTAssertEqual(observe(20, 60).count, 1)
        XCTAssertTrue(observe(18, 120).isEmpty)
        XCTAssertTrue(observe(50, 180).isEmpty)
        XCTAssertTrue(observe(10, 240).isEmpty, "No threshold jitter spam")
        XCTAssertTrue(observe(10, 240, account: "b").isEmpty, "Separate baseline")
        XCTAssertEqual(observe(100, 300).first?.recovered, true)
        XCTAssertTrue(observe(100, 360).isEmpty)
        XCTAssertEqual(observe(5, 420).first?.recovered, false)
    }
    func testQuietHoursConsumeEventsAndMutedAccountsStayQuiet() {
        var settings = enabled; settings.quietEnabled = true; settings.quietStart = 0; settings.quietEnd = 0
        var tracker = QuotaNoticeTracker()
        _ = tracker.observe(account: "a", snapshot: snapshot(50, at: now), preferences: settings, now: now)
        let later = now.addingTimeInterval(60)
        XCTAssertTrue(tracker.observe(account: "a", snapshot: snapshot(10, at: later), preferences: settings, now: later).isEmpty)
        XCTAssertFalse(tracker.delivered.isEmpty)
        settings.quietEnabled = false; settings.mutedAccounts = ["a"]
        let next = later.addingTimeInterval(60)
        XCTAssertTrue(tracker.observe(account: "a", snapshot: snapshot(100, at: next), preferences: settings, now: next).isEmpty)
        settings.quietEnabled = true; settings.quietStart = 22; settings.quietEnd = 8
        XCTAssertTrue(settings.isQuiet(hour: 23)); XCTAssertTrue(settings.isQuiet(hour: 7)); XCTAssertFalse(settings.isQuiet(hour: 8))
    }
    func testLongOutageCannotProduceRecoveryAndRestartKeepsDeduplication() {
        var tracker = QuotaNoticeTracker()
        _ = tracker.observe(account: "a", snapshot: snapshot(50, at: now), preferences: enabled, now: now)
        let later = now.addingTimeInterval(60)
        _ = tracker.observe(account: "a", snapshot: snapshot(10, at: later), preferences: enabled, now: later)
        var restarted = QuotaNoticeTracker(); restarted.delivered = tracker.delivered
        _ = restarted.observe(account: "a", snapshot: snapshot(50, at: later), preferences: enabled, now: later)
        let next = later.addingTimeInterval(60)
        XCTAssertTrue(restarted.observe(account: "a", snapshot: snapshot(10, at: next), preferences: enabled, now: next).isEmpty)
        let outage = next.addingTimeInterval(3600)
        XCTAssertTrue(restarted.observe(account: "a", snapshot: snapshot(100, at: outage), preferences: enabled, now: outage).isEmpty)
        XCTAssertTrue(restarted.delivered.allSatisfy { !$0.contains("weekly") })
    }
}
