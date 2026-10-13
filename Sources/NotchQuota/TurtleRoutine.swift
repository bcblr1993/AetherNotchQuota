import AppKit

/// Geometry is based on the display's visible frame, including negative origins.
/// Automatic travel never writes the user's saved placement.
enum TurtleRoute {
    static func clamp(_ origin: CGPoint, size: CGSize, screen: CGRect) -> CGPoint {
        CGPoint(x: min(max(screen.minX + 8, origin.x), max(screen.minX + 8, screen.maxX - size.width - 8)),
                y: min(max(screen.minY + 8, origin.y), max(screen.minY + 8, screen.maxY - size.height - 8)))
    }
    static func destination(home: CGPoint, current: CGPoint, size: CGSize, screen: CGRect, direction: Double) -> CGPoint {
        let home = clamp(home, size: size, screen: screen)
        var target = clamp(CGPoint(x: home.x + direction * 96, y: home.y), size: size, screen: screen)
        if abs(target.x - current.x) < 24 {
            target = clamp(CGPoint(x: home.x - direction * 96, y: home.y), size: size, screen: screen)
        }
        return target
    }
}

struct TurtleRoutineBag {
    private var pending: [TurtleScene] = []
    private var previous: TurtleScene?
    mutating func next() -> TurtleScene {
        if pending.isEmpty {
            pending = TurtleScene.allCases.shuffled()
            if pending.first == previous { pending.swapAt(0, 1) }
        }
        let next = pending.removeFirst(); previous = next; return next
    }
}

/// One idle work item; a 30 Hz window-position timer exists only during travel.
/// Sprite animation itself runs in Core Animation. All cancellation is synchronous.
@MainActor final class TurtleRoutine {
    var enabled = true
    var canPlay: () -> Bool = { false }
    var canAutoPlay: () -> Bool = { false }
    var screen: () -> CGRect = { .zero }
    var playPose: (TurtleScene, Double?) -> Bool = { _, _ in false }
    var rest: () -> Void = {}
    var face: (Bool) -> Void = { _ in }
    private weak var panel: NSPanel?
    private(set) var home: CGPoint?
    private(set) var activity: TurtleScene?
    private var pending: DispatchWorkItem?
    private var completion: DispatchWorkItem?
    private var movement: Timer?
    private var bag = TurtleRoutineBag()
    private var returnFromRiver: CGPoint?
    private var direction = -1.0
    var hasPending: Bool { pending != nil }
    var isMoving: Bool { movement != nil }
    var quietDelay: () -> Double = { Double.random(in: 10...18) }

    init(panel: NSPanel) { self.panel = panel }
    func placed() { cancel(); home = panel?.frame.origin; face(false) }
    func schedule(after delay: Double? = nil) {
        guard pending == nil, activity == nil, enabled, canAutoPlay() else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pending = nil
            guard self.enabled, self.canAutoPlay() else { self.schedule(); return }
            self.perform(self.bag.next())
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (delay ?? quietDelay()), execute: work)
    }
    func cancel() {
        pending?.cancel(); pending = nil
        completion?.cancel(); completion = nil
        movement?.invalidate(); movement = nil
        returnFromRiver = nil
        activity = nil; rest()
    }
    func toggle() { enabled.toggle(); cancel(); schedule() }
    func interact() { perform(bag.next()) }
    func perform(_ scene: TurtleScene) {
        guard canPlay(), let panel else { return }
        cancel(); activity = scene
        if home == nil { home = panel.frame.origin }
        if scene == .swim {
            returnFromRiver = panel.frame.origin
            let bank = TurtleRoute.destination(home: home!, current: panel.frame.origin,
                                               size: panel.frame.size, screen: screen(), direction: 1)
            travel(to: bank, then: .swim)
        } else if scene == .walk || scene == .home {
            let target = scene == .home
                ? TurtleRoute.clamp(home!, size: panel.frame.size, screen: screen())
                : TurtleRoute.destination(home: home!, current: panel.frame.origin, size: panel.frame.size, screen: screen(), direction: direction)
            direction *= -1
            travel(to: target, then: scene == .home ? .home : nil)
        } else { playStationary(scene) }
    }
    private func playStationary(_ scene: TurtleScene) {
        if scene == .swim { face(false) }
        guard canPlay(), playPose(scene, nil) else { cancel(); schedule(); return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.completion = nil
            if scene == .swim, let origin = self.returnFromRiver, let panel = self.panel {
                self.returnFromRiver = nil
                self.travel(to: TurtleRoute.clamp(origin, size: panel.frame.size, screen: self.screen()), then: nil)
            } else { self.finish() }
        }
        completion = work
        DispatchQueue.main.asyncAfter(deadline: .now() + scene.duration + 0.22, execute: work)
    }
    private func travel(to destination: CGPoint, then scene: TurtleScene?) {
        guard let panel else { cancel(); return }
        let start = panel.frame.origin
        let distance = hypot(destination.x - start.x, destination.y - start.y)
        if distance < 1 {
            if let scene { playStationary(scene) } else { finish() }
            return
        }
        let duration = max(2.4, distance / 16)
        face(destination.x > start.x)
        guard playPose(.walk, duration) else { cancel(); schedule(); return }
        let began = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                guard let panel = self.panel, self.canPlay() else { self.cancel(); return }
                let progress = min(1, (ProcessInfo.processInfo.systemUptime - began) / duration)
                // Gentle acceleration and braking, with no discontinuity in position.
                let t = progress * progress * (3 - 2 * progress)
                panel.setFrameOrigin(CGPoint(x: start.x + (destination.x - start.x) * t,
                                             y: start.y + (destination.y - start.y) * t))
                if progress >= 1 {
                    timer.invalidate(); self.movement = nil
                    if let scene { self.playStationary(scene) } else { self.finish() }
                }
            }
        }
        timer.tolerance = 0.008; movement = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func finish() {
        completion = nil; activity = nil
        schedule()
    }
}
