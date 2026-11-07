import Foundation

struct RefreshBackoff {
    private var failures = 0
    private(set) var retryAt: Date?
    mutating func failed(now: Date, retryAfter: TimeInterval? = nil) {
        failures = min(7, failures + 1)
        let interval = max(min(1800, 30 * pow(2, Double(failures - 1))), retryAfter ?? 0)
        retryAt = now.addingTimeInterval(interval)
    }
    mutating func succeeded() { failures = 0; retryAt = nil }
    func allows(_ now: Date) -> Bool { retryAt.map { now >= $0 } ?? true }
    static func retryDelay(_ header: String?, now: Date = Date()) -> TimeInterval {
        guard let header else { return 180 }
        if let seconds = Double(header), seconds.isFinite { return min(86400, max(30, seconds)) }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.date(from: header).map { min(86400, max(30, $0.timeIntervalSince(now))) } ?? 180
    }
}
