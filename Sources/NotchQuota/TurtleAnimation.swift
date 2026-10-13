import AppKit
import ImageIO

enum TurtleScene: String, CaseIterable {
    case walk, home, read, drink, swim
    var title: String {
        switch self {
        case .walk: return "出去散步"
        case .home: return "回家休息"
        case .read: return "翻书阅读"
        case .drink: return "低头喝水"
        case .swim: return "去河里游泳"
        }
    }
    struct Pose { let frame: Int; let seconds: Double }
    var poses: [Pose] {
        switch self {
        case .walk:
            return (0..<3).flatMap { _ in (0..<16).map { Pose(frame: $0, seconds: 0.15) } }
        case .home:
            return (0..<16).map { Pose(frame: $0, seconds: (8...11).contains($0) ? 1.8 : 0.25) }
        case .read:
            return (0..<16).map { Pose(frame: $0, seconds: [4, 5, 11, 12, 13].contains($0) ? 0.9 : 0.24) }
        case .drink:
            return (0..<16).map { Pose(frame: $0, seconds: (6...9).contains($0) ? 0.7 : 0.23) }
        case .swim:
            let enter = (0..<4).map { Pose(frame: $0, seconds: 0.34) }
            let paddle = [4, 5, 6, 7].map { Pose(frame: $0, seconds: 0.22) }
            return enter + paddle + paddle + paddle + (8..<16).map { Pose(frame: $0, seconds: 0.34) }
        }
    }
    var duration: Double { poses.reduce(0) { $0 + $1.seconds } }
}

/// Full-body authored poses. Only two decoded clips are retained, plus one rest
/// frame. Motion is finite; the layer has no display timer or idle loop.
final class TurtleAnimation: CALayer {
    enum AssetError: Error { case invalid(String) }
    private var clips: [TurtleScene: [CGImage]] = [:]
    private var recent: [TurtleScene] = []
    private var resting: CGImage?
    private var cleanup: DispatchWorkItem?
    private(set) var scene: TurtleScene?
    var cachedClipCount: Int { clips.count }
    var decodedBytes: Int {
        var bytes = resting == nil ? 0 : 256 * 256 * 4
        for frames in clips.values {
            for frame in frames { bytes += frame.bytesPerRow * frame.height }
        }
        return bytes
    }

    override init() {
        super.init()
        contentsGravity = .resizeAspect
        minificationFilter = .trilinear; magnificationFilter = .linear
        actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull(), "transform": NSNull()]
    }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func frames(for scene: TurtleScene) throws -> [CGImage] {
        recent.removeAll { $0 == scene }; recent.append(scene)
        if let found = clips[scene] { return found }
        let name = "turtle-" + scene.rawValue
        guard let url = ResourceLocator.icon(name), let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil), atlas.width == 1024, atlas.height == 1024 else { throw AssetError.invalid(name) }
        var frames: [CGImage] = []
        for i in 0..<16 {
            guard let crop = atlas.cropping(to: CGRect(x: i % 4 * 256, y: i / 4 * 256, width: 256, height: 256)),
                  let context = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 1024,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw AssetError.invalid(name) }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 256, height: 256))
            guard let image = context.makeImage() else { throw AssetError.invalid(name) }
            frames.append(image)
        }
        clips[scene] = frames
        while clips.count > 2, let oldest = recent.first { clips.removeValue(forKey: oldest); recent.removeFirst() }
        return frames
    }

    func rest(animated: Bool = false) throws {
        cleanup?.cancel(); cleanup = nil; removeAllAnimations(); scene = nil
        if resting == nil { resting = try frames(for: .walk)[5] }
        if animated { transition() }
        contents = resting
    }
    private func transition() {
        let fade = CATransition(); fade.type = .fade; fade.duration = 0.18
        add(fade, forKey: "turtle.transition")
    }
    @discardableResult func play(_ scene: TurtleScene, duration: Double? = nil, allowMotion: Bool = true) throws -> Bool {
        try rest()
        guard allowMotion else { return false }
        let frames = try frames(for: scene), poses = scene.poses
        let animation = CAKeyframeAnimation(keyPath: "contents")
        var elapsed = 0.0, times: [NSNumber] = []
        for pose in poses { times.append(NSNumber(value: elapsed / scene.duration)); elapsed += pose.seconds }
        times.append(1)
        animation.values = poses.map { frames[$0.frame] } + [frames[poses.last!.frame]]
        animation.keyTimes = times; animation.calculationMode = .discrete
        animation.duration = duration ?? scene.duration
        contents = frames[0]; transition(); self.scene = scene
        add(animation, forKey: "turtle.scene")
        let work = DispatchWorkItem { [weak self] in try? self?.rest(animated: true) }
        cleanup = work
        DispatchQueue.main.asyncAfter(deadline: .now() + animation.duration, execute: work)
        return true
    }
    func stop() { try? rest() }
}
