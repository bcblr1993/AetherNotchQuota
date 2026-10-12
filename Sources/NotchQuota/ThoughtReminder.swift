import AppKit
import QuartzCore

struct ReminderCycle {
    var lastID: String?
    mutating func next(in ids: [String]) -> String? {
        guard !ids.isEmpty else { return nil }
        let index = lastID.flatMap { ids.firstIndex(of: $0) }.map { ($0 + 1) % ids.count } ?? 0
        lastID = ids[index]; return lastID
    }
}

struct QuotaRecoveryDetector {
    static func restoredWindows(previous: Snapshot?, current: Snapshot) -> [String] {
        guard let previous else { return [] }
        let old = Dictionary(uniqueKeysWithValues: previous.windows.map { ($0.id, $0) })
        return current.windows.compactMap { window in
            guard window.label == "5 小时" || window.label == "每周" ||
                    window.label.hasSuffix(" · 5 小时") || window.label.hasSuffix(" · 每周"),
                  let before = old[window.id], before.label == window.label,
                  let former = before.remaining, former >= 0, former < 100,
                  let now = window.remaining, now >= 100 else { return nil }
            return window.label
        }
    }
}

enum RecoveryStyle: CaseIterable {
    case cloud, bounce, edge
}

struct RecoveryAnnouncement {
    let windows: [String]
    let style: RecoveryStyle
    var title: String {
        if windows.count > 1 {
            let hasFive = windows.contains { $0 == "5 小时" || $0.hasSuffix(" · 5 小时") }
            let hasWeek = windows.contains { $0 == "每周" || $0.hasSuffix(" · 每周") }
            return hasFive && hasWeek ? L10n.text("5 小时与每周额度") : L10n.text("多项额度")
        }
        return windows.first.map { L10n.quotaLabel($0) } ?? L10n.text("额度")
    }
}

enum ReminderFreshness {
    static func accepts(_ state: DisplayState, since started: Date) -> Bool {
        guard !state.loading, state.error == nil, !state.stale,
              let snapshot = state.snapshot, snapshot.fetchedAt >= started,
              snapshot.remaining != nil else { return false }
        return true
    }
}

struct ThoughtLayout {
    static let size = NSSize(width: 268, height: 166)
    static func frame(anchor: NSRect, screen: NSRect) -> NSRect {
        let above = anchor.maxY + size.height <= screen.maxY - 8
        let x = min(screen.maxX - size.width - 8, max(screen.minX + 8, anchor.midX - size.width / 2))
        let y = above ? anchor.maxY : anchor.minY - size.height
        return NSRect(x: x, y: min(screen.maxY - size.height - 8, max(screen.minY + 8, y)), width: size.width, height: size.height)
    }
}

