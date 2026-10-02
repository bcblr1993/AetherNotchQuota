import AppKit
import QuartzCore

/// Stable persisted values; unknown values from future versions fall back safely.
enum SidebarAppearance: String, CaseIterable {
    case capsule, orb, gauge, ghost, bunny, bear, cloud, cat, fox, panda, penguin
    static let preferenceKey = "sidebarAppearance"
    /// Legacy styles remain decodable, but are no longer offered in the menu.
    static let selectable: [Self] = [.ghost, .bunny, .bear, .cloud, .cat, .fox, .panda, .penguin]
    static func restored(_ value: String?) -> Self {
        guard let style = value.flatMap(Self.init(rawValue:)), selectable.contains(style) else { return .ghost }
        return style
    }
    var isCharacter: Bool { Self.selectable.contains(self) }
    var scale: CGFloat { isCharacter ? 2.25 : 1.5 }
    var title: String {
        switch self {
        case .capsule: return "原生胶囊"
        case .orb: return "磨砂圆球"
        case .gauge: return "迷你仪表"
        case .ghost: return "小幽灵"
        case .bunny: return "奶油小兔"
        case .bear: return "蜂蜜小熊"
        case .cloud: return "云朵团子"
        case .cat: return "橘子小猫"
        case .fox: return "枫糖小狐"
        case .panda: return "糯米熊猫"
        case .penguin: return "冰蓝企鹅"
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
        case .ghost:
            let p = CGMutablePath(); p.move(to: CGPoint(x: 4.2, y: 13))
            p.addCurve(to: CGPoint(x: 8.4, y: 29), control1: CGPoint(x: 2.3, y: 19), control2: CGPoint(x: 3.5, y: 27))
            p.addCurve(to: CGPoint(x: 25.5, y: 31), control1: CGPoint(x: 12.2, y: 35), control2: CGPoint(x: 21.4, y: 35))
            p.addCurve(to: CGPoint(x: 32.2, y: 13), control1: CGPoint(x: 31.1, y: 28), control2: CGPoint(x: 33.3, y: 20))
            p.addCurve(to: CGPoint(x: 31, y: 5.8), control1: CGPoint(x: 31.8, y: 9), control2: CGPoint(x: 33.4, y: 7.4))
            p.addCurve(to: CGPoint(x: 23.3, y: 5), control1: CGPoint(x: 29.2, y: 2.1), control2: CGPoint(x: 25.3, y: 2.5))
            p.addCurve(to: CGPoint(x: 17.2, y: 5.6), control1: CGPoint(x: 21.8, y: 2.5), control2: CGPoint(x: 19.5, y: 2.8))
            p.addCurve(to: CGPoint(x: 10, y: 5), control1: CGPoint(x: 15.2, y: 2.7), control2: CGPoint(x: 12, y: 2.8))
            p.addCurve(to: CGPoint(x: 4.2, y: 13), control1: CGPoint(x: 5.4, y: 2.6), control2: CGPoint(x: 3.9, y: 7.5))
            p.closeSubpath()
            body(p, colors: [
                NSColor(srgbRed: 1, green: 0.988, blue: 0.965, alpha: 1),
                NSColor(srgbRed: 0.925, green: 0.914, blue: 0.941, alpha: 1),
                NSColor(srgbRed: 0.843, green: 0.839, blue: 0.882, alpha: 1)
            ])
            for cheekX: CGFloat in [8.2, 25] {
                let cheek = CAShapeLayer()
                cheek.path = CGPath(ellipseIn: CGRect(x: cheekX, y: 15.9, width: 4.6, height: 2), transform: nil)
                cheek.fillColor = NSColor(srgbRed: 0.91, green: 0.66, blue: 0.73, alpha: 0.52).cgColor
                addSublayer(cheek)
            }
            let smilePath = CGMutablePath(); smilePath.move(to: CGPoint(x: 16.1, y: 17.2))
            smilePath.addQuadCurve(to: CGPoint(x: 19.6, y: 17.1), control: CGPoint(x: 17.8, y: 14.8))
            let smile = CAShapeLayer(); smile.path = smilePath; smile.fillColor = nil
            smile.strokeColor = NSColor(srgbRed: 0.36, green: 0.31, blue: 0.38, alpha: 1).cgColor
            smile.lineWidth = 0.8; smile.lineCap = .round; addSublayer(smile)
            eyes.frame = bounds
            let eyeColor = NSColor(srgbRed: 0.16, green: 0.17, blue: 0.21, alpha: 1).cgColor
            for frame in [CGRect(x: 10.5, y: 19.8, width: 3.6, height: 5.5),
                          CGRect(x: 21, y: 20.6, width: 3.6, height: 5.5)] {
                let eye = CAShapeLayer(); eye.path = CGPath(ellipseIn: frame, transform: nil)
                eye.fillColor = eyeColor; eyes.addSublayer(eye)
            }
            addSublayer(eyes)
            // Lean the body and face out into the desktop from the screen edge.
            let leaningBody = CALayer()
            leaningBody.bounds = bounds
            leaningBody.anchorPoint = CGPoint(x: 27.0 / 36, y: 13.0 / 36)
            leaningBody.position = CGPoint(x: 27, y: 13)
            let bodyLayers = sublayers ?? []
            for child in bodyLayers { child.removeFromSuperlayer(); leaningBody.addSublayer(child) }
            self.leaningBody = leaningBody
            addSublayer(leaningBody)
        case .bunny, .bear, .cloud, .cat, .fox, .panda, .penguin:
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
        removeAllAnimations(); eyes.removeAllAnimations()
    }
    var hasMotion: Bool { animationKeys()?.isEmpty == false || eyes.animationKeys()?.isEmpty == false }
    var hasReturnMotion: Bool { animation(forKey: "returnHop") != nil && eyes.animation(forKey: "returnBlink") != nil }
    func playReturn() {
        guard appearance.isCharacter else { return }
        returnCleanup?.cancel()
        let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
        hop.values = [0, -2.2, 0.8, 0]
        hop.keyTimes = [0, 0.28, 0.68, 1]
        hop.beginTime = convertTime(CACurrentMediaTime(), from: nil)
        hop.duration = 0.38; hop.calculationMode = .cubic
        add(hop, forKey: "returnHop")
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
        leaningBody?.transform = docked ? CATransform3DMakeRotation(14 * .pi / 180, 0, 0, 1) : CATransform3DIdentity
        // Mirror only the character, never quota text.
        sublayerTransform = CATransform3DMakeScale((appearance.isCharacter && !right ? -1 : 1) * appearance.scale, appearance.scale, 1)
    }
}
