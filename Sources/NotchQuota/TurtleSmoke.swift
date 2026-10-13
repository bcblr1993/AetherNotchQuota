import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor extension AppDelegate {
    func runTurtleSmoke(_ bar: SidebarController) async {
        var failures = 0
        func check(_ value: Bool, _ label: String) {
            print("TURTLE \(label): \(value ? "PASS" : "FAIL")"); fflush(stdout)
            if !value { failures += 1 }
        }
        func wait(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1e9)) }
        guard let screen = NSScreen.main else { exit(1) }
        let requests = lastAttempt
        bar.setAppearance(.turtle)
        bar.place(at: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY), screen: screen, keepCollapsed: true)
        bar.exitBar(); await wait(0.6)
        check(bar.isFloatingTurtle && bar.turtleRoutine.hasPending, "floating turtle schedules daily life")
        bar.toggleTurtleDaily()
        check(!bar.turtleRoutine.enabled && !bar.turtleRoutine.hasPending, "automatic activities can be disabled")
        if CommandLine.arguments.contains("--turtle-benchmark") {
            func mark(_ phase: String) { print("TURTLE BENCH \(phase) \(Date().timeIntervalSince1970)"); fflush(stdout) }
            mark("walking"); bar.playTurtle(.walk); await wait(6.5)
            mark("stationary")
            for scene in [TurtleScene.read, .drink] {
                bar.playTurtle(scene); await wait(scene.duration + 0.5)
            }
            mark("swimming"); bar.playTurtle(.swim); await wait(32)
            bar.turtleRoutine.cancel(); mark("idle"); await wait(10)
            check(!bar.turtleRoutine.isMoving && !bar.turtleRoutine.hasPending && !bar.hasEmblemAnimations, "benchmark idle has no motion or daily work")
            bar.hide(); print("TURTLE BENCH COMPLETE: PASS"); fflush(stdout); exit(0)
        }
        let home = bar.panel.frame.origin
        bar.playTurtle(.walk); await wait(0.5)
        check(bar.turtleRoutine.isMoving && bar.panel.frame.origin != home, "walking actually moves the small native window")
        check(bar.turtleRoutine.home == home, "automatic travel preserves drop anchor")
        updateSidebar()
        check(bar.turtleRoutine.isMoving && bar.turtleScene == .walk, "quota cache refresh does not interrupt walking")
        bar.enterBar(); let paused = bar.panel.frame.origin; await wait(0.15)
        check(bar.collapsed && !bar.turtleRoutine.isMoving && bar.panel.frame.origin == paused, "hover pauses travel without expanding")
        bar.exitBar()
        bar.playTurtle(.home); await wait(2.7)
        check(hypot(bar.panel.frame.minX - home.x, bar.panel.frame.minY - home.y) < 1 && bar.turtleScene == .home, "home walks back before retreating into shell")
        bar.turtleRoutine.cancel()
        if CommandLine.arguments.contains("--turtle-record") {
            do {
                for scene in TurtleScene.allCases {
                    if scene == .home {
                        bar.panel.setFrameOrigin(CGPoint(x: home.x - 40, y: home.y))
                    }
                    if scene == .swim { bar.panel.setFrameOrigin(home) }
                    bar.playTurtle(scene)
                    try await recordTurtle(bar, scene: scene, home: home, duration: scene.duration + (scene == .home ? 3 : scene == .swim ? 12.6 : 0.4))
                    if scene == .swim {
                        check(bar.panel.frame.origin == home && !bar.turtleRoutine.isMoving && bar.turtleRoutine.activity == nil,
                              "swimming walks to river then comes back to its starting position")
                    }
                    bar.turtleRoutine.cancel()
                }
                check(true, "five native sidebar animation recordings saved")
            } catch { check(false, "recording: \(error)") }
        }
        for scene in [TurtleScene.read, .drink] {
            bar.playTurtle(scene); await wait(0.35)
            check(bar.turtleScene == scene, "manual \(scene.rawValue) plays with automatic life off")
        }
        bar.playTurtle(.swim); await wait(0.15)
        check(bar.turtleRoutine.activity == .swim && bar.turtleRoutine.isMoving && bar.turtleScene == .walk,
              "swimming begins with an actual walk to the river")
        bar.interactWithTurtle(clickCount: 2); await wait(0.4)
        check(!bar.collapsed && bar.turtleRoutine.activity == nil && !bar.turtleRoutine.isMoving, "double click opens quotas and clears activity")
        bar.exitBar(); bar.setCollapsed(true); await wait(0.6)
        suppressMotion = true; updateSidebar(); bar.playTurtle(.walk)
        check(!bar.turtleRoutine.isMoving && bar.turtleScene == nil && !bar.turtleRoutine.hasPending, "reduced motion stops manual and automatic activity")
        suppressMotion = false; updateSidebar(); bar.toggleTurtleDaily()
        bar.turtleRoutine.cancel(); bar.turtleRoutine.schedule(after: 0.1); await wait(0.3)
        check(bar.turtleRoutine.activity != nil, "idle schedule actually starts an activity")
        bar.hide(); await wait(0.1)
        check(!bar.turtleRoutine.isMoving && !bar.turtleRoutine.hasPending && bar.turtleScene == nil && !bar.hasEmblemAnimations, "hide cancels every activity and movement timer")
        updateSidebar(); bar.setAppearance(.panda); bar.exitBar(); bar.setCollapsed(true); bar.playPanda(.drink)
        check(bar.pandaScene == .drink && bar.turtleRoutine.activity == nil, "panda keeps its released interactions")
        check(lastAttempt == requests, "all activities use cached quotas without requests")
        bar.hide()
        print("TURTLE COMPLETE: \(failures == 0 ? "PASS" : "FAIL")"); fflush(stdout)
        exit(failures == 0 ? 0 : 1)
    }

    private func recordTurtle(_ bar: SidebarController, scene: TurtleScene, home: CGPoint, duration: Double) async throws {
        guard let path = ProcessInfo.processInfo.environment["NOTCHQUOTA_SMOKE_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let count = Int(ceil(duration * 20))
        guard let gif = CGImageDestinationCreateWithURL(directory.appendingPathComponent("turtle-\(scene.rawValue).gif") as CFURL, UTType.gif.identifier as CFString, count, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let began = ProcessInfo.processInfo.systemUptime
        for index in 0..<count {
            let delay = began + Double(index) / 20 - ProcessInfo.processInfo.systemUptime
            if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1e9)) }
            try autoreleasepool {
                guard let context = CGContext(data: nil, width: 640, height: 360, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
                context.setFillColor(NSColor(srgbRed: 0.93, green: 0.95, blue: 0.88, alpha: 1).cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
                context.translateBy(x: 270 + bar.panel.frame.minX - home.x, y: 108 + bar.panel.frame.minY - home.y)
                if let layer = bar.surface.layer { (layer.presentation() ?? layer).render(in: context) }
                guard let image = context.makeImage() else { throw CocoaError(.fileWriteUnknown) }
                CGImageDestinationAddImage(gif, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.05]] as CFDictionary)
                if index == 35 || index == 70 || (scene == .swim && index == 170) {
                    let url = directory.appendingPathComponent("turtle-\(scene.rawValue)-\(index).png")
                    try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
                }
            }
        }
        guard CGImageDestinationFinalize(gif) else { throw CocoaError(.fileWriteUnknown) }
    }
}