/// A small themed note. All artwork is static; only entry/exit uses bounded layer animations.
final class ThoughtView: NSView {
    private let card = CALayer()
    private var dots: [CALayer] = []
    private var tracking: NSTrackingArea?
    var companion: SidebarAppearance = .ghost
    var acceptsInput = true
    var enter: (() -> Void)?, leave: (() -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true
        layer?.addSublayer(card)
        for diameter: CGFloat in [4, 7, 10] {
            let dot = CALayer(); dot.bounds.size = NSSize(width: diameter, height: diameter)
            dot.cornerRadius = diameter / 2
            layer?.addSublayer(dot); dots.append(dot)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { if acceptsInput { enter?() } }
    override func mouseExited(with event: NSEvent) { if acceptsInput { leave?() } }
    func configure(account: OverviewAccount, anchor: NSRect, windowFrame: NSRect, animated: Bool) {
        configureCard(account: account, announcement: nil, anchor: anchor, windowFrame: windowFrame, animated: animated)
    }
    func configureRecovery(account: OverviewAccount, announcement: RecoveryAnnouncement,
                           anchor: NSRect, windowFrame: NSRect, animated: Bool) {
        configureCard(account: account, announcement: announcement, anchor: anchor, windowFrame: windowFrame, animated: animated)
    }
    private func configureCard(account: OverviewAccount, announcement: RecoveryAnnouncement?,
                               anchor: NSRect, windowFrame: NSRect, animated: Bool) {
        stopMotion()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        card.sublayers?.forEach { $0.removeFromSuperlayer() }
        let above = windowFrame.midY > anchor.midY
        card.frame = NSRect(x: 8, y: above ? 26 : 8, width: 252, height: 132)
        let accent = companion.accent
        let ink = NSColor(srgbRed: 0.20, green: 0.20, blue: 0.27, alpha: 1)
        let paper = NSColor(srgbRed: 1, green: 0.985, blue: 0.96, alpha: 1)
        let fill = CAGradientLayer(); fill.frame = card.bounds
        fill.colors = [paper.cgColor, accent.blended(withFraction: 0.89, of: paper)!.cgColor]
        fill.startPoint = CGPoint(x: 0, y: 1); fill.endPoint = CGPoint(x: 1, y: 0)
        fill.cornerRadius = announcement?.style == .bounce ? 30 : 24; fill.cornerCurve = .continuous
        fill.borderColor = accent.withAlphaComponent(0.23).cgColor; fill.borderWidth = 0.75
        // Explicit shadow path avoids dynamic offscreen shape analysis.
        fill.shadowPath = CGPath(roundedRect: fill.bounds, cornerWidth: fill.cornerRadius, cornerHeight: fill.cornerRadius, transform: nil)
        fill.shadowColor = accent.blended(withFraction: 0.5, of: ink)!.cgColor
        fill.shadowOpacity = 0.16; fill.shadowRadius = 5; fill.shadowOffset = CGSize(width: 0, height: -2)
        card.addSublayer(fill)
        addMotif(accent)
        let mascot = SidebarMascotArtwork.make(style: companion)
        mascot.position = CGPoint(x: 221, y: 107); mascot.setAffineTransform(CGAffineTransform(scaleX: 0.90, y: 0.90))
        card.addSublayer(mascot)
        let iconPlate = CALayer(); iconPlate.frame = CGRect(x: 15, y: 91, width: 30, height: 30)
        iconPlate.backgroundColor = accent.withAlphaComponent(0.10).cgColor; iconPlate.cornerRadius = 10
        card.addSublayer(iconPlate)
        let icon = CALayer(); icon.frame = CGRect(x: 19, y: 95, width: 22, height: 22)
        icon.contents = account.image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        icon.contentsGravity = .resizeAspect; card.addSublayer(icon)
        let quota = account.state.snapshot?.windows.filter { $0.remaining != nil }.min { $0.remaining! < $1.remaining! }
        let stale = account.state.stale || account.state.error != nil
        let percent = announcement == nil ? (quota?.remaining.map { "\(Int($0.rounded()))%" } ?? "—") : "100%"
        let subtitle = announcement == nil ? account.subtitle : L10n.text("已恢复至 100%")
        label(account.title, CGRect(x: 53, y: subtitle.isEmpty ? 98 : 103, width: 141, height: 18), size: 12, color: ink, weight: .semibold)
        if !subtitle.isEmpty {
            label(subtitle, CGRect(x: 53, y: 88, width: 143, height: 14), size: 9, color: ink.withAlphaComponent(0.64))
        }
        let tint = announcement != nil ? NSColor(srgbRed: 0.18, green: 0.50, blue: 0.32, alpha: 1) :
            QuotaTint.color(stale ? nil : quota?.remaining).blended(withFraction: 0.40, of: ink)!
        label(percent, CGRect(x: 16, y: 38, width: 111, height: 46), size: 35, color: tint, weight: .semibold, rounded: true)
        label(announcement == nil ? L10n.text("剩余") : L10n.text("额度"), CGRect(x: 132, y: 65, width: 103, height: 16), size: 11, color: ink, weight: .medium)
        let group = announcement?.title ?? quota.map { L10n.quotaLabel($0.label) } ?? L10n.text("暂时无法读取额度")
        label(group, CGRect(x: 132, y: 38, width: 103, height: 27), size: 10, color: ink.withAlphaComponent(0.7), wrapped: true)
        let footer = CALayer(); footer.frame = CGRect(x: 12, y: 10, width: 228, height: 24)
        footer.cornerRadius = 10; footer.backgroundColor = accent.withAlphaComponent(0.10).cgColor; card.addSublayer(footer)
        let symbol = CALayer(); symbol.frame = CGRect(x: 21, y: 16, width: 12, height: 12)
        if let image = NSImage(systemSymbolName: announcement == nil ? "clock" : "checkmark.seal.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(paletteColors: [accent.blended(withFraction: 0.25, of: ink)!])
            symbol.contents = image.withSymbolConfiguration(config)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        symbol.contentsGravity = .resizeAspect; card.addSublayer(symbol)
        let reset = announcement == nil ? (quota.map { QuotaSummary.resetText($0.reset) } ?? L10n.text("暂时无法读取额度")) : L10n.text("新一轮额度已开始")
        label(stale && announcement == nil ? L10n.text("上次数据") + " · " + reset : reset,
              CGRect(x: 39, y: 15, width: 192, height: 15), size: 10, color: ink.withAlphaComponent(0.74))
        let tip = min(bounds.width - 12, max(12, anchor.midX - windowFrame.minX))
        for (index, dot) in dots.enumerated() {
            let step = CGFloat(index)
            dot.backgroundColor = accent.blended(withFraction: 0.78, of: paper)!.cgColor
            dot.position = CGPoint(x: tip + (bounds.midX - tip) * step * 0.17,
                                   y: above ? 3 + step * 8 : bounds.height - 3 - step * 8)
        }
        CATransaction.commit()
        setAccessibilityElement(true)
        setAccessibilityLabel(announcement.map { L10n.format("{0} {1}已恢复至 100%", account.title, $0.title) } ??
            L10n.format("{0} {1} 剩余 {2}，{3}", account.title, subtitle, percent, group + " · " + reset))
        if animated { animateEntry(above: above, celebratory: announcement?.style == .bounce) }
    }
    private func label(_ value: String, _ frame: CGRect, size: CGFloat, color: NSColor,
                       weight: NSFont.Weight = .regular, rounded: Bool = false, wrapped: Bool = false) {
        let text = CATextLayer(); text.frame = frame; text.string = value
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        text.font = rounded ? NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: size) : font
        text.fontSize = size; text.foregroundColor = color.cgColor
        text.contentsScale = window?.backingScaleFactor ?? 2
        text.truncationMode = .end; text.isWrapped = wrapped; card.addSublayer(text)
    }
    private func addMotif(_ accent: NSColor) {
        let scene = CALayer(); scene.frame = card.bounds
        let color = accent.withAlphaComponent(0.12)
        func shape(_ path: CGPath) {
            let mark = CAShapeLayer(); mark.path = path; mark.fillColor = color.cgColor; scene.addSublayer(mark)
        }
        switch companion {
        case .panda, .bunny:
            // Bamboo leaves / long rabbit-ear petals.
            for (x, y) in [(CGFloat(190), CGFloat(77)), (234, 72)] {
                let leaf = CGMutablePath(); leaf.move(to: CGPoint(x: x, y: y))
                leaf.addQuadCurve(to: CGPoint(x: x + 8, y: y + 17), control: CGPoint(x: x - 5, y: y + 15))
                leaf.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + 15, y: y + 6)); leaf.closeSubpath(); shape(leaf)
            }
        case .turtle, .bear:
            for x: CGFloat in [188, 230] {
                let hex = CGMutablePath()
                for i in 0..<6 {
                    let a = CGFloat(i) * .pi / 3
                    let point = CGPoint(x: x + cos(a) * 10, y: 77 + sin(a) * 10)
                    if i == 0 { hex.move(to: point) } else { hex.addLine(to: point) }
                }
                hex.closeSubpath(); shape(hex)
            }
        case .cat:
            shape(CGPath(ellipseIn: CGRect(x: 218, y: 70, width: 15, height: 11), transform: nil))
            for x: CGFloat in [217, 225, 233] { shape(CGPath(ellipseIn: CGRect(x: x, y: 82, width: 5, height: 6), transform: nil)) }
        case .fox:
            let leaf = CGMutablePath()
            leaf.addLines(between: [CGPoint(x: 220, y: 68), CGPoint(x: 210, y: 78), CGPoint(x: 216, y: 79),
                                   CGPoint(x: 213, y: 86), CGPoint(x: 221, y: 82), CGPoint(x: 225, y: 94),
                                   CGPoint(x: 230, y: 83), CGPoint(x: 238, y: 88), CGPoint(x: 235, y: 79),
                                   CGPoint(x: 242, y: 78), CGPoint(x: 230, y: 70)])
            leaf.closeSubpath(); shape(leaf)
        case .cloud:
            for x: CGFloat in [186, 194, 202] { shape(CGPath(ellipseIn: CGRect(x: x, y: x == 194 ? 74 : 70, width: 16, height: 13), transform: nil)) }
        case .penguin:
            let snow = CGMutablePath()
            for i in 0..<3 {
                let a = CGFloat(i) * .pi / 3
                snow.move(to: CGPoint(x: 232 - cos(a) * 10, y: 76 - sin(a) * 10))
                snow.addLine(to: CGPoint(x: 232 + cos(a) * 10, y: 76 + sin(a) * 10))
            }
            let line = CAShapeLayer(); line.path = snow; line.strokeColor = color.cgColor; line.lineWidth = 3; line.lineCap = .round; scene.addSublayer(line)
        default:
            SidebarMascotArtwork.star(at: CGPoint(x: 191, y: 76), radius: 7, color: color, in: scene)
            SidebarMascotArtwork.star(at: CGPoint(x: 238, y: 79), radius: 5, color: color, in: scene)
        }
        card.addSublayer(scene)
    }
    private func animateEntry(above: Bool, celebratory: Bool) {
        let floating = companion == .ghost || companion == .cloud
        let gentle = companion == .turtle
        let duration: Double
        switch companion {
        case .panda: duration = 0.38
        case .bunny: duration = 0.36
        case .fox: duration = 0.34
        case .turtle: duration = 0.44
        case .cloud: duration = 0.50
        case .bear: duration = 0.40
        case .cat: duration = 0.32
        case .penguin: duration = 0.42
        default: duration = 0.46
        }
        for (index, dot) in dots.enumerated() {
            let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0; fade.toValue = 1
            fade.duration = 0.15; fade.beginTime = CACurrentMediaTime() + Double(index) * 0.045
            fade.fillMode = .backwards; dot.add(fade, forKey: "appear")
        }
        let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0; fade.toValue = 1
        let rise = CAKeyframeAnimation(keyPath: "transform.translation.y")
        let distance: Double = companion == .bunny || celebratory ? 12 : (gentle ? 4 : 8)
        let direction: Double = above ? -1 : 1
        rise.values = [distance * direction, floating || gentle ? 0 : -2 * direction, 0]; rise.keyTimes = [0, 0.72, 1]
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [floating || gentle ? 0.97 : 0.91, floating || gentle ? 1 : 1.015, 1]; pop.keyTimes = rise.keyTimes
        var animations: [CAAnimation] = [fade, rise, pop]
        if [.fox, .cat, .penguin].contains(companion) {
            let sway = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            sway.values = [companion == .penguin ? -0.025 : 0.018, -0.006, 0]; sway.keyTimes = rise.keyTimes
            animations.append(sway)
        }
        let group = CAAnimationGroup(); group.animations = animations; group.duration = duration
        group.beginTime = CACurrentMediaTime() + 0.08; group.fillMode = .backwards
        group.timingFunction = CAMediaTimingFunction(name: .easeOut); card.add(group, forKey: "entry")
    }
    func animateExit() {
        stopMotion()
        let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 1; fade.toValue = 0
        let scale = CABasicAnimation(keyPath: "transform.scale"); scale.fromValue = 1; scale.toValue = 0.97
        let group = CAAnimationGroup(); group.animations = [fade, scale]; group.duration = 0.18
        group.fillMode = .forwards; group.isRemovedOnCompletion = false
        layer?.add(group, forKey: "exit")
    }
    func stopMotion() {
        layer?.removeAllAnimations(); card.removeAllAnimations(); dots.forEach { $0.removeAllAnimations() }
    }
    var hasMotion: Bool {
        layer?.animationKeys()?.isEmpty == false || card.animationKeys()?.isEmpty == false || dots.contains { $0.animationKeys()?.isEmpty == false }
    }
}

