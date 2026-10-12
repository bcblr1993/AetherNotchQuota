import AppKit
import ImageIO

/// C-style prototype: authored full-body poses, decoded once per clip. No frame
/// timer or image decoding is scheduled while the companion is resting.
enum SoftPandaScene: String, CaseIterable {
    case drink, music
    var title: String { self == .drink ? "拿杯喝水" : "戴耳机听音乐" }

    struct Step {
        let frame: Int
        let seconds: Double
    }
    var steps: [Step] {
        switch self {
        case .drink:
            // The authored middle poses are reordered by cup height. Reuse the
            // same poses on the way down to keep identity and contact stable.
            return [(0, 0.45), (1, 0.10), (4, 0.09), (2, 0.09), (3, 0.09),
                    (5, 0.09), (6, 0.10), (7, 0.12), (8, 0.18), (9, 0.55),
                    (8, 0.16), (7, 0.10), (6, 0.09), (5, 0.09), (3, 0.09),
                    (2, 0.09), (4, 0.09), (13, 0.10), (14, 0.12), (0, 0.50)]
                .map { Step(frame: $0.0, seconds: $0.1) }
        case .music:
            let lift = (0...10).map { Step(frame: $0, seconds: $0 == 0 ? 0.4 : 0.10) }
            let sway = [11, 12, 11, 13, 14, 15, 14, 13]
                .map { Step(frame: $0, seconds: 0.16) }
            let lower = (0...10).reversed().map { Step(frame: $0, seconds: $0 == 0 ? 0.5 : 0.10) }
            return lift + sway + sway + lower
        }
    }
    var duration: Double { steps.reduce(0) { $0 + $1.seconds } }
}

final class SoftPandaAnimation: CALayer {
    enum AssetError: Error { case missing(String), invalidAtlas(String) }
    private var clips: [SoftPandaScene: [CGImage]] = [:]
    private(set) var scene: SoftPandaScene?
    private var completion: DispatchWorkItem?
    private(set) var decodedBytes = 0
    var cachedClipCount: Int { clips.count }

    override init() {
        super.init()
        contentsGravity = .resizeAspect
        minificationFilter = .trilinear; magnificationFilter = .linear
        actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
    }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func frames(for scene: SoftPandaScene) throws -> [CGImage] {
        if let frames = clips[scene] { return frames }
        let name = "soft-panda-" + scene.rawValue
        guard let url = ResourceLocator.icon(name) else { throw AssetError.missing(name) }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil),
              atlas.width >= 1024, atlas.width == atlas.height else { throw AssetError.invalidAtlas(name) }
        // Generation can return an odd-sized atlas; round shared boundaries
        // rather than dropping the trailing pixels or overlapping cells.
        let cellW = Double(atlas.width) / 4, cellH = Double(atlas.height) / 4
        var frames: [CGImage] = []
        for index in 0..<16 {
            let x = floor(Double(index % 4) * cellW), y = floor(Double(index / 4) * cellH)
            let rect = CGRect(x: x, y: y,
                              width: floor(Double(index % 4 + 1) * cellW) - x,
                              height: floor(Double(index / 4 + 1) * cellH) - y)
            guard let crop = atlas.cropping(to: rect),
                  let context = CGContext(data: nil, width: 256, height: 256, bitsPerComponent: 8,
                                          bytesPerRow: 1024, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw AssetError.invalidAtlas(name)
            }
            context.interpolationQuality = .high
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 256, height: 256))
            guard let frame = context.makeImage() else { throw AssetError.invalidAtlas(name) }
            frames.append(frame)
        }
        clips[scene] = frames
        decodedBytes += frames.reduce(0) { $0 + $1.bytesPerRow * $1.height }
        return frames
    }

    func rest(_ scene: SoftPandaScene = .drink) throws {
        stop()
        contents = try frames(for: scene)[0]
    }

    @discardableResult func play(_ scene: SoftPandaScene, allowMotion: Bool = true) throws -> Bool {
        try rest(scene)
        guard allowMotion else { return false }
        let frames = try frames(for: scene), steps = scene.steps
        let animation = CAKeyframeAnimation(keyPath: "contents")
        var elapsed = 0.0, times: [NSNumber] = []
        for step in steps {
            times.append(NSNumber(value: elapsed / scene.duration)); elapsed += step.seconds
        }
        times.append(1)
        animation.values = steps.map { frames[$0.frame] } + [frames[0]]
        animation.keyTimes = times; animation.calculationMode = .discrete
        animation.duration = scene.duration
        self.scene = scene
        add(animation, forKey: "softPanda.scene")
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        completion = work
        DispatchQueue.main.asyncAfter(deadline: .now() + scene.duration, execute: work)
        return true
    }

    func stop() {
        completion?.cancel(); completion = nil
        removeAllAnimations(); scene = nil
    }

    func releaseClips() {
        stop(); contents = nil; clips.removeAll(); decodedBytes = 0
    }
}
