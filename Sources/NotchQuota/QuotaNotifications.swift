import Foundation
import CryptoKit
import UserNotifications

struct QuotaNoticePreferences: Codable, Equatable {
    var enabled = false
    var threshold = 20
    var recovery = false
    var quietEnabled = true
    var quietStart = 22
    var quietEnd = 8
    var mutedAccounts: Set<String> = []
    func isQuiet(hour: Int) -> Bool {
        guard quietEnabled else { return false }
        if quietStart == quietEnd { return true }
        return quietStart < quietEnd ? (quietStart..<quietEnd).contains(hour) : hour >= quietStart || hour < quietEnd
    }
}

/// No credentials, account names, or raw service payloads enter this state.
/// A new account/window needs a successful baseline before it may notify.
struct QuotaNoticeTracker {
    struct Reading { let value: Double; let reset: Date?; let fetched: Date }
    var previous: [String: Reading] = [:]
    var delivered: Set<String> = []
    struct Event: Equatable { let window: String; let recovered: Bool; let remaining: Int }
    mutating func observe(account: String, snapshot: Snapshot, preferences: QuotaNoticePreferences, now: Date) -> [Event] {
        guard now.timeIntervalSince(snapshot.fetchedAt) >= -5, now.timeIntervalSince(snapshot.fetchedAt) <= 600 else { return [] }
        var events: [Event] = []
        for window in snapshot.windows {
            guard let value = window.remaining, value.isFinite, (0...100).contains(value) else { continue }
            let key = Self.digest(account) + ":" + Self.digest(window.id)
            let old = previous[key]
            guard old == nil || snapshot.fetchedAt > old!.fetched else { continue }
            previous[key] = Reading(value: value, reset: window.reset, fetched: snapshot.fetchedAt)
            // Include the provider cycle so deduplication survives an app restart across resets.
            let cycle = window.reset.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "unspecified"
            let lowKey = key + ":low:\(preferences.threshold):" + cycle
            let recoveryKey = key + ":recovery:" + cycle
            // Reset moves forward at a cycle boundary. Reaching full also rearms low alerts.
            let newCycle = old?.reset.map { previousReset in
                window.reset.map { $0.timeIntervalSince(previousReset) > 60 && now >= previousReset } ?? false
            } ?? false
            if newCycle || value == 100 { delivered = delivered.filter { !$0.hasPrefix(key + ":low:") } }
            if newCycle { delivered.remove(recoveryKey) }
            guard let old, now.timeIntervalSince(old.fetched) <= 600 else { continue }
            let low = value <= Double(preferences.threshold) && old.value > Double(preferences.threshold)
            let recovered = value == 100 && old.value < 100
            guard preferences.enabled, !preferences.mutedAccounts.contains(account) else { continue }
            let eventKey: String
            if low { eventKey = lowKey }
            else if recovered && preferences.recovery { eventKey = recoveryKey }
            else { continue }
            guard delivered.insert(eventKey).inserted else { continue }
            // Quiet-hour events are consumed, never queued for a burst in the morning.
            if !preferences.isQuiet(hour: Calendar.current.component(.hour, from: now)) {
                events.append(Event(window: window.label, recovered: recovered, remaining: Int(value.rounded())))
            }
        }
        return events
    }
    static func digest(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    mutating func forget(account: String) {
        // Baselines are intentionally discarded when an identity/selection changes.
        let prefix = Self.digest(account) + ":"
        previous = previous.filter { !$0.key.hasPrefix(prefix) }
        delivered = delivered.filter { !$0.hasPrefix(prefix) }
    }
}

@MainActor final class QuotaNotifications {
    private let defaults: UserDefaults
    private var tracker = QuotaNoticeTracker()
    private(set) var preferences: QuotaNoticePreferences
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = defaults.data(forKey: "quotaNotices").flatMap { try? JSONDecoder().decode(QuotaNoticePreferences.self, from: $0) } ?? .init()
        preferences.threshold = [10, 20].contains(preferences.threshold) ? preferences.threshold : 20
        preferences.quietStart = min(23, max(0, preferences.quietStart))
        preferences.quietEnd = min(23, max(0, preferences.quietEnd))
        tracker.delivered = Set(defaults.stringArray(forKey: "quotaNoticeDelivered") ?? [])
    }
    func save(_ value: QuotaNoticePreferences) {
        preferences = value
        defaults.set(try? JSONEncoder().encode(value), forKey: "quotaNotices")
    }
    func forget(account: String) { tracker.forget(account: account) }
    func observe(_ snapshot: Snapshot, account: String, title: String, now: Date = Date()) {
        let events = tracker.observe(account: account, snapshot: snapshot, preferences: preferences, now: now)
        // Bound old records; only opaque hashes and event types are persisted.
        if tracker.delivered.count > 512 { tracker.delivered.removeAll() }
        defaults.set(Array(tracker.delivered), forKey: "quotaNoticeDelivered")
        guard !events.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = events.map { event in
            event.recovered ? L10n.format("{0}已恢复至 100%", L10n.quotaLabel(event.window)) : L10n.format("{0}剩余 {1}%", L10n.quotaLabel(event.window), String(event.remaining))
        }.joined(separator: "\n")
        // No sound, automatic app launch, account switching, or additional requests.
        let request = UNNotificationRequest(identifier: QuotaNoticeTracker.digest(account) + UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
