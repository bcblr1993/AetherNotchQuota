import AppKit
import QuartzCore

/// Keep the original pencil texture intact. Gentle, finite gestures have a pause
/// before the response and a quiet settling phase; no articulated replacement body.
final class SoftCompanion: CALayer {
    let artwork: CALayer
    private let heart = CALayer()
    private let glint = CALayer()
    let companionStyle: SidebarAppearance
    override init(layer: Any) {
        let source = layer as! SoftCompanion
        companionStyle = source.companionStyle; artwork = CALayer()
        super.init(layer: layer)
    }
    required init?(coder: NSCoder) { fatalError() }
    init(style: SidebarAppearance) {
        self.companionStyle = style
        artwork = SidebarMascotArtwork.make(style: style)
        super.init()
        bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        // Leave breathing room for watercolor edges, curls and a soft landing.
        artwork.bounds = CGRect(x: 0, y: 0, width: 32, height: 32)
        artwork.anchorPoint = CGPoint(x: 0.5, y: 0.18)
        artwork.position = CGPoint(x: 18, y: 7.76)
        artwork.name = "watercolorArtwork"; addSublayer(artwork)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -1.6))
        path.addCurve(to: CGPoint(x: 0, y: 1), control1: CGPoint(x: -4, y: 1), control2: CGPoint(x: -1.8, y: 3.4))
        path.addCurve(to: CGPoint(x: 0, y: -1.6), control1: CGPoint(x: 1.8, y: 3.4), control2: CGPoint(x: 4, y: 1))
        CompanionDrawing.shape(path, CompanionDrawing.color(0xECA8A5), in: heart)
        heart.position = CGPoint(x: 29, y: 30); heart.opacity = 0; addSublayer(heart)
        SidebarMascotArtwork.star(at: .zero, radius: 1.5, color: CompanionDrawing.color(0xDABF7D), in: glint)
        glint.position = CGPoint(x: 6, y: 29); glint.opacity = 0; addSublayer(glint)
    }
    private var bindings: [(String, CALayer, String)] {
        [("x", artwork, "transform.translation.x"), ("y", artwork, "transform.translation.y"),
         ("tilt", artwork, "transform.rotation.z"), ("sx", artwork, "transform.scale.x"),
         ("sy", artwork, "transform.scale.y"), ("heart", heart, "opacity"),
         ("heartY", heart, "transform.translation.y"), ("glint", glint, "opacity")]
    }
    static func neutral(_ channel: String) -> Double { ["sx", "sy"].contains(channel) ? 1 : 0 }
    func stop() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (channel, layer, path) in bindings {
            layer.removeAllAnimations(); layer.setValue(Self.neutral(channel), forKeyPath: path)
        }
        CATransaction.commit()
    }
    func play(_ activity: CompanionActivity) {
        stop()
        let frames = Int(activity.duration * 30)
        let poses = (0...frames).map { pose(activity, progress: Double($0) / Double(frames)) }
        let now = CACurrentMediaTime()
        for (channel, layer, path) in bindings {
            let values = poses.map { $0[channel] ?? Self.neutral(channel) }
            guard values.contains(where: { abs($0 - Self.neutral(channel)) > 0.0001 }) else { continue }
            let animation = CAKeyframeAnimation(keyPath: path)
            animation.values = values; animation.duration = activity.duration
            animation.calculationMode = .linear; animation.beginTime = layer.convertTime(now, from: nil)
            layer.add(animation, forKey: "soft." + path)
        }
    }
    func renderPose(_ activity: CompanionActivity, progress: Double) {
        stop()
        let pose = pose(activity, progress: progress)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (channel, layer, path) in bindings { layer.setValue(pose[channel] ?? Self.neutral(channel), forKeyPath: path) }
        CATransaction.commit()
    }
    func pose(_ activity: CompanionActivity, progress: Double) -> [String: Double] {
        let t = min(1, max(0, progress))
        // Uneven beats: notice, anticipate, respond, hold, settle. Smoothstep gives
        // zero velocity at the joins, with no spline overshoot or rubber-band jitter.
        let times = [0.0, 0.14, 0.30, 0.48, 0.67, 0.84, 1.0]
        func curve(_ values: [Double]) -> Double {
            let i = min(5, (0..<6).first(where: { t <= times[$0 + 1] }) ?? 5)
            let u = (t - times[i]) / (times[i + 1] - times[i])
            let ease = u * u * (3 - 2 * u)
            return values[i] + (values[i + 1] - values[i]) * ease
        }
        var p: [String: Double] = [:]
        let ghost = companionStyle == .ghost, fox = companionStyle == .fox
        let energy = ghost ? 1.0 : (fox ? 0.75 : 0.45)
        switch activity {
        case .pet:
            // A surprised little dip, leaning into the touch, then one soft sigh.
            p["y"] = curve([0, -0.4, -0.7, 0.5, 0.3, 0.1, 0]) * energy
            p["tilt"] = curve([0, 0, -0.045, -0.065, -0.04, 0.012, 0]) * (fox ? -1 : 1)
            p["sx"] = 1 + curve([0, 0.01, 0.035, -0.012, 0.008, 0, 0]) * energy
            p["sy"] = 1 + curve([0, -0.015, -0.055, 0.025, -0.012, 0, 0]) * energy
            p["heart"] = curve([0, 0, 0, 0.85, 0.7, 0, 0])
            p["heartY"] = curve([0, 0, 0, 0.5, 1.8, 2.6, 0])
        case .play:
            if ghost {
                // Bashful tuck, a curious peek to one side, a tiny proud lift.
                p["sy"] = curve([1, 0.98, 0.90, 0.90, 1.035, 0.99, 1])
                p["sx"] = curve([1, 1.01, 1.06, 1.06, 0.98, 1.005, 1])
                p["y"] = curve([0, -0.3, -0.6, -0.6, 1.5, 0.4, 0])
                p["x"] = curve([0, 0, 0, 0.6, 1.0, 0.3, 0])
                p["tilt"] = curve([0, 0, -0.02, -0.07, 0.035, 0.012, 0])
            } else if fox {
                p["x"] = curve([0, 0, -0.4, 1.0, 1.1, 0.4, 0])
                p["tilt"] = curve([0, 0.02, 0.04, -0.055, -0.055, 0.012, 0])
                p["sy"] = curve([1, 1, 0.975, 1.02, 1.01, 0.995, 1])
            } else {
                p["y"] = curve([0, -0.2, -0.4, 0.5, 0.7, 0.25, 0])
                p["sy"] = curve([1, 0.99, 0.965, 1.025, 1.035, 1.01, 1])
                p["tilt"] = curve([0, 0, 0.025, -0.025, -0.035, -0.01, 0])
            }
            p["glint"] = curve([0, 0, 0, 0, 0.7, 0.25, 0])
        case .greet, .look:
            p["tilt"] = curve([0, 0, -0.045, -0.045, 0.025, 0.01, 0]) * energy
            p["y"] = curve([0, 0.15, 0.8, 0.8, 0.4, 0.15, 0]) * energy
        case .sleep, .yawn, .hungry:
            p["sy"] = 1 + curve([0, -0.01, -0.045, -0.05, -0.05, -0.025, 0]) * energy
            p["sx"] = 1 + curve([0, 0, 0.025, 0.03, 0.03, 0.015, 0]) * energy
            p["tilt"] = curve([0, 0, 0.025, 0.035, 0.035, 0.02, 0])
        case .stretch, .pickup:
            p["sy"] = 1 + curve([0, -0.025, 0.025, 0.055, 0.055, 0.02, 0]) * energy
            p["sx"] = 1 + curve([0, 0.012, -0.012, -0.025, -0.025, -0.01, 0]) * energy
            p["y"] = curve([0, -0.3, 0.8, 1.2, 1.0, 0.4, 0]) * energy
        case .land:
            p["sy"] = curve([1, 0.95, 1.025, 0.99, 1.005, 1, 1])
            p["sx"] = curve([1, 1.025, 0.99, 1.005, 1, 1, 1])
            p["y"] = curve([0, -0.4, 0.3, -0.1, 0, 0, 0])
        case .music, .walk:
            p["tilt"] = curve([0, -0.02, -0.04, 0.035, 0.015, -0.01, 0]) * energy
            p["y"] = curve([0, 0.1, 0.55, 0.15, 0.5, 0.1, 0]) * energy
        case .snack, .drink, .groom, .read:
            p["tilt"] = curve([0, 0, 0.025, 0.01, 0.025, 0.01, 0]) * energy
            p["y"] = curve([0, 0, -0.3, 0.1, -0.2, 0.05, 0]) * energy
        }
        return p
    }
}
