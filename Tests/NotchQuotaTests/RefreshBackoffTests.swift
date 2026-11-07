import XCTest
@testable import NotchQuota
final class RefreshBackoffTests: XCTestCase {
    func testFailureBackoffSuccessAndServerRetryAfter() {
        var policy = RefreshBackoff()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(policy.allows(now))
        policy.failed(now: now)
        XCTAssertFalse(policy.allows(now.addingTimeInterval(29)))
        XCTAssertTrue(policy.allows(now.addingTimeInterval(30)))
        policy.failed(now: now)
        XCTAssertEqual(policy.retryAt, now.addingTimeInterval(60))
        policy.failed(now: now, retryAfter: 3600)
        XCTAssertFalse(policy.allows(now.addingTimeInterval(3599)))
        policy.succeeded(); XCTAssertTrue(policy.allows(now))
        policy.failed(now: now); XCTAssertEqual(policy.retryAt, now.addingTimeInterval(30))
    }
    func testRetryAfterAcceptsSecondsAndHTTPDatesAndBoundsUntrustedValues() {
        let now = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(RefreshBackoff.retryDelay("120", now: now), 120)
        XCTAssertEqual(RefreshBackoff.retryDelay("Thu, 01 Jan 1970 00:05:00 GMT", now: now), 300)
        XCTAssertEqual(RefreshBackoff.retryDelay("-20", now: now), 30)
        XCTAssertEqual(RefreshBackoff.retryDelay("nan", now: now), 180)
        XCTAssertEqual(RefreshBackoff.retryDelay("9000000", now: now), 86400)
    }
}
