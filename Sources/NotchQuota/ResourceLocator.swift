import Foundation

enum ResourceLocator {
    static var bundle: Bundle {
        if let embedded = Bundle.main.resourceURL?.appendingPathComponent("NotchQuota_NotchQuota.bundle"), let bundle = Bundle(url: embedded) { return bundle }
        return Bundle.module
    }
    static func icon(_ name: String) -> URL? { bundle.url(forResource: name, withExtension: "png") }
}
