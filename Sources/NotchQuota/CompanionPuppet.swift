import AppKit
import QuartzCore

/// Keyframes are compiled once at the start of a finite scene. Core Animation
/// interpolates joints; there is no display-link, frame decoding or idle tick.
final class CompanionPuppet: CALayer {
    private var character: CompanionCharacter!
    private(set) var companionStyle: SidebarAppearance = .panda
    override init() { super.init(); bounds = CGRect(x: 0, y: 0, width: 36, height: 36) }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }
    static func make(_ style: SidebarAppearance) -> CompanionPuppet? {
        guard style.isCharacter else { return nil }
        let puppet = CompanionPuppet(); puppet.companionStyle = style
        puppet.character = CompanionCharacter(style: style)
        puppet.addSublayer(puppet.character.shadow); puppet.addSublayer(puppet.character.root)
        return puppet
    }
    func stop() {
        func clear(_ layer: CALayer) { layer.removeAllAnimations(); layer.sublayers?.forEach(clear) }
        clear(self)
    }
    func play(_ activity: CompanionActivity) {
        stop()
        let c = character!
        let bindings: [(String, CALayer, String)] = [
            ("x", c.root, "transform.translation.x"), ("y", c.root, "transform.translation.y"),
            ("lean", c.root, "transform.rotation.z"), ("squash", c.torso, "transform.scale.y"),
            ("head", c.head, "transform.rotation.z"), ("headY", c.head, "transform.translation.y"),
            ("headX", c.head, "transform.translation.x"), ("headScale", c.head, "transform.scale"),
            ("earL", c.leftEar, "transform.rotation.z"), ("earR", c.rightEar, "transform.rotation.z"),
            ("tail", c.tail, "transform.rotation.z"), ("footL", c.leftFoot, "transform.rotation.z"),
            ("footR", c.rightFoot, "transform.rotation.z"), ("footLY", c.leftFoot, "transform.translation.y"),
            ("footRY", c.rightFoot, "transform.translation.y"), ("armL", c.left, "transform.rotation.z"),
            ("armR", c.right, "transform.rotation.z"), ("elbowL", c.left.forearm, "transform.rotation.z"),
            ("elbowR", c.right.forearm, "transform.rotation.z"), ("wrist", c.right.grip, "transform.rotation.z"),
            ("eyes", c.leftEye, "transform.scale.y"), ("eyes", c.rightEye, "transform.scale.y"),
            ("eyeX", c.leftEye, "transform.translation.x"), ("eyeX", c.rightEye, "transform.translation.x"),
            ("mouth", c.mouth, "transform.scale.y"), ("cup", c.cup, "opacity"), ("food", c.food, "opacity"),
            ("foodScale", c.food, "transform.scale"), ("headset", c.headphones, "opacity"),
            ("headsetY", c.headphones, "transform.translation.y"), ("book", c.book, "opacity"),
            ("page", c.page, "transform.scale.x"), ("toy", c.toy, "opacity"),
            ("toyX", c.toy, "transform.translation.x"), ("toyY", c.toy, "transform.translation.y"),
            ("toySpin", c.toy, "transform.rotation.z"), ("shadow", c.shadow, "transform.scale.x")
        ]
        let frames = Int(activity.duration * 24)
        let poses = (0...frames).map { pose(activity, progress: Double($0) / Double(frames)) }
        let begin = CACurrentMediaTime()
        for (channel, layer, path) in bindings {
            let fallback = Self.unitChannels.contains(channel) ? 1.0 : 0.0
            let values = poses.map { $0[channel] ?? fallback }
            guard values.contains(where: { abs($0 - fallback) > 0.0001 }) else { continue }
            let animation = CAKeyframeAnimation(keyPath: path); animation.values = values
            animation.duration = activity.duration; animation.calculationMode = .linear
            animation.beginTime = layer.convertTime(begin, from: nil)
            layer.add(animation, forKey: "joint." + path)
        }
    }
    private static let unitChannels: Set<String> = ["squash", "headScale", "eyes", "mouth", "foodScale", "page", "shadow"]

    /// Pure scene sampling also lets tests check contact, continuity and recovery.
    func pose(_ activity: CompanionActivity, progress t: Double) -> [String: Double] {
        let c = character!, style = companionStyle
        let personality = CompanionPersonality.profile(style)
        func smooth(_ x: Double) -> Double { let v = min(1, max(0, x)); return v * v * (3 - 2 * v) }
        func rise(_ a: Double, _ b: Double) -> Double { smooth((t - a) / (b - a)) }
        func hold(_ a: Double = 0.08, _ b: Double = 0.25, _ end: Double = 0.78, _ out: Double = 0.98) -> Double { rise(a, b) * (1 - rise(end, out)) }
        func wave(_ cycles: Double, phase: Double = 0) -> Double { sin(t * .pi * 2 * cycles / personality.tempo + phase) }
        let e = hold(), beat = wave(activity.duration / (1.4 * personality.tempo))
        var p: [String: Double] = [:]

        // Idle ear and tail posture per species
        if style == .fox {
            p["earL"] = e * beat * 0.12
            p["earR"] = -e * wave(2.5, phase: 0.5) * 0.10
            p["tail"] = e * wave(2.5) * 0.35 // Natural lush tail sway
        } else if style == .turtle {
            p["tail"] = e * wave(1.5) * 0.08 // Subtle turtle tail wiggle
        } else if style == .ghost {
            p["y"] = e * (1.2 + wave(1.5) * 1.0) // Continuous floating hover
            p["squash"] = 1 + e * wave(1.5) * 0.04 // Jelly breathing
        } else {
            p["earL"] = e * beat * (style == .bunny ? 0.12 : 0.035)
            p["earR"] = -e * wave(3, phase: 0.5) * (style == .bunny ? 0.09 : 0.04)
            p["tail"] = e * wave(3) * 0.1
        }

        // A single blink is a deforming eyelid, never an icon or opaque patch.
        let blink = max(0, 1 - abs(t - 0.12) / 0.025)
        p["eyes"] = 1 - 0.92 * smooth(blink)
        func reach(_ arm: CompanionLimb, _ point: CGPoint, _ amount: Double, left: Bool) {
            let a = arm.reach(point, outer: left)
            p[left ? "armL" : "armR"] = a.0 * amount
            p[left ? "elbowL" : "elbowR"] = a.1 * amount
            if !left { p["wrist"] = -(a.0 + a.1) * amount }
        }
        func hands(_ lp: CGPoint, _ rp: CGPoint, _ amount: Double) { reach(c.left, lp, amount, left: true); reach(c.right, rp, amount, left: false) }

        switch activity {
        case .snack, .drink:
            let lift = hold(0.1, style == .turtle ? 0.38 : 0.30, 0.71, 0.94)
            let nibble = hold(0.32, 0.4, 0.67, 0.74)
            let bites = wave(style == .turtle ? 3 : 5)
            p["head"] = -0.035 * lift + nibble * bites * 0.025
            p["mouth"] = 1 + nibble * (activity == .drink ? 0.8 : 1.4) * max(0, bites)
            p["eyes"] = 1 - nibble * (activity == .drink ? 0.65 : 0.18)
            // Rim lands just below the mouth; sip happens only after the lift.
            reach(c.right, CGPoint(x: 23.5, y: 17.0), lift, left: false)
            if [.panda, .bear, .turtle, .penguin].contains(style) {
                reach(c.left, CGPoint(x: 15.5, y: 17), lift * 0.85, left: true)
            } else { p["elbowL"] = lift * 0.7; p["armL"] = -lift * 0.12 }
            p["wrist", default: 0] += nibble * (activity == .drink ? -0.22 : bites * 0.07)
            p[activity == .drink ? "cup" : "food"] = hold(0.02, 0.1, 0.93, 0.995)
            if activity == .snack { p["foodScale"] = 1 - 0.18 * rise(0.42, 0.7) * (1 - rise(0.92, 1)) }
            if style == .fox {
                p["earL", default: 0] += nibble * 0.15
                p["tail", default: 0] += nibble * 0.25
            } else if style == .ghost {
                p["lean"] = nibble * wave(2) * 0.1
                p["squash"] = 1 + nibble * 0.06
            }
            p["squash", default: 1] -= nibble * max(0, bites) * 0.025
        case .music:
            let putOn = hold(0.02, 0.24, 0.78, 0.98)
            let release = hold(0.27, 0.35, 0.69, 0.78)
            hands(CGPoint(x: 8.5, y: 23 - 16 * (1 - putOn)), CGPoint(x: 27.5, y: 23 - 16 * (1 - putOn)), hold(0, 0.06, 0.96, 1) * (1 - release))
            p["headset"] = hold(0, 0.06, 0.96, 1); p["headsetY"] = -16 * (1 - putOn) * (1 - rise(0.985, 1))
            p["head"] = beat * release * personality.tilt * 1.8
            p["eyes"] = 1 - release * 0.65
            p["footL"] = max(0, beat) * release * 0.3
            p["footR"] = min(0, beat) * release * 0.25
            p["squash"] = 1 - release * abs(beat) * 0.035
            if style == .fox {
                p["tail"] = beat * release * 0.55 // Fox tail keeps rhythmic tempo
                p["earL"] = beat * release * 0.16
                p["earR"] = -beat * release * 0.14
            }
            if c.floating {
                p["y"] = release * (1.2 + beat * 1.0)
                p["armL", default: 0] -= release * 0.6
                p["armR", default: 0] += release * 0.6
            }
        case .sleep:
            let settle = hold(0.04, 0.3, 0.84, 1)
            p["eyes"] = 1 - settle * 0.94; p["headY"] = -settle * 2
            p["squash"] = 1 - settle * (0.06 + wave(3) * 0.014)
            p["elbowL"] = settle * 1.2; p["elbowR"] = -settle * 1.2
            switch style {
            case .turtle:
                // Signature: Turtle withdraws into its protective matcha shell
                p["headY"] = -settle * 5.6
                p["headScale"] = 1 - settle * 0.22
                p["armL"] = settle * 0.35
                p["armR"] = -settle * 0.35
                p["footL"] = settle * 0.15
                p["footR"] = -settle * 0.15
            case .fox:
                // Signature: Fox wraps its fluffy white-tipped tail around snout
                p["tail"] = settle * 1.35
                p["headY"] = -settle * 2.5
                p["head"] = settle * 0.25
                p["lean"] = settle * 0.07
                p["earL"] = -settle * 0.35
                p["earR"] = settle * 0.35
            case .ghost:
                // Signature: Ghost melts softly like a cozy pudding on the ground
                p["y"] = -settle * 2.8
                p["squash"] = 1 - settle * 0.26
                p["headY"] = -settle * 2.2
                p["lean"] = settle * -0.06
            case .panda: p["head"] = settle * 0.2; p["armL"] = -settle * 0.25
            case .bunny: p["earL"] = -settle * 0.72; p["earR"] = settle * 0.5; p["head"] = -settle * 0.12
            case .cloud: p["y"] = settle * 1.5; p["squash"] = 1 - settle * 0.16; p["headY"] = -settle * 3.5
            case .bear: p["head"] = -settle * 0.19; p["elbowL"] = settle * 1.7; p["elbowR"] = -settle * 1.7
            case .cat: p["tail"] = settle * 1.1; p["lean"] = settle * 0.12; p["head"] = -settle * 0.24
            default: p["headY"] = -settle * 3; p["footL"] = settle * 0.18; p["footR"] = -settle * 0.18
            }
        case .hungry:
            p["head"] = e * personality.tilt * 2 * wave(1)
            hands(CGPoint(x: 15, y: 9), CGPoint(x: 21, y: 10 + beat), e)
            p["eyeX"] = e * wave(1) * 0.7; p["headY"] = -e * 0.5
            p["earL"] = -e * 0.15; p["earR"] = e * 0.15
            if style == .turtle { p["headScale"] = 1 - e * 0.08 }
            if style == .fox { p["tail"] = -e * 0.3 }
        case .stretch:
            let lift = hold(0.16, 0.45, 0.63, 0.94)
            p["squash"] = 1 - hold(0.02, 0.12, 0.15, 0.3) * 0.1 + lift * 0.1
            p["headY"] = lift * 1.8; p["eyes"] = 1 - e * 0.82
            p["armL"] = -lift * 2.5; p["armR"] = lift * 2.5
            p["elbowL"] = -lift * 0.3; p["elbowR"] = lift * 0.3
            if style == .fox {
                // Signature: Fox stretches with arched back, lowered front and high tail
                p["headY"] = -lift * 2.2
                p["head"] = lift * 0.15
                p["tail"] = -lift * 0.95
                p["armL"] = -lift * 1.1; p["armR"] = lift * 1.1
            } else if style == .turtle {
                // Signature: Turtle stretches neck high upward
                p["headY"] = lift * 2.8
                p["headScale"] = 1 + lift * 0.12
                p["armL"] = -lift * 1.2; p["armR"] = lift * 1.2
            } else if style == .ghost {
                // Ghost stretches like a water drop elongating
                p["y"] = lift * 2.2
                p["squash"] = 1 + lift * 0.22
            }
        case .play:
            p["toy"] = e
            switch style {
            case .turtle:
                // Turtle playfully nudges a floating fresh leaf
                p["toyX"] = -4 * e
                p["toyY"] = e * (2 + wave(1) * 1.5)
                p["headY"] = -e * 1.2
                p["head"] = -e * 0.12
                p["armR"] = e * 0.5
            case .fox:
                // Fox pounces and bats at a fluttering red maple leaf
                p["toyX"] = e * (-10 + 7 * wave(1))
                p["toyY"] = e * (15 + 3 * wave(2))
                p["toySpin"] = t * .pi * 3 * e
                p["head"] = -e * wave(1) * 0.22
                p["armR"] = e * (1.1 + beat * 0.5)
                p["tail"] = e * wave(3.2) * 0.55 // Excited rapid tail wagging
            case .ghost:
                // Ghost plays with a glowing golden star candy
                p["toyX"] = e * (-10 + 8 * wave(1))
                p["toyY"] = e * (17 + 3 * wave(2))
                p["toySpin"] = wave(1) * e
                p["y"] = e * (1.2 + wave(2) * 1.2)
                p["squash"] = 1 + e * wave(2) * 0.08
                p["armL"] = -e * 1.2; p["armR"] = e * 1.2
                p["head"] = e * wave(2) * 0.12
            case .panda:
                p["toyX"] = -8 * e; p["toyY"] = e * (11 + beat); p["toySpin"] = e * beat * 0.3
                hands(CGPoint(x: 15, y: 16), CGPoint(x: 24, y: 17), e); p["head"] = e * beat * 0.1
            case .bunny:
                let hop = max(0, sin((t - 0.15) * .pi * 5)) * hold(0.08, 0.2, 0.65, 0.9)
                p["y"] = hop * 3; p["footL"] = -hop * 0.5; p["footR"] = hop * 0.5; p["earL"] = -hop * 0.4; p["earR"] = -hop * 0.3; p["toy"] = 0
            default:
                p["toy"] = 0; p["x"] = e * wave(1) * 2.7; p["lean"] = -e * wave(1) * 0.22; p["armL"] = -e * 0.8; p["armR"] = e * 0.8
            }
        case .groom:
            let scrub = e * wave(style == .fox ? 5 : 4)
            let target = style == .turtle ? CGPoint(x: 21, y: 12) : CGPoint(x: 24, y: 23)
            reach(c.right, CGPoint(x: target.x + scrub * 0.6, y: target.y + scrub * 0.8), e, left: false)
            p["head"] = -e * 0.12; p["eyes"] = 1 - e * 0.75
            if style == .fox {
                p["tail"] = e * 0.6
                p["earR"] = -e * 0.25
            } else if style == .turtle {
                p["headScale"] = 1 + e * 0.04
            } else if c.floating {
                hands(CGPoint(x: 11, y: 22 + scrub), CGPoint(x: 25, y: 22 + scrub), e)
                p["headScale"] = 1 - e * 0.03
            }
        case .read:
            p["book"] = e; hands(CGPoint(x: 12, y: 12), CGPoint(x: 24, y: 12), e)
            p["headY"] = -e; p["head"] = e * wave(2) * personality.tilt; p["eyeX"] = e * wave(3) * 0.6
            p["page"] = 1 - max(0, 1 - abs(t - 0.55) / 0.08) * 1.95
            p["earL"] = e * 0.08; p["earR"] = -e * 0.08
            switch style {
            case .turtle: p["headScale"] = 1 + e * 0.05
            case .fox: p["head"] = e * 0.14; p["tail"] = e * wave(1.5) * 0.25
            case .ghost: p["y"] = e * wave(2) * 0.5
            default: p["footL"] = e * 0.15; p["footR"] = -e * 0.15
            }
        case .walk:
            let step = wave(style == .turtle ? 2 : 4), travel = wave(1)
            p["x"] = e * travel * (style == .turtle ? 1.0 : 2.5)
            p["footL"] = e * step * 0.4; p["footR"] = -e * step * 0.4
            p["footLY"] = e * max(0, step) * 0.7; p["footRY"] = e * max(0, -step) * 0.7
            p["armL"] = -e * step * 0.25; p["armR"] = e * step * 0.25
            p["head"] = e * step * personality.tilt; p["eyeX"] = e * travel * 0.6
            if style == .fox { p["tail"] = -e * step * 0.4 }
            if c.floating { p["y"] = e * (1 + step * 0.6); p["armL"] = -e * 0.5; p["armR"] = e * 0.5 }
        case .look:
            p["head"] = e * wave(1) * personality.tilt * 2; p["eyeX"] = e * wave(1) * 0.85
            p["headY"] = e * 0.6; p["earL"] = -e * 0.1; p["earR"] = e * 0.1
            if style == .turtle { p["headScale"] = 1 + e * 0.06 }
            if style == .fox { p["tail"] = e * 0.3; p["earL"] = e * 0.2 }
        case .yawn:
            p["eyes"] = 1 - e * 0.9; p["mouth"] = 1 + e * 4
            p["head"] = -e * 0.12; p["headY"] = e * 0.7
            reach(c.right, CGPoint(x: 22, y: 18), e, left: false)
            p["earL"] = -e * 0.2; p["earR"] = e * 0.2
            if style == .turtle { p["headScale"] = 1 + e * 0.06 }
        case .pet:
            p["eyes"] = 1 - e * 0.91; p["head"] = e * (0.10 + personality.tilt * beat)
            p["headY"] = e * 0.8; p["headX"] = e * wave(1) * 0.65
            p["elbowL"] = e * 0.75; p["elbowR"] = -e * 0.75
            if style == .fox {
                // Fox: airplane ears and ecstatic tail wag
                p["earL"] = -e * 0.45; p["earR"] = e * 0.45
                p["tail"] = e * beat * 0.7
            } else if style == .turtle {
                p["headScale"] = 1 + e * 0.04
            } else if style == .ghost {
                // Ghost: squishy bouncy jelly response
                p["y"] = e * 1.4
                p["squash"] = 1 - e * 0.08 + sin(t * .pi * 4) * e * 0.06
            }
        case .greet:
            p["armR"] = e * 2.4; p["elbowR"] = e * (0.3 + beat * 0.4)
            p["head"] = -e * 0.12; p["eyes"] = 1 - e * 0.45
            let hop = max(0, sin((t - 0.18) * .pi * 2)) * e
            p["y"] = hop * (style == .turtle ? 0.35 : (style == .fox ? 1.5 : 0.85))
            p["squash"] = 1 - hold(0.02, 0.08, 0.14, 0.24) * 0.08
            p["footL"] = -hop * 0.2; p["footR"] = hop * 0.2
            if style == .fox { p["tail"] = e * beat * 0.5 }
            if c.floating { p["y"] = e * 1.5 }
        case .pickup:
            p["armL"] = -e * 0.65; p["armR"] = e * 0.65
            p["footL"] = -e * 0.3; p["footR"] = e * 0.3; p["y"] = e
            p["head"] = e * wave(2) * 0.1; p["earL"] = -e * 0.25; p["earR"] = e * 0.25
            if style == .turtle {
                // Turtle paddles feet in midair
                p["footL"] = wave(3) * e * 0.4
                p["footR"] = -wave(3) * e * 0.4
                p["headY"] = -e * 1.5
            } else if style == .fox {
                p["tail"] = e * 0.5
            } else if style == .ghost {
                p["squash"] = 1 + e * 0.18
            } else {
                p["squash"] = 1 + e * 0.06
            }
        case .land:
            let settle = sin(t * .pi * 3) * pow(1 - t, 2)
            p["squash"] = 1 - max(0, settle) * (style == .ghost ? 0.22 : 0.16)
            p["headY"] = -settle * 1.5; p["earL"] = -settle * 0.35; p["earR"] = settle * 0.35
            p["armL"] = -settle * 0.6; p["armR"] = settle * 0.6
            if style == .fox {
                p["tail"] = -settle * 0.5 // Tail flips upward to absorb impact
            } else {
                p["tail"] = settle * 0.25
            }
        }
        p["shadow"] = 1 - max(0, p["y"] ?? 0) * 0.06
        return p
    }
}
