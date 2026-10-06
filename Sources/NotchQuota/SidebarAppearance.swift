import AppKit
import QuartzCore

/// Stable persisted values; unknown values from future versions fall back safely.
enum SidebarAppearance: String, CaseIterable {
    case capsule, orb, gauge, ghost, bunny, bear, cloud, cat, fox, panda, penguin, turtle
    static let preferenceKey = "sidebarAppearance"
    /// Legacy styles remain decodable, but are no longer offered in the menu.
    static let selectable: [Self] = [.panda, .bunny, .fox, .turtle, .ghost, .cloud, .bear, .cat, .penguin]
    static func restored(_ value: String?) -> Self {
        guard let style = value.flatMap(Self.init(rawValue:)), selectable.contains(style) else { return .ghost }
        return style
    }
    var isCharacter: Bool { Self.selectable.contains(self) }
    var scale: CGFloat { isCharacter ? 2.25 : 1.5 }
    var title: String {
        switch self {
        case .capsule: return L10n.text("原生胶囊")
        case .orb: return L10n.text("磨砂圆球")
        case .gauge: return L10n.text("迷你仪表")
        case .ghost: return L10n.text("小幽灵")
        case .bunny: return L10n.text("奶油小兔")
        case .bear: return L10n.text("蜂蜜小熊")
        case .cloud: return L10n.text("云朵团子")
        case .cat: return L10n.text("橘子小猫")
        case .fox: return L10n.text("枫糖小狐")
        case .panda: return L10n.text("糯米熊猫")
        case .penguin: return L10n.text("冰蓝企鹅")
        case .turtle: return L10n.text("抹茶小龟")
        }
    }
}

