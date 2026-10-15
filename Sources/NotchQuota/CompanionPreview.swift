import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Explicit QA entry point only. Renders the actual production layers, with demo
/// characters and no credentials, preference writes, or additional network work.
@MainActor enum CompanionPreview {
    static func run() async {
        guard let directory = ProcessInfo.processInfo.environment["NOTCHQUOTA_SMOKE_DIR"] else { exit(1) }
        let closeup = CommandLine.arguments.contains("--puppet-closeup")
        let interactive = CommandLine.arguments.contains("--companion-interactions")
        let showcase = CommandLine.arguments.contains("--companion-showcase")
        let styles: [SidebarAppearance] = closeup ? [.turtle, .fox] : SidebarAppearance.selectable
        let size = CGSize(width: 720, height: closeup ? 420 : 360)
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.level = .floating
        let view = NSView(frame: CGRect(origin: .zero, size: size)); view.wantsLayer = true
        guard let root = view.layer else { exit(1) }
        root.backgroundColor = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.98, alpha: 1).cgColor
        panel.contentView = view; panel.center(); panel.orderFrontRegardless()
        func label(_ text: String, frame: CGRect, size: CGFloat, color: NSColor) -> CATextLayer {
            let label = CATextLayer(); label.string = text; label.font = NSFont.systemFont(ofSize: size, weight: .medium)
            label.fontSize = size; label.foregroundColor = color.cgColor; label.alignmentMode = .center
            label.contentsScale = 2; label.frame = frame; return label
        }
        let ink = NSColor(srgbRed: 0.24, green: 0.22, blue: 0.30, alpha: 1)
        root.addSublayer(label(closeup ? "抹茶小龟与枫糖小狐 · 细腻肢体与道具动作" : (interactive ? "绘本小伙伴 · 互动反馈（摸摸 / 扑跃 / Q弹果冻）" : "绘本小伙伴 · 抹茶小龟、枫糖小狐与小幽灵的一天"), frame: CGRect(x: 0, y: size.height - 42, width: 720, height: 28), size: 20, color: ink))
        root.addSublayer(label(closeup ? "真实关节与形变 · 缩壳伸展、尾巴卷绕与星星糖果冻律动" : (interactive ? "靠近打招呼 · 单击摸摸 · 拖动提起与落地" : "精选三位性格各异的小伙伴 · 原生手绘绘本风格 · 零安装包体积膨胀"), frame: CGRect(x: 0, y: size.height - 64, width: 720, height: 20), size: 12, color: .gray))
        var emblems: [SidebarEmblem] = [], captions: [CATextLayer] = []
        for (index, style) in styles.enumerated() {
            let x = closeup ? CGFloat(index) * 350 + 15 : CGFloat(index) * 234 + 15
            let y: CGFloat = 15
            let w: CGFloat = closeup ? 340 : 222, h: CGFloat = closeup ? 330 : 265
            let card = CALayer(); card.frame = CGRect(x: x, y: y, width: w, height: h)
            card.backgroundColor = NSColor.white.cgColor; card.cornerRadius = 20; root.addSublayer(card)
            card.addSublayer(label(closeup ? (index == 0 ? "抹茶小龟 · 慢嚼嫩叶与缩壳" : "枫糖小狐 · 蓬松大尾巴与扑枫叶") : style.title, frame: CGRect(x: 0, y: h - 32, width: w, height: 22), size: 14, color: ink))
            let emblem = SidebarEmblem(); emblem.configure(style); emblem.face(right: true, docked: false, peeking: false)
            emblem.position = CGPoint(x: w / 2, y: closeup ? 158 : 138)
            emblem.transform = CATransform3DMakeScale(closeup ? 2.5 : 1.7, closeup ? 2.5 : 1.7, 1)
            card.addSublayer(emblem); emblems.append(emblem)
            let caption = label("", frame: CGRect(x: 6, y: 14, width: w - 12, height: 24), size: closeup ? 12 : 11, color: ink)
            card.addSublayer(caption); captions.append(caption)
        }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(closeup ? "panda-articulated.gif" : (interactive ? "companion-interactions.gif" : (showcase ? "companion-showcase.gif" : "companion-daily-life.gif")))
        let activities: [CompanionActivity] = closeup ? [.drink] : (interactive ? [.greet, .pet, .play, .pickup, .land] : (showcase ? [.music, .play] : CompanionActivity.allCases))
        let totalFrames = closeup ? 70 : activities.reduce(0) { $0 + Int($1.duration * 10) }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, totalFrames, nil) else { exit(1) }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for activity in activities {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for (index, emblem) in emblems.enumerated() {
                let current: CompanionActivity = closeup && index == 1 ? .music : activity
                emblem.playActivity(current); captions[index].string = current.title + " · " + current.caption(for: emblem.appearance)
            }
            CATransaction.commit(); CATransaction.flush()
            for frame in 0..<(closeup ? 70 : Int(activity.duration * 10)) {
                try? await Task.sleep(nanoseconds: 100_000_000)
                autoreleasepool {
                    guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                    (root.presentation() ?? root).render(in: context)
                    guard let image = context.makeImage() else { return }
                    CGImageDestinationAddImage(destination, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
                    if (closeup ? [0, 8, 16, 30, 48, 65].contains(frame) : frame == Int(activity.duration * 10 * 0.45)), let png = CGImageDestinationCreateWithURL(URL(fileURLWithPath: directory).appendingPathComponent(closeup ? "panda-joints-\(frame).png" : "daily-" + activity.rawValue + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil) {
                        CGImageDestinationAddImage(png, image, nil); CGImageDestinationFinalize(png)
                    }
                }
            }
        }
        let success = CGImageDestinationFinalize(destination)
        emblems.forEach { $0.stopMotion() }; panel.orderOut(nil)
        print("COMPANION PREVIEW: \(success ? "PASS" : "FAIL")"); fflush(stdout)
        exit(success ? 0 : 1)
    }
}
