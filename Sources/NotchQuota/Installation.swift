import AppKit
import Foundation

/// Resolve installed applications without assuming a username or /Applications location.
enum Installation {
    struct AntigravityConfiguration {
        let endpoint: String
        let userAgent: String
    }

    static func antigravityConfiguration(appURL: URL? = nil) throws -> AntigravityConfiguration {
        guard let app = appURL ?? app("Antigravity") else { throw QuotaError.message("请先安装并登录 Antigravity") }
        let archive = try Data(contentsOf: app.appendingPathComponent("Contents/Resources/app.asar"), options: .alwaysMapped)
        let info = (try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")))
            .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
        return try AntigravityConfiguration(endpoint: endpoint(from: archive), userAgent: antigravityUserAgent(from: archive, version: info?["CFBundleShortVersionString"] as? String))
    }

    static func antigravityUserAgent(from archive: Data, version: String?) -> String {
        // Match the selected installed client's identity: hub is a distinct backend capability.
        guard let version, version.range(of: #"\A[0-9]+(?:\.[0-9]+){1,3}(?:[-+][A-Za-z0-9.-]+)?\z"#, options: .regularExpression) != nil else { return "antigravity" }
        var subclient = ""
        if let marker = archive.range(of: Data("--subclient_type".utf8)) {
            let snippet = String(decoding: archive[marker.upperBound..<min(archive.count, marker.upperBound + 128)], as: UTF8.self)
            if snippet.range(of: #"\A["']\s*,\s*["']hub["']"#, options: .regularExpression) != nil { subclient = "/hub" }
        }
        return "antigravity\(subclient)/\(version) (os_type=darwin; arch=arm64)"
    }

    static func app(_ name: String) -> URL? {
        let identifiers: [String]
        switch name {
        case "Codex": identifiers = ["com.openai.codex"]
        case "Claude": identifiers = ["com.anthropic.claudefordesktop"]
        case "Antigravity": identifiers = ["com.google.antigravity", "com.google.antigravity.ide"]
        default: identifiers = []
        }
        let names = [name]
        let roots = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        for root in roots { for name in names {
            let url = root.appendingPathComponent(name + ".app")
            if Bundle(url: url) != nil { return url }
        } }
        for id in identifiers { if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id), Bundle(url: url) != nil { return url } }
        return nil
    }
    static func antigravityServer() throws -> URL {
        guard let app = app("Antigravity") else { throw QuotaError.message("请先安装并登录 Antigravity") }
        return app.appendingPathComponent("Contents/Resources/bin/language_server")
    }
    static func antigravityEndpoint() throws -> String {
        guard let app = app("Antigravity") else { throw QuotaError.message("请先安装并登录 Antigravity") }
        let archive = try Data(contentsOf: app.appendingPathComponent("Contents/Resources/app.asar"), options: .alwaysMapped)
        return try endpoint(from: archive)
    }
    static func endpoint(from archive: Data) throws -> String {
        let marker = Data("--cloud_code_endpoint".utf8)
        guard let position = archive.range(of: marker) else { throw QuotaError.message("当前 Antigravity 版本未提供可识别的额度地址") }
        let snippet = String(decoding: archive[position.upperBound..<min(archive.count, position.upperBound + 256)], as: UTF8.self)
        let regex = try NSRegularExpression(pattern: "https://([a-z0-9-]+\\.googleapis\\.com)")
        guard let match = regex.firstMatch(in: snippet, range: NSRange(snippet.startIndex..., in: snippet)), let range = Range(match.range, in: snippet) else { throw QuotaError.message("无法识别 Antigravity 额度服务") }
        let endpoint = String(snippet[range])
        // Do not transmit Google credentials to arbitrary application-provided origins.
        guard ["https://cloudcode-pa.googleapis.com", "https://daily-cloudcode-pa.googleapis.com", "https://daily-cloudcode-pa.sandbox.googleapis.com"].contains(endpoint) else { throw QuotaError.message("Antigravity 额度地址尚未支持") }
        return endpoint + "/v1internal:"
    }
}
