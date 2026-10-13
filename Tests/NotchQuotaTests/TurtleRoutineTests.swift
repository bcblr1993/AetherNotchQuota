import XCTest
import AppKit
@testable import NotchQuota

final class TurtleRoutineTests: XCTestCase {
    func testAllActivitiesAppearWithoutImmediateRepeats() {
        var bag = TurtleRoutineBag(), last: TurtleScene?
        for _ in 0..<50 {
            var cycle = Set<TurtleScene>()
            for _ in TurtleScene.allCases {
                let next = bag.next(); XCTAssertNotEqual(next, last); cycle.insert(next); last = next
            }
            XCTAssertEqual(cycle, Set(TurtleScene.allCases))
        }
    }
    func testTravelStaysOnItsDisplayAndNearHome() {
        let size = CGSize(width: 128, height: 128)
        for screen in [CGRect(x: 0, y: 25, width: 1440, height: 850), CGRect(x: -1920, y: -800, width: 1920, height: 1050)] {
            for x in [screen.minX, screen.midX, screen.maxX - 128] {
                let home = CGPoint(x: x, y: screen.midY)
                for direction in [-1.0, 1.0] {
                    let target = TurtleRoute.destination(home: home, current: home, size: size, screen: screen, direction: direction)
                    XCTAssertTrue(screen.contains(CGRect(origin: target, size: size)))
                    XCTAssertLessThanOrEqual(abs(target.x - home.x), 104)
                }
            }
        }
    }
    func testFiveAtlasesArePaddedDistinctAndCacheIsBounded() throws {
        let turtle = TurtleAnimation()
        try turtle.rest()
        for scene in TurtleScene.allCases {
            let frames = try turtle.frames(for: scene)
            XCTAssertEqual(frames.count, 16)
            var unique = Set<Data>()
            for frame in frames {
                let data = try XCTUnwrap(frame.dataProvider?.data) as Data
                unique.insert(data)
                for n in 0..<256 {
                    XCTAssertEqual(data[n * 4 + 3], 0)
                    XCTAssertEqual(data[255 * 1024 + n * 4 + 3], 0)
                    XCTAssertEqual(data[n * 1024 + 3], 0)
                    XCTAssertEqual(data[n * 1024 + 255 * 4 + 3], 0)
                }
            }
            XCTAssertEqual(unique.count, 16)
            XCTAssertLessThanOrEqual(turtle.cachedClipCount, 2)
            XCTAssertLessThanOrEqual(turtle.decodedBytes, 8 * 1024 * 1024 + 256 * 256 * 4)
            XCTAssertTrue(scene.poses.allSatisfy { (0..<16).contains($0.frame) && $0.seconds > 0 })
            try turtle.play(scene)
            let animation = try XCTUnwrap(turtle.animation(forKey: "turtle.scene") as? CAKeyframeAnimation)
            XCTAssertEqual(animation.repeatCount, 0)
            XCTAssertEqual(animation.duration, scene.duration)
        }
        XCTAssertFalse(try turtle.play(.walk, allowMotion: false))
        XCTAssertNil(turtle.scene)
        XCTAssertTrue(turtle.animationKeys()?.isEmpty != false)
    }
    @MainActor func testMovementCancelsWithoutReplayingAndNeverChangesHome() async throws {
        let panel = NSPanel(contentRect: CGRect(x: 300, y: 300, width: 128, height: 128), styleMask: .borderless, backing: .buffered, defer: false)
        let routine = TurtleRoutine(panel: panel)
        routine.canPlay = { true }; routine.canAutoPlay = { true }
        routine.screen = { CGRect(x: 0, y: 0, width: 1000, height: 800) }
        routine.playPose = { _, _ in true }
        routine.placed(); let home = routine.home
        routine.perform(.walk)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNotEqual(panel.frame.origin, home)
        XCTAssertEqual(routine.home, home)
        routine.cancel(); let stopped = panel.frame.origin
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(panel.frame.origin, stopped)
        XCTAssertFalse(routine.isMoving); XCTAssertFalse(routine.hasPending); XCTAssertNil(routine.activity)
        routine.enabled = false; routine.schedule(after: 0)
        XCTAssertFalse(routine.hasPending)
        routine.perform(.read); XCTAssertEqual(routine.activity, .read)
        routine.cancel()
    }
}