/// Only the selected design is allocated. Gradients are static layers, not live blur or shaders.
final class SidebarEmblem: CALayer {
    private let indicator = CAShapeLayer(), valueLabel = CATextLayer(), eyes = CALayer()
    private var leaningBody: CALayer?
    private var returnCleanup: DispatchWorkItem?
    private(set) var appearance: SidebarAppearance = .ghost
    override init() { super.init(); bounds = CGRect(x: 0, y: 0, width: 36, height: 36) }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ style: SidebarAppearance) {
        stopMotion()
        leaningBody = nil
        sublayers?.forEach { $0.removeFromSuperlayer() }
        eyes.sublayers?.forEach { $0.removeFromSuperlayer() }
        appearance = style
        indicator.path = nil; indicator.fillColor = nil; indicator.strokeColor = nil
        indicator.lineWidth = 2; indicator.lineCap = .round; indicator.strokeEnd = 1
        indicator.frame = bounds
        valueLabel.frame = CGRect(x: 1, y: 5, width: 34, height: 10)
        valueLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .semibold)
        valueLabel.fontSize = 8; valueLabel.alignmentMode = .center
        valueLabel.foregroundColor = NSColor.white.cgColor
        let dark = [NSColor(white: 0.23, alpha: 1), NSColor(red: 0.06, green: 0.075, blue: 0.10, alpha: 1)]
        switch style {
        case .capsule:
            body(CGPath(roundedRect: CGRect(x: 7, y: 1, width: 22, height: 34), cornerWidth: 11, cornerHeight: 11, transform: nil), colors: dark)
            indicator.path = CGPath(roundedRect: CGRect(x: 16.5, y: 19, width: 3, height: 11), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
            valueLabel.frame.origin.y = 7
            addSublayer(valueLabel)
        case .orb:
            body(CGPath(ellipseIn: CGRect(x: 2, y: 2, width: 32, height: 32), transform: nil), colors: [NSColor(red: 0.91, green: 0.94, blue: 1, alpha: 0.98), NSColor(red: 0.58, green: 0.65, blue: 0.81, alpha: 0.95), NSColor(red: 0.79, green: 0.83, blue: 0.94, alpha: 0.98)])
            let shine = CAGradientLayer(); shine.frame = CGRect(x: 8, y: 21, width: 15, height: 9)
            shine.colors = [NSColor(white: 1, alpha: 0.7).cgColor, NSColor(white: 1, alpha: 0).cgColor]
            shine.cornerRadius = 4.5; addSublayer(shine)
            indicator.path = CGPath(ellipseIn: CGRect(x: 15, y: 14, width: 6, height: 6), transform: nil)
        case .gauge:
            body(CGPath(ellipseIn: CGRect(x: 1, y: 1, width: 34, height: 34), transform: nil), colors: dark)
            let arc = CGMutablePath()
            arc.addArc(center: CGPoint(x: 18, y: 19), radius: 12, startAngle: -.pi * 0.22, endAngle: .pi * 1.22, clockwise: false)
            let track = CAShapeLayer(); track.path = arc; track.fillColor = nil
            track.strokeColor = NSColor(white: 1, alpha: 0.13).cgColor; track.lineWidth = 2; track.lineCap = .round
            addSublayer(track); indicator.path = arc
            let spark = CGMutablePath()
            spark.move(to: CGPoint(x: 18, y: 26)); spark.addLine(to: CGPoint(x: 20, y: 22))
            spark.addLine(to: CGPoint(x: 24, y: 20)); spark.addLine(to: CGPoint(x: 20, y: 18))
            spark.addLine(to: CGPoint(x: 18, y: 14)); spark.addLine(to: CGPoint(x: 16, y: 18))
            spark.addLine(to: CGPoint(x: 12, y: 20)); spark.addLine(to: CGPoint(x: 16, y: 22)); spark.closeSubpath()
            let mark = CAShapeLayer(); mark.path = spark; mark.fillColor = NSColor(white: 0.96, alpha: 1).cgColor
            addSublayer(mark); addSublayer(valueLabel)
        case .ghost, .bunny, .bear, .cloud, .cat, .fox, .panda, .penguin, .turtle:
            let character = SidebarMascotArtwork.make(style: style, eyes: eyes)
            character.bounds = bounds
            character.anchorPoint = CGPoint(x: 27.0 / 36, y: 13.0 / 36)
            character.position = CGPoint(x: 27, y: 13)
            leaningBody = character
            addSublayer(character)
        }
        if !style.isCharacter { addSublayer(indicator) }
    }
    private func body(_ path: CGPath, colors: [NSColor]) {
        let gradient = CAGradientLayer(); gradient.frame = bounds
        gradient.colors = colors.map(\.cgColor); gradient.startPoint = CGPoint(x: 0.2, y: 1); gradient.endPoint = CGPoint(x: 0.8, y: 0)
        let mask = CAShapeLayer(); mask.path = path; gradient.mask = mask; addSublayer(gradient)
        let rim = CAShapeLayer(); rim.path = path; rim.fillColor = nil
        rim.strokeColor = NSColor(white: 1, alpha: 0.25).cgColor; rim.lineWidth = 0.6; addSublayer(rim)
    }
    func update(remaining: Double?, scale: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let color = QuotaTint.color(remaining).cgColor
        indicator.fillColor = appearance == .gauge ? nil : color
        indicator.strokeColor = appearance == .gauge ? color : nil
        indicator.strokeEnd = appearance == .gauge ? CGFloat(min(100, max(0, remaining ?? 0))) / 100 : 1
        valueLabel.contentsScale = scale * appearance.scale
        valueLabel.string = remaining.map { "\(Int($0.rounded()))%" } ?? "—"
        CATransaction.commit()
    }
    func stopMotion() {
        returnCleanup?.cancel(); returnCleanup = nil
        removeAllAnimations(); eyes.removeAllAnimations(); leaningBody?.removeAllAnimations()
    }
    var hasMotion: Bool { animationKeys()?.isEmpty == false || eyes.animationKeys()?.isEmpty == false || leaningBody?.animationKeys()?.isEmpty == false }
    var hasReturnMotion: Bool { animation(forKey: "returnHop") != nil && eyes.animation(forKey: "returnBlink") != nil }
    func playReturn() {
        guard appearance.isCharacter else { return }
        returnCleanup?.cancel()
        // Anticipation, lift, soft landing, then stillness. Each pet has its own gesture.
        let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
        let floating = appearance == .ghost || appearance == .cloud
        let hopping = appearance == .bunny
        hop.values = floating ? [0, -0.4, 2.0, 0.7, 0] : [0, -0.7, hopping ? 3.0 : 1.2, -0.4, 0]
        if appearance == .turtle { hop.values = [0, -0.1, -0.4, -0.15, 0] }
        hop.keyTimes = [0, 0.18, 0.46, 0.74, 1]
        hop.duration = 0.44; hop.calculationMode = .cubic
        add(hop, forKey: "returnHop")
        if let character = leaningBody {
            let gesture = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle: Double = appearance == .penguin ? 0.13 : ([SidebarAppearance.cat, .fox].contains(appearance) ? 0.09 : 0.035)
            gesture.values = [0, -angle * 0.4, angle, -angle * 0.25, 0]
            gesture.keyTimes = [0, 0.18, 0.46, 0.74, 1]; gesture.duration = 0.44
            gesture.isAdditive = true; gesture.calculationMode = .cubic
            character.add(gesture, forKey: "returnGesture")
            let squash = CAKeyframeAnimation(keyPath: "transform.scale.y")
            squash.values = appearance == .turtle ? [1, 1, 0.97, 0.99, 1] : [1, 0.94, 1.035, 0.97, 1]; squash.keyTimes = gesture.keyTimes
            squash.duration = 0.44; character.add(squash, forKey: "returnSquash")
        }
        let blink = CAKeyframeAnimation(keyPath: "transform.scale.y")
        blink.values = [1, 0.14, 1]
        blink.keyTimes = [0, 0.42, 1]
        blink.beginTime = eyes.convertTime(CACurrentMediaTime(), from: nil) + 0.14
        blink.duration = 0.23
        eyes.add(blink, forKey: "returnBlink")
        // AppKit may defer retiring animations while a clipped panel changes size.
        // One bounded cleanup prevents old motion from surviving that transition.
        let cleanup = DispatchWorkItem { [weak self] in
            self?.removeAnimation(forKey: "returnHop")
            self?.eyes.removeAnimation(forKey: "returnBlink")
            self?.leaningBody?.removeAllAnimations()
            self?.returnCleanup = nil
        }
        returnCleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: cleanup)
    }
    func idle(_ enabled: Bool) {
        guard enabled else { removeAnimation(forKey: "idleFloat"); eyes.removeAllAnimations(); return }
        guard animation(forKey: "idleFloat") == nil else { return }
        let float = CAKeyframeAnimation(keyPath: "transform.translation.y")
        float.values = [0, 0, appearance.isCharacter ? 1.8 : 0.8, 0, 0]
        float.keyTimes = [0, 0.70, 0.84, 0.96, 1]; float.duration = 10
        float.repeatCount = .infinity; float.calculationMode = .cubic; add(float, forKey: "idleFloat")
        if appearance.isCharacter {
            let blink = CAKeyframeAnimation(keyPath: "transform.scale.y")
            blink.values = [1, 1, 0.12, 1, 1]; blink.keyTimes = [0, 0.8, 0.82, 0.85, 1]
            blink.duration = 7; blink.repeatCount = .infinity; eyes.add(blink, forKey: "blink")
        }
    }
    func face(right: Bool, docked: Bool, peeking: Bool) {
        // Only edge-docked characters lean; a free-floating character stands upright.
        leaningBody?.transform = docked ? CATransform3DMakeRotation(6 * .pi / 180, 0, 0, 1) : CATransform3DIdentity
        // Mirror only the character, never quota text.
        sublayerTransform = CATransform3DMakeScale((appearance.isCharacter && !right ? -1 : 1) * appearance.scale, appearance.scale, 1)
    }
}
