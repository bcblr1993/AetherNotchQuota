import AppKit
import QuartzCore

/// Stable persisted values; unknown values from future versions fall back safely.
enum SidebarAppearance: String, CaseIterable {
    case capsule, orb, gauge, ghost, bunny, bear, cloud, cat, fox, panda, penguin, turtle
    static let preferenceKey = "sidebarAppearance"
    /// Legacy styles remain decodable, but are no longer offered in the menu.
    static let selectable: [Self] = [.turtle, .fox, .ghost]
    static func restored(_ value: String?) -> Self {
        guard let style = value.flatMap(Self.init(rawValue:)), selectable.contains(style) else { return .ghost }
        return style
    }
    var isCharacter: Bool { !([.capsule, .orb, .gauge].contains(self)) }
    var scale: CGFloat { isCharacter ? 2.25 : 1.5 }
    var accent: NSColor {
        switch self {
        case .turtle: return NSColor(srgbRed: 0.48, green: 0.65, blue: 0.36, alpha: 1)
        case .fox: return NSColor(srgbRed: 0.91, green: 0.54, blue: 0.31, alpha: 1)
        case .ghost: return NSColor(srgbRed: 0.64, green: 0.53, blue: 0.86, alpha: 1)
        default: return NSColor(srgbRed: 0.48, green: 0.65, blue: 0.36, alpha: 1)
        }
    }
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
    private let indicator = CAShapeLayer(), valueLabel = CATextLayer()
    private var leaningBody: CALayer?
    private let confetti = CALayer()
    private var returnCleanup: DispatchWorkItem?
    private var activityProps: CALayer?
    private var activityFace: CALayer?
    private var activityCleanup: DispatchWorkItem?
    private(set) var currentActivity: CompanionActivity?
    private(set) var appearance: SidebarAppearance = .ghost
    private(set) var remainingQuota: Double?
    override init() { super.init(); bounds = CGRect(x: 0, y: 0, width: 36, height: 36) }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ style: SidebarAppearance) {
        stopMotion()
        leaningBody = nil
        sublayers?.forEach { $0.removeFromSuperlayer() }
        confetti.sublayers?.forEach { $0.removeFromSuperlayer() }
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
            let character = SidebarMascotArtwork.make(style: style)
            character.bounds = bounds
            character.anchorPoint = CGPoint(x: 27.0 / 36, y: 13.0 / 36)
            character.position = CGPoint(x: 27, y: 13)
            leaningBody = character
            addSublayer(character)
            confetti.frame = bounds; confetti.opacity = 0
            SidebarMascotArtwork.star(at: CGPoint(x: 3, y: 27), radius: 2.1,
                                     color: NSColor(red: 1, green: 0.83, blue: 0.53, alpha: 1), in: confetti)
            SidebarMascotArtwork.star(at: CGPoint(x: 32, y: 31), radius: 1.5,
                                     color: NSColor(red: 0.72, green: 0.93, blue: 0.90, alpha: 1), in: confetti)
            addSublayer(confetti)
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
        remainingQuota = remaining
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
        activityCleanup?.cancel(); activityCleanup = nil; currentActivity = nil
        activityProps?.removeFromSuperlayer(); activityProps = nil
        activityFace?.removeFromSuperlayer(); activityFace = nil
        (leaningBody as? CompanionPuppet)?.stop()
        removeAllAnimations(); leaningBody?.removeAllAnimations(); confetti.removeAllAnimations()
    }
    var hasMotion: Bool { currentActivity != nil || animationKeys()?.isEmpty == false || leaningBody?.animationKeys()?.isEmpty == false || confetti.animationKeys()?.isEmpty == false }
    var hasReturnMotion: Bool { animation(forKey: "returnHop") != nil && leaningBody?.animation(forKey: "returnGesture") != nil }
    func playReturn() {
        guard appearance.isCharacter else { return }
        stopMotion()
        let twinkle = CAKeyframeAnimation(keyPath: "opacity")
        twinkle.values = [0, 0, 1, 0]; twinkle.keyTimes = [0, 0.25, 0.5, 1]; twinkle.duration = 0.44
        confetti.add(twinkle, forKey: "returnTwinkle")
        // Anticipation, lift, soft landing, then stillness. Distinct gesture per selected character.
        let hop = CAKeyframeAnimation(keyPath: "transform.translation.y")
        if appearance == .turtle {
            hop.values = [0, -0.15, -0.45, -0.15, 0]
        } else if appearance == .fox {
            hop.values = [0, -0.6, 2.2, -0.3, 0]
        } else {
            // ghost
            hop.values = [0, -0.5, 2.4, 0.8, 0]
        }
        hop.keyTimes = [0, 0.18, 0.46, 0.74, 1]
        hop.duration = 0.44; hop.calculationMode = .cubic
        add(hop, forKey: "returnHop")
        if let character = leaningBody {
            let gesture = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let angle: Double = appearance == .fox ? 0.12 : (appearance == .ghost ? 0.06 : 0.02)
            gesture.values = [0, -angle * 0.4, angle, -angle * 0.25, 0]
            gesture.keyTimes = [0, 0.18, 0.46, 0.74, 1]; gesture.duration = 0.44
            gesture.isAdditive = true; gesture.calculationMode = .cubic
            character.add(gesture, forKey: "returnGesture")
            let squash = CAKeyframeAnimation(keyPath: "transform.scale.y")
            squash.values = appearance == .turtle ? [1, 1.01, 0.97, 0.99, 1] : (appearance == .ghost ? [1, 0.91, 1.10, 0.96, 1] : [1, 0.93, 1.05, 0.97, 1])
            squash.keyTimes = gesture.keyTimes
            squash.duration = 0.44; character.add(squash, forKey: "returnSquash")
        }
        // AppKit may defer retiring animations while a clipped panel changes size.
        // One bounded cleanup prevents old motion from surviving that transition.
        let cleanup = DispatchWorkItem { [weak self] in
            self?.removeAnimation(forKey: "returnHop")
            self?.leaningBody?.removeAllAnimations()
            self?.confetti.removeAllAnimations()
            self?.returnCleanup = nil
        }
        returnCleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: cleanup)
    }
    func playActivity(_ activity: CompanionActivity) {
        guard appearance.isCharacter, let character = leaningBody else { return }
        stopMotion(); currentActivity = activity
        if let puppet = character as? CompanionPuppet {
            puppet.play(activity)
        } else {
            playStorybookActivity(activity, for: character)
        }
        let cleanup = DispatchWorkItem { [weak self] in self?.stopMotion() }
        activityCleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + activity.duration, execute: cleanup)
    }
    private func playStorybookActivity(_ activity: CompanionActivity, for character: CALayer) {
        let duration = activity.duration
        func addKF(_ path: String, values: [Double], mode: CAAnimationCalculationMode = .cubic) {
            let anim = CAKeyframeAnimation(keyPath: path)
            anim.values = values
            anim.duration = duration
            anim.calculationMode = mode
            anim.isRemovedOnCompletion = true
            character.add(anim, forKey: "storybook." + path)
        }
        func twinkleConfetti(values: [Double] = [0, 1, 0.8, 1, 0]) {
            let twinkle = CAKeyframeAnimation(keyPath: "opacity")
            twinkle.values = values
            twinkle.duration = duration
            confetti.add(twinkle, forKey: "activityTwinkle")
        }

        switch appearance {
        case .turtle:
            switch activity {
            case .sleep:
                // 抹茶小龟缩壳入睡：身体向下沉降、纵向微缩，像缩进壳里安详小憩，呼吸微浮
                addKF("transform.translation.y", values: [0, -0.6, -2.5, -2.3, -2.5, -0.6, 0])
                addKF("transform.scale.y", values: [1.0, 0.95, 0.88, 0.91, 0.88, 0.97, 1.0])
                addKF("transform.scale.x", values: [1.0, 1.02, 1.05, 1.03, 1.05, 1.01, 1.0])
                addKF("transform.rotation.z", values: [0, 0.02, 0.04, 0.03, 0.04, 0.01, 0])
            case .stretch:
                // 抹茶小龟舒爽探头：慢悠悠拔长脖子伸出硬壳，向斜上方打量舒展
                addKF("transform.translation.y", values: [0, 0.8, 2.6, 2.8, 2.6, 0.9, 0])
                addKF("transform.scale.y", values: [1.0, 1.08, 1.15, 1.15, 1.10, 1.04, 1.0])
                addKF("transform.scale.x", values: [1.0, 0.96, 0.93, 0.93, 0.96, 0.98, 1.0])
                addKF("transform.rotation.z", values: [0, 0.02, -0.04, 0.04, -0.02, 0])
            case .snack, .drink:
                // 抹茶小龟慢条斯理嚼嫩叶/抿水：规律轻柔低头咀嚼三次，微仰头咽下
                addKF("transform.translation.y", values: [0, -0.9, 0.1, -0.9, 0.1, -0.8, 0.5, 0])
                addKF("transform.rotation.z", values: [0, 0.035, -0.015, 0.035, -0.015, 0.03, -0.02, 0])
                addKF("transform.scale.y", values: [1.0, 0.96, 1.02, 0.96, 1.02, 0.97, 1.02, 1.0])
            case .music:
                // 抹茶小龟慢节拍晃头：沉浸在悠闲慢歌里的微幅摆钟晃动
                addKF("transform.rotation.z", values: [0, -0.035, 0.035, -0.035, 0.035, -0.02, 0])
                addKF("transform.translation.y", values: [0, 0.3, -0.3, 0.3, -0.3, 0.2, 0])
            case .play:
                // 抹茶小龟推小石子：稳稳前倾，左右慢移探索
                addKF("transform.translation.x", values: [0, -0.8, 1.0, -0.5, 0.7, 0])
                addKF("transform.translation.y", values: [0, -0.4, 0.6, -0.3, 0.4, 0])
                addKF("transform.rotation.z", values: [0, -0.03, 0.04, -0.02, 0.03, 0])
            case .walk:
                // 抹茶小龟坚定碎步：平稳左右轻点小脚踏步
                addKF("transform.translation.y", values: [0, 0.4, 0, 0.4, 0, 0.4, 0])
                addKF("transform.rotation.z", values: [0, 0.025, -0.025, 0.025, -0.025, 0.015, 0])
            case .look:
                // 抹茶小龟慢转头环顾：左看一眼凝视，右看一眼凝视
                addKF("transform.rotation.z", values: [0, -0.04, -0.04, 0.04, 0.04, 0])
                addKF("transform.translation.x", values: [0, -0.6, -0.6, 0.6, 0.6, 0])
            case .yawn:
                // 抹茶小龟深长哈欠：向上探头大张嘴微仰，再缓缓垂下头
                addKF("transform.translation.y", values: [0, 0.6, 1.4, 1.4, -0.6, 0])
                addKF("transform.scale.y", values: [1.0, 1.05, 1.12, 1.12, 0.95, 1.0])
                addKF("transform.rotation.z", values: [0, -0.03, -0.05, -0.05, 0.02, 0])
            case .greet:
                // 抹茶小龟探头问候：稳稳探出小脑袋微点头两次
                addKF("transform.translation.y", values: [0, 0.8, 1.3, 0.6, 1.1, 0])
                addKF("transform.rotation.z", values: [0, 0.03, -0.03, 0.02, 0])
            case .pet:
                // 抹茶小龟被摸摸：先害羞微缩壳，随即舒服微仰头、微小弹跳，金色柔光小星点
                addKF("transform.translation.y", values: [0, -0.5, 0.9, -0.2, 0.5, 0])
                addKF("transform.scale.y", values: [1.0, 0.95, 1.04, 0.97, 1.02, 1.0])
                addKF("transform.rotation.z", values: [0, -0.04, 0.03, -0.02, 0])
                twinkleConfetti()
            case .pickup:
                // 抹茶小龟被轻轻提起：四脚与头往壳里收拢，悬空微晃
                addKF("transform.scale.y", values: [1.0, 0.93, 0.93, 0.96, 1.0])
                addKF("transform.scale.x", values: [1.0, 0.94, 0.94, 0.97, 1.0])
                addKF("transform.translation.y", values: [0, 1.2, 2.0, 1.8, 0])
                addKF("transform.rotation.z", values: [0, 0.03, -0.03, 0.02, 0])
            case .land:
                // 抹茶小龟稳稳落地：触地沉降缓冲回稳
                addKF("transform.translation.y", values: [0, -1.0, 0.3, -0.1, 0])
                addKF("transform.scale.y", values: [1.0, 0.92, 1.02, 0.98, 1.0])
            default:
                addKF("transform.translation.y", values: [0, -0.5, 0.6, -0.3, 0])
                addKF("transform.rotation.z", values: [0, 0.025, -0.025, 0.015, 0])
                addKF("transform.scale.y", values: [1.0, 0.98, 1.02, 0.99, 1.0])
            }

        case .fox:
            switch activity {
            case .play:
                // 枫糖小狐扑枫叶：机敏下压蓄力、爆发轻快跃起飞扑、兴奋歪头、开心星点
                addKF("transform.translation.y", values: [0, -1.8, 4.2, 1.5, 3.2, 0.6, 0])
                addKF("transform.translation.x", values: [0, -1.6, 2.2, -1.2, 1.4, 0])
                addKF("transform.rotation.z", values: [0, -0.10, 0.18, -0.08, 0.12, 0])
                addKF("transform.scale.y", values: [1.0, 0.90, 1.12, 0.94, 1.06, 0.98, 1.0])
                twinkleConfetti(values: [0, 0.9, 0, 1, 0.5, 0])
            case .sleep:
                // 枫糖小狐蜷缩入睡：侧身伏地，身体蜷缩成温暖球形，尾巴绕过鼻尖
                addKF("transform.translation.y", values: [0, -1.0, -2.4, -2.2, -2.4, -0.7, 0])
                addKF("transform.rotation.z", values: [0, 0.07, 0.15, 0.14, 0.15, 0.04, 0])
                addKF("transform.scale.y", values: [1.0, 0.94, 0.88, 0.90, 0.88, 0.97, 1.0])
            case .stretch:
                // 枫糖小狐猫狐式伸懒腰：前伏后弓深深拉伸，向上反弹抖抖毛
                addKF("transform.translation.y", values: [0, -2.2, -2.8, 1.8, 0.6, 0])
                addKF("transform.rotation.z", values: [0, -0.14, -0.18, 0.10, -0.04, 0])
                addKF("transform.scale.y", values: [1.0, 0.88, 0.85, 1.10, 0.98, 1.0])
            case .snack, .drink:
                // 枫糖小狐尝小浆果/舔泉水：机敏前俯、轻快吧唧小口舔食、耳朵随节拍微颤
                addKF("transform.translation.y", values: [0, -1.0, 0.4, -1.0, 0.4, -0.8, 0.3, 0])
                addKF("transform.rotation.z", values: [0, -0.06, 0.08, -0.06, 0.08, -0.04, 0.03, 0])
                addKF("transform.scale.y", values: [1.0, 0.94, 1.04, 0.94, 1.04, 0.96, 1.02, 1.0])
            case .music:
                // 枫糖小狐抖耳律动：左右侧倾欢快摇摆，小狐狸跟随明快节拍摇头晃脑
                addKF("transform.rotation.z", values: [0, -0.12, 0.12, -0.10, 0.10, -0.06, 0.06, 0])
                addKF("transform.translation.y", values: [0, 0.8, -0.4, 0.8, -0.4, 0.5, 0])
                addKF("transform.scale.y", values: [1.0, 1.04, 0.96, 1.04, 0.96, 1.02, 1.0])
            case .walk:
                // 枫糖小狐轻灵狐步：轻快小跑步伐，上下起伏
                addKF("transform.translation.y", values: [0, 1.4, 0, 1.4, 0, 1.2, 0])
                addKF("transform.rotation.z", values: [0, 0.07, -0.07, 0.07, -0.07, 0.04, 0])
            case .look:
                // 枫糖小狐警觉歪头：猛然歪头、立耳打量、再换方向歪头
                addKF("transform.rotation.z", values: [0, 0.15, 0.15, -0.12, -0.12, 0])
                addKF("transform.translation.y", values: [0, 0.5, 0.5, 0.4, 0.4, 0])
            case .yawn:
                // 枫糖小狐畅快哈欠：昂头大张嘴、伸舌头、抖擞精神
                addKF("transform.translation.y", values: [0, 0.8, 1.8, 1.8, -0.8, 0.4, 0])
                addKF("transform.scale.y", values: [1.0, 1.06, 1.14, 1.14, 0.92, 1.0])
                addKF("transform.rotation.z", values: [0, -0.06, -0.10, -0.10, 0.05, 0])
            case .pet, .greet:
                // 枫糖小狐飞机耳与依赖贴贴：身体下压蹭手心，欢快跃动摇晃，金色星光
                addKF("transform.rotation.z", values: [0, -0.10, 0.18, -0.09, 0.14, -0.05, 0])
                addKF("transform.translation.y", values: [0, -0.6, 2.0, -0.4, 1.4, 0])
                addKF("transform.scale.y", values: [1.0, 0.93, 1.08, 0.95, 1.04, 1.0])
                twinkleConfetti()
            case .pickup:
                // 枫糖小狐悬空提溜：四肢下垂微晃、尾巴轻摆
                addKF("transform.translation.y", values: [0, 1.5, 2.6, 2.3, 0])
                addKF("transform.rotation.z", values: [0, -0.08, 0.08, -0.05, 0.04, 0])
            case .land:
                // 枫糖小狐灵巧着陆：四脚精准落地，弹性垫步缓冲
                addKF("transform.translation.y", values: [0, -1.2, 0.6, -0.2, 0])
                addKF("transform.scale.y", values: [1.0, 0.90, 1.06, 0.97, 1.0])
            default:
                addKF("transform.rotation.z", values: [0, 0.08, -0.06, 0.05, 0])
                addKF("transform.translation.y", values: [0, -0.6, 1.5, -0.4, 0])
                addKF("transform.scale.y", values: [1.0, 0.95, 1.04, 0.98, 1.0])
            }

        case .ghost:
            switch activity {
            case .sleep:
                // 小幽灵融化布丁：彻底软瘫在地面上，像融化的冰淇淋摊开
                addKF("transform.translation.y", values: [0, -1.6, -4.5, -4.3, -4.5, -1.2, 0])
                addKF("transform.scale.y", values: [1.0, 0.82, 0.66, 0.70, 0.66, 0.90, 1.0])
                addKF("transform.scale.x", values: [1.0, 1.15, 1.35, 1.30, 1.35, 1.10, 1.0])
            case .stretch:
                // 小幽灵逆重力水滴拉丝：向上拔高拉长，如轻烟曼妙飘逸
                addKF("transform.translation.y", values: [0, 1.8, 4.5, 4.6, 4.2, 1.4, 0])
                addKF("transform.scale.y", values: [1.0, 1.18, 1.36, 1.36, 1.25, 1.10, 1.0])
                addKF("transform.scale.x", values: [1.0, 0.85, 0.72, 0.72, 0.80, 0.92, 1.0])
                addKF("transform.rotation.z", values: [0, 0.03, -0.04, 0.03, -0.02, 0])
            case .pet:
                // 小幽灵 Q 弹布丁弹性波：极致的 Squash & Stretch 阻尼振荡，Duang~Duang~
                addKF("transform.scale.y", values: [1.0, 0.72, 1.28, 0.86, 1.10, 0.96, 1.0])
                addKF("transform.scale.x", values: [1.0, 1.28, 0.76, 1.12, 0.92, 1.03, 1.0])
                addKF("transform.translation.y", values: [0, -2.0, 3.0, -1.0, 1.2, -0.4, 0])
                twinkleConfetti()
            case .play:
                // 小幽灵抓星星：空中波浪翻腾弹跳、轻灵回旋
                addKF("transform.translation.y", values: [0, 3.5, 1.0, 4.2, 1.5, 3.0, 0])
                addKF("transform.translation.x", values: [0, -1.8, 1.5, -1.2, 1.0, 0])
                addKF("transform.rotation.z", values: [0, 0.16, -0.14, 0.12, -0.08, 0])
                addKF("transform.scale.y", values: [1.0, 1.12, 0.90, 1.16, 0.94, 1.06, 1.0])
                twinkleConfetti(values: [0, 1, 0, 1, 0])
            case .snack, .drink:
                // 小幽灵吞星星糖/甘露：身体中间微泛波光，果冻身子欢快一颤
                addKF("transform.scale.y", values: [1.0, 0.92, 1.14, 0.96, 1.06, 0.98, 1.0])
                addKF("transform.scale.x", values: [1.0, 1.08, 0.90, 1.04, 0.95, 1.02, 1.0])
                addKF("transform.translation.y", values: [0, -0.8, 1.6, -0.3, 0.8, 0])
                twinkleConfetti(values: [0, 0.8, 1, 0.6, 0])
            case .music:
                // 小幽灵水母极光律动：多波长漂浮起伏，梦幻悠游
                addKF("transform.translation.y", values: [0, 2.8, -1.2, 3.2, -0.8, 2.0, 0])
                addKF("transform.scale.y", values: [1.0, 1.12, 0.92, 1.14, 0.94, 1.06, 1.0])
                addKF("transform.scale.x", values: [1.0, 0.90, 1.08, 0.88, 1.06, 0.95, 1.0])
                addKF("transform.rotation.z", values: [0, 0.06, -0.06, 0.05, -0.04, 0])
            case .walk:
                // 小幽灵幽灵飘飘行：脱离地面的波浪式前移
                addKF("transform.translation.y", values: [0, 2.0, 0.5, 2.2, 0.8, 1.8, 0])
                addKF("transform.translation.x", values: [0, -1.0, 0.8, -0.6, 0.8, 0])
                addKF("transform.rotation.z", values: [0, 0.05, -0.05, 0.04, -0.03, 0])
            case .look:
                // 小幽灵漂浮张望：忽左忽右飘移打量
                addKF("transform.translation.x", values: [0, -1.4, -1.4, 1.4, 1.4, 0])
                addKF("transform.translation.y", values: [0, 1.2, 1.2, 1.0, 1.0, 0])
                addKF("transform.rotation.z", values: [0, -0.08, -0.08, 0.08, 0.08, 0])
            case .yawn:
                // 小幽灵烟圈哈欠：气泡般膨胀呼出
                addKF("transform.scale.y", values: [1.0, 1.15, 1.22, 0.88, 0.95, 1.0])
                addKF("transform.scale.x", values: [1.0, 1.15, 1.22, 0.88, 0.95, 1.0])
                addKF("transform.translation.y", values: [0, 1.0, 2.0, -0.8, 0])
            case .greet:
                // 小幽灵探头致意：从下方向上幽幽浮现、欢快晃两下
                addKF("transform.translation.y", values: [0, 2.5, 1.0, 2.2, 0])
                addKF("transform.rotation.z", values: [0, 0.08, -0.08, 0.05, 0])
                twinkleConfetti()
            case .pickup:
                // 小幽灵水滴拔丝：纵向拉长悬浮空中晃荡
                addKF("transform.scale.y", values: [1.0, 1.25, 1.25, 1.10, 1.0])
                addKF("transform.scale.x", values: [1.0, 0.80, 0.80, 0.92, 1.0])
                addKF("transform.translation.y", values: [0, 1.8, 3.2, 2.5, 0])
                addKF("transform.rotation.z", values: [0, 0.05, -0.05, 0.03, 0])
            case .land:
                // 小幽灵触地果冻回弹：Duang 软着陆
                addKF("transform.translation.y", values: [0, -2.2, 1.0, -0.4, 0])
                addKF("transform.scale.y", values: [1.0, 0.74, 1.20, 0.92, 1.0])
                addKF("transform.scale.x", values: [1.0, 1.25, 0.82, 1.08, 1.0])
            default:
                addKF("transform.translation.y", values: [0, 2.0, -1.0, 2.2, -0.5, 1.5, 0])
                addKF("transform.scale.y", values: [1.0, 1.08, 0.94, 1.10, 0.96, 1.04, 1.0])
                addKF("transform.rotation.z", values: [0, 0.05, -0.05, 0.04, -0.03, 0])
            }

        default:
            addKF("transform.translation.y", values: [0, -0.5, 1.2, -0.3, 0])
            addKF("transform.scale.y", values: [1.0, 0.96, 1.03, 0.98, 1.0])
        }
    }
    func face(right: Bool, docked: Bool, peeking: Bool) {
        // Only edge-docked characters lean; a free-floating character stands upright.
        leaningBody?.transform = docked ? CATransform3DMakeRotation(6 * .pi / 180, 0, 0, 1) : CATransform3DIdentity
        // Mirror only the character, never quota text.
        sublayerTransform = CATransform3DMakeScale((appearance.isCharacter && !right ? -1 : 1) * appearance.scale, appearance.scale, 1)
    }
}
