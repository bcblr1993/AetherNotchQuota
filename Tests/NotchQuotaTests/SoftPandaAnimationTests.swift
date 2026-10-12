import XCTest
import AppKit
@testable import NotchQuota

final class SoftPandaAnimationTests: XCTestCase {
    func testAtlasDecodingPreservesAlphaAndHasBoundedReusableStorage() throws {
        let panda = SoftPandaAnimation()
        for scene in SoftPandaScene.allCases {
            let frames = try panda.frames(for: scene)
            XCTAssertEqual(frames.count, 16)
            XCTAssertEqual(frames[0].width, 256)
            XCTAssertEqual(frames[0].height, 256)
            XCTAssertTrue(frames[0] === (try panda.frames(for: scene))[0])
            var distinct = Set<Data>()
            for frame in frames {
                let bytes = try XCTUnwrap(frame.dataProvider?.data) as Data
                var borderIsClear = true
                for n in 0..<256 {
                    let top = n * 4 + 3, left = n * 1024 + 3
                    if bytes[top] != 0 || bytes[261120 + top] != 0 || bytes[left] != 0 || bytes[left + 1020] != 0 {
                        borderIsClear = false
                    }
                }
                XCTAssertTrue(borderIsClear, "Packed poses need transparent padding, with no neighbouring-frame fragments")
                distinct.insert(bytes)
            }
            XCTAssertEqual(distinct.count, 16, "Each authored pose must be present")
        }
        XCTAssertEqual(panda.cachedClipCount, 2)
        XCTAssertEqual(panda.decodedBytes, 8 * 1024 * 1024)
        panda.releaseClips()
        XCTAssertEqual(panda.decodedBytes, 0)
        XCTAssertEqual(panda.cachedClipCount, 0)
        XCTAssertNil(panda.contents)
    }

    func testFiniteTimelinesReplaceCleanlyAndReducedMotionStaysStill() throws {
        let panda = SoftPandaAnimation()
        for scene in SoftPandaScene.allCases {
            XCTAssertTrue(scene.steps.allSatisfy { (0..<16).contains($0.frame) && $0.seconds > 0 })
            XCTAssertEqual(scene.steps.first?.frame, scene.steps.last?.frame)
            try panda.play(scene)
            let animation = try XCTUnwrap(panda.animation(forKey: "softPanda.scene") as? CAKeyframeAnimation)
            XCTAssertEqual(animation.duration, scene.duration)
            XCTAssertEqual(animation.repeatCount, 0)
            XCTAssertTrue(animation.isRemovedOnCompletion)
            XCTAssertEqual(animation.keyTimes?.first, 0)
            XCTAssertEqual(animation.keyTimes?.last, 1)
            XCTAssertEqual(animation.values?.count, scene.steps.count + 1)
            XCTAssertEqual(animation.calculationMode, .discrete)
            XCTAssertEqual(panda.animationKeys(), ["softPanda.scene"])
        }
        XCTAssertFalse(try panda.play(.drink, allowMotion: false))
        XCTAssertNil(panda.scene)
        XCTAssertTrue(panda.animationKeys()?.isEmpty != false)
        XCTAssertNotNil(panda.contents)
    }

    @MainActor func testNaturalCompletionAndReplacementCleanup() async throws {
        let panda = SoftPandaAnimation()
        try panda.play(.drink)
        try await Task.sleep(nanoseconds: 100_000_000)
        try panda.play(.music)
        try await Task.sleep(nanoseconds: UInt64((SoftPandaScene.drink.duration + 0.1) * 1e9))
        XCTAssertEqual(panda.scene, .music, "Cancelled completion must not stop a replacement")
        let remaining = SoftPandaScene.music.duration - SoftPandaScene.drink.duration
        try await Task.sleep(nanoseconds: UInt64((remaining + 0.2) * 1e9))
        XCTAssertNil(panda.scene)
        XCTAssertTrue(panda.animationKeys()?.isEmpty != false)
    }
}
