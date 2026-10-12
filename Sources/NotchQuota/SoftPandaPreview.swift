import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Isolated, local-only art trial. Entered before account readers, preferences,
/// quota windows or Sparkle are started. Does not replace the installed app.
@MainActor final class SoftPandaPreview {
    private static var retained: SoftPandaPreview?
    let panel: NSPanel
    let surface: PandaSurface
    private var observers: [NSObjectProtocol] = []

    init() throws {
        panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 148, height: 148),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        surface = PandaSurface(frame: CGRect(x: 0, y: 0, width: 148, height: 148))
        panel.contentView = surface; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.level = .floating; panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        surface.panda.frame = CGRect(x: 10, y: 10, width: 128, height: 128)
        try surface.panda.rest()
        panel.title = "熊猫 · C 风格本地样片"
        panel.center()
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.accessibilityDisplayOptionsDidChangeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.surface.panda.stop() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.surface.panda.stop() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didHideNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.surface.panda.stop() }
        })
    }
    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    static func run() async {
        do {
            let preview = try SoftPandaPreview(); retained = preview
            preview.panel.orderFrontRegardless()
            if CommandLine.arguments.contains("--soft-panda-benchmark") {
                try await preview.benchmark()
            } else if CommandLine.arguments.contains("--soft-panda-preview") {
                try await preview.record()
            } else {
                preview.surface.perform(.drink)
            }
        } catch {
            fputs("SOFT PANDA FAIL: \(error)\n", stderr); exit(1)
        }
    }

    private func benchmark() async throws {
        func mark(_ phase: String) { print("SOFT PANDA \(phase) \(Date().timeIntervalSince1970)"); fflush(stdout) }
        mark("ready")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        mark("active")
        for scene in [SoftPandaScene.drink, .music, .drink] {
            try surface.panda.play(scene)
            try await Task.sleep(nanoseconds: UInt64((scene.duration + 0.2) * 1e9))
        }
        guard surface.panda.animationKeys()?.isEmpty != false, surface.panda.scene == nil else { throw PreviewError.animationLeaked }
        mark("idle")
        try await Task.sleep(nanoseconds: 10_000_000_000)
        print("SOFT PANDA decodedBytes \(surface.panda.decodedBytes)")
        surface.panda.releaseClips(); panel.orderOut(nil)
        print("SOFT PANDA BENCH COMPLETE: PASS"); fflush(stdout); exit(0)
    }

    enum PreviewError: Error { case outputRequired, encodeFailed, animationLeaked }
    private func record() async throws {
        guard let directory = ProcessInfo.processInfo.environment["NOTCHQUOTA_SMOKE_DIR"] else { throw PreviewError.outputRequired }
        let output = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let size = CGSize(width: 720, height: 430)
        panel.setContentSize(size); panel.center()
        surface.frame = CGRect(origin: .zero, size: size)
        let root = surface.layer!
        root.backgroundColor = NSColor(srgbRed: 0.965, green: 0.955, blue: 0.935, alpha: 1).cgColor
        surface.panda.frame = CGRect(x: 20, y: 50, width: 300, height: 300)
        let actual = SoftPandaAnimation(); actual.frame = CGRect(x: 458, y: 155, width: 128, height: 128)
        root.addSublayer(actual)
        func label(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, font: CGFloat) -> CATextLayer {
            let l = CATextLayer(); l.string = text; l.fontSize = font
            l.font = NSFont.systemFont(ofSize: font, weight: .medium); l.contentsScale = 2
            l.alignmentMode = .center; l.foregroundColor = NSColor.darkGray.cgColor
            l.frame = CGRect(x: x, y: y, width: width, height: 30); root.addSublayer(l); return l
        }
        _ = label("C · 熊猫本地动画样片", x: 0, y: 385, width: 720, font: 21)
        _ = label("放大检查", x: 20, y: 18, width: 300, font: 14)
        _ = label("桌宠尺寸 · 128 pt", x: 380, y: 115, width: 290, font: 14)
        let caption = label("", x: 360, y: 70, width: 330, font: 14)
        for scene in SoftPandaScene.allCases {
            let count = Int(ceil((scene.duration + 0.4) * 20))
            guard let gif = CGImageDestinationCreateWithURL(output.appendingPathComponent("panda-\(scene.rawValue).gif") as CFURL, UTType.gif.identifier as CFString, count, nil) else { throw PreviewError.encodeFailed }
            CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            caption.string = scene.title
            try surface.panda.play(scene); try actual.play(scene)
            CATransaction.flush()
            let start = ProcessInfo.processInfo.systemUptime
            for index in 0..<count {
                let delay = start + Double(index) / 20 - ProcessInfo.processInfo.systemUptime
                if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1e9)) }
                try autoreleasepool {
                    guard let context = CGContext(data: nil, width: 720, height: 430, bitsPerComponent: 8, bytesPerRow: 0,
                                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PreviewError.encodeFailed }
                    (root.presentation() ?? root).render(in: context)
                    guard let image = context.makeImage() else { throw PreviewError.encodeFailed }
                    CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.05]] as CFDictionary)
                    if index % 10 == 0 {
                        guard let png = CGImageDestinationCreateWithURL(output.appendingPathComponent("\(scene.rawValue)-\(index).png") as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw PreviewError.encodeFailed }
                        CGImageDestinationAddImage(png, image, nil)
                        guard CGImageDestinationFinalize(png) else { throw PreviewError.encodeFailed }
                    }
                }
            }
            guard CGImageDestinationFinalize(gif) else { throw PreviewError.encodeFailed }
            print("SOFT PANDA \(scene.rawValue): \(count) captured frames, \(scene.steps.count) timed poses")
        }
        surface.panda.releaseClips(); actual.releaseClips(); panel.orderOut(nil)
        print("SOFT PANDA PREVIEW: PASS"); fflush(stdout); exit(0)
    }
}

@MainActor final class PandaSurface: NSView {
    let panda = SoftPandaAnimation()
    private var press: NSPoint?, origin: NSPoint?
    private var dragged = false
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true; layer?.addSublayer(panda)
        toolTip = "本地样片：单击喝水，双击听音乐，拖动移动，右键关闭"
        setAccessibilityLabel("熊猫 C 风格动画样片")
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidMoveToWindow() { if window == nil { panda.stop() } }
    override func mouseDown(with event: NSEvent) {
        press = NSEvent.mouseLocation; origin = window?.frame.origin; dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let press, let origin else { return }
        let current = NSEvent.mouseLocation
        if hypot(current.x - press.x, current.y - press.y) > 3 {
            if !dragged { panda.stop() }; dragged = true
        }
        if dragged { window?.setFrameOrigin(NSPoint(x: origin.x + current.x - press.x, y: origin.y + current.y - press.y)) }
    }
    override func mouseUp(with event: NSEvent) {
        if !dragged { perform(event.clickCount > 1 ? .music : .drink) }
        press = nil; origin = nil
    }
    func perform(_ scene: SoftPandaScene) {
        do {
            try panda.play(scene, allowMotion: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && !ProcessInfo.processInfo.isLowPowerModeEnabled)
        } catch { NSLog("Panda preview asset unavailable: %@", String(describing: error)) }
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        for (title, action) in [("喝水", #selector(drink)), ("听音乐", #selector(music)), ("暂停动作", #selector(stop)), ("关闭样片", #selector(closePreview))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func drink() { perform(.drink) }
    @objc private func music() { perform(.music) }
    @objc private func stop() { panda.stop() }
    @objc private func closePreview() { panda.releaseClips(); window?.orderOut(nil); NSApp.terminate(nil) }
}