@MainActor final class ThoughtReminder {
    let panel: NSPanel
    let view = ThoughtView(frame: NSRect(origin: .zero, size: ThoughtLayout.size))
    private(set) var timer: Timer?
    private var dismissal: DispatchWorkItem?
    private var generation = 0
    private var animatedPresentation = false
    private var cycle = ReminderCycle()
    var tick: (() -> Void)?
    init() {
        panel = NSPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = view; panel.title = L10n.text("额度思考泡泡")
        view.enter = { [weak self] in
            guard let self else { return }
            self.generation += 1; self.dismissal?.cancel(); self.dismissal = nil
            self.view.layer?.removeAnimation(forKey: "exit")
        }
        view.leave = { [weak self] in self?.dismiss(after: 0.3) }
    }
    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 600, target: self, selector: #selector(timerFired(_:)),
                          userInfo: nil, repeats: true)
        timer.tolerance = 15; self.timer = timer; RunLoop.main.add(timer, forMode: .default)
    }
    @objc private func timerFired(_ timer: Timer) { tick?() }
    func stop() { timer?.invalidate(); timer = nil; hide() }
    func showNext(accounts: [OverviewAccount], anchor: NSRect, screen: NSRect, animated: Bool) {
        guard let id = cycle.next(in: accounts.map(\.id)), let account = accounts.first(where: { $0.id == id }) else { return }
        hide()
        animatedPresentation = animated
        let frame = ThoughtLayout.frame(anchor: anchor, screen: screen)
        panel.setFrame(frame, display: false)
        view.configure(account: account, anchor: anchor, windowFrame: frame, animated: animated)
        panel.alphaValue = 1; panel.orderFrontRegardless(); dismiss(after: 5)
    }
    func showRecovery(account: OverviewAccount, windows: [String], style: RecoveryStyle,
                      anchor: NSRect, screen: NSRect, animated: Bool) {
        hide()
        animatedPresentation = animated
        let frame = ThoughtLayout.frame(anchor: anchor, screen: screen)
        panel.setFrame(frame, display: false)
        view.configureRecovery(account: account,
                               announcement: RecoveryAnnouncement(windows: windows, style: style),
                               anchor: anchor, windowFrame: frame, animated: animated)
        panel.alphaValue = 1; panel.orderFrontRegardless(); dismiss(after: 4)
    }
    func hide() {
        generation += 1; dismissal?.cancel(); dismissal = nil
        panel.orderOut(nil); panel.alphaValue = 1; view.stopMotion()
    }
    private func dismiss(after delay: Double) {
        dismissal?.cancel()
        let token = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, token == self.generation else { return }
            guard self.animatedPresentation, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                  !ProcessInfo.processInfo.isLowPowerModeEnabled else { self.hide(); return }
            self.view.animateExit()
            let finish = DispatchWorkItem { [weak self] in
                guard let self, token == self.generation else { return }; self.hide()
            }
            self.dismissal = finish
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: finish)
        }
        dismissal = work; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
