import Foundation

enum AppLanguage: String, CaseIterable {
    case system, simplifiedChinese = "zh-Hans", english = "en", japanese = "ja"
    static let preferenceKey = "appLanguage"
    static let supported: [Self] = [.simplifiedChinese, .english, .japanese]
    var title: String {
        switch self {
        case .system: return L10n.text("跟随系统")
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }
    static func restored(_ raw: String?) -> Self { raw.flatMap(Self.init(rawValue:)) ?? .system }
    static func resolve(_ selection: Self, preferred: [String]) -> Self {
        guard selection == .system else { return selection }
        for identifier in preferred {
            let prefix = identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first
            switch prefix {
            case "zh": return .simplifiedChinese
            case "en": return .english
            case "ja": return .japanese
            default: continue
            }
        }
        return .english
    }
    static let smokeSuite = "NotchQuota.LocalizationSmoke." + String(ProcessInfo.processInfo.processIdentifier)
    static let defaults: UserDefaults = {
        guard CommandLine.arguments.contains("--localization-smoke") else { return .standard }
        let defaults = UserDefaults(suiteName: smokeSuite)!
        defaults.removePersistentDomain(forName: smokeSuite)
        if let language = ProcessInfo.processInfo.environment["NOTCHQUOTA_LANGUAGE"] { defaults.set(language, forKey: preferenceKey) }
        return defaults
    }()
    static var selection: Self { restored(defaults.string(forKey: preferenceKey)) }
    static var effective: Self {
        // A test-only override never changes the user's language preferences.
        let isTest = CommandLine.arguments.contains("--ui-smoke") || CommandLine.arguments.contains("--sidebar-test")
        if isTest, let override = ProcessInfo.processInfo.environment["NOTCHQUOTA_LANGUAGE"], let language = Self(rawValue: override), language != .system { return language }
        let system = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String] ?? Locale.preferredLanguages
        return resolve(selection, preferred: system)
    }
    static func save(_ language: Self, to store: UserDefaults? = nil) {
        let defaults = store ?? Self.defaults
        defaults.set(language.rawValue, forKey: preferenceKey)
        if language == .system { defaults.removeObject(forKey: "AppleLanguages") }
        else { defaults.set([language.rawValue], forKey: "AppleLanguages") }
    }
}

enum L10n {
    static var locale: Locale { Locale(identifier: AppLanguage.effective.rawValue) }
    static let catalogs: [AppLanguage: [String: String]] = {
        var result: [AppLanguage: [String: String]] = [:]
        for language in AppLanguage.supported {
            let name = ResourceLocator.bundle.localizations.first { $0.caseInsensitiveCompare(language.rawValue) == .orderedSame } ?? language.rawValue
            let file = ResourceLocator.bundle.resourceURL?.appendingPathComponent(name + ".lproj/Localizable.strings")
            if let file, let data = try? Data(contentsOf: file), let entries = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] {
                result[language] = entries
            }
        }
        return result
    }()
    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        let resolved = language == .system ? AppLanguage.effective : (language ?? AppLanguage.effective)
        return catalogs[resolved]?[key] ?? catalogs[.english]?[key] ?? key
    }
    /// Numbered slots let translations reorder values; values are inserted only once.
    static func format(_ key: String, _ arguments: String..., language: AppLanguage? = nil) -> String {
        render(text(key, language: language), arguments: arguments)
    }
    static func render(_ template: String, arguments: [String]) -> String {
        let regex = try! NSRegularExpression(pattern: #"\{(\d+)\}"#)
        let string = template as NSString
        var result = template
        for match in regex.matches(in: template, range: NSRange(location: 0, length: string.length)).reversed() {
            guard let index = Int(string.substring(with: match.range(at: 1))), arguments.indices.contains(index), let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: arguments[index])
        }
        return result
    }
    /// Cached errors remain canonical, so they are translated at presentation time.
    static func message(_ source: String, language: AppLanguage? = nil) -> String {
        if catalogs[.simplifiedChinese]?[source] != nil { return text(source, language: language) }
        for (key, prefix) in [("额度服务暂不可用（{0}）", "额度服务暂不可用（"), ("Codex 额度服务暂不可用（{0}）", "Codex 额度服务暂不可用（")] {
            if source.hasPrefix(prefix), source.hasSuffix("）") {
                return format(key, String(source.dropFirst(prefix.count).dropLast()), language: language)
            }
        }
        return source
    }
    /// Translate only recognized window labels, leaving provider/model names intact.
    static func quotaLabel(_ source: String, language: AppLanguage? = nil) -> String {
        source.components(separatedBy: " · ").map { component in
            if component.hasSuffix(" 小时"), let hours = Int(component.dropLast(3)) {
                return hours == 1 ? text("1 小时", language: language) : format("{0} 小时", String(hours), language: language)
            }
            return message(component, language: language)
        }.joined(separator: " · ")
    }
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = locale; formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
