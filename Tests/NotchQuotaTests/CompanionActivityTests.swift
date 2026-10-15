import XCTest
import AppKit
@testable import NotchQuota

final class CompanionActivityTests: XCTestCase {
    func testEveryCharacterHasRealJointsAndHeldObjectsRatherThanChangingIcons() throws {
        func descendants(_ layer: CALayer) -> [CALayer] { [layer] + (layer.sublayers ?? []).flatMap(descendants) }
        for style in SidebarAppearance.selectable {
            let puppet = try XCTUnwrap(CompanionPuppet.make(style))
            let layers = descendants(puppet)
            let cup = try XCTUnwrap(layers.first { $0.name == "cup" })
            let head = try XCTUnwrap(layers.first { $0.name == "head" })
            let headphones = try XCTUnwrap(layers.first { $0.name == "headphones" })
            XCTAssertEqual(cup.superlayer?.name, "grip")
            XCTAssertEqual(cup.superlayer?.superlayer?.name, "elbow")
            XCTAssertTrue(headphones.superlayer === head)
            puppet.play(.drink)
            XCTAssertNotNil(cup.superlayer?.superlayer?.animation(forKey: "joint.transform.rotation.z"))
            XCTAssertNotNil(cup.superlayer?.animation(forKey: "joint.transform.rotation.z"))
            puppet.play(.music)
            XCTAssertNotNil(headphones.animation(forKey: "joint.transform.translation.y"))
            XCTAssertNotNil(head.animation(forKey: "joint.transform.rotation.z"))
            for layer in layers {
                for key in layer.animationKeys() ?? [] {
                    XCTAssertNotEqual((layer.animation(forKey: key) as? CAPropertyAnimation)?.keyPath, "contents")
                }
            }
            puppet.stop()
            XCTAssertTrue(layers.allSatisfy { $0.animationKeys()?.isEmpty != false })
        }
    }
    func testEverySceneRecoversAndEverySpeciesHasDistinctMotion() throws {
        let unit: Set<String> = ["squash", "headScale", "eyes", "mouth", "foodScale", "page", "shadow"]
        for activity in CompanionActivity.allCases {
            var signatures = Set<String>()
            for style in SidebarAppearance.selectable {
                let puppet = try XCTUnwrap(CompanionPuppet.make(style))
                let end = puppet.pose(activity, progress: 1)
                for (channel, value) in end {
                    XCTAssertEqual(value, unit.contains(channel) ? 1 : 0, accuracy: 0.0001, "Recovery: \(style) \(activity) \(channel)")
                }
                let samples = (0...100).map { puppet.pose(activity, progress: Double($0) / 100) }
                for pair in zip(samples, samples.dropFirst()) {
                    for key in ["armL", "armR", "elbowL", "elbowR", "wrist"] {
                        XCTAssertLessThan(abs((pair.0[key] ?? 0) - (pair.1[key] ?? 0)), 1.1, "Joint continuity: \(style) \(activity) \(key)")
                    }
                }
                XCTAssertTrue(samples.flatMap { $0.values }.allSatisfy { $0.isFinite })
                signatures.insert(samples[45].sorted { $0.key < $1.key }.description)
            }
            // Selected roles have a distinct motion signature; reactions may share a contact primitive.
            if CompanionActivity.daily.contains(activity) { XCTAssertGreaterThanOrEqual(signatures.count, min(3, SidebarAppearance.selectable.count), "Species variation: \(activity)") }
        }
    }
    func testBothPawsContactHeadsetBeforeReleaseForAllSpecies() throws {
        for style in SidebarAppearance.selectable {
            let puppet = try XCTUnwrap(CompanionPuppet.make(style))
            let pose = puppet.pose(.music, progress: 0.24)
            for (side, shoulderX, targetX) in [("L", 9.7, 8.5), ("R", 26.3, 27.5)] {
                let shoulder = try XCTUnwrap(pose["arm" + side])
                let elbow = try XCTUnwrap(pose["elbow" + side])
                let handX = shoulderX + 5 * sin(shoulder) + 4.5 * sin(shoulder + elbow)
                let handY = 15 - 5 * cos(shoulder) - 4.5 * cos(shoulder + elbow)
                XCTAssertEqual(handX, targetX, accuracy: 0.05, "Headphone contact: \(style) \(side)")
                XCTAssertEqual(handY, 23, accuracy: 0.05, "Headphone contact: \(style) \(side)")
            }
        }
    }
    func testPlayfulReactionsVaryByCharacterAndResetAfterPause() {
        var signatures = Set<String>()
        for style in SidebarAppearance.selectable {
            var interaction = CompanionInteraction()
            let reactions = (0..<4).compactMap { interaction.tap(style, at: Double($0)) }
            XCTAssertEqual(reactions.first, .pet)
            XCTAssertEqual(Set(reactions).count, 4)
            signatures.insert(reactions.map(\.rawValue).joined(separator: ","))
            XCTAssertNil(interaction.tap(style, at: 3.1), "Rapid clicks are throttled")
            XCTAssertEqual(interaction.tap(style, at: 20), .pet, "Quiet gaps reset to a gentle pet")
        }
        XCTAssertEqual(signatures.count, SidebarAppearance.selectable.count)
    }
    func testApproachHasCooldownAndPetSequencesAreIndependent() {
        var interaction = CompanionInteraction()
        XCTAssertTrue(interaction.approach(at: 0))
        XCTAssertFalse(interaction.approach(at: 1))
        XCTAssertTrue(interaction.approach(at: 20))
        XCTAssertEqual(interaction.tap(.panda, at: 21), .pet)
        XCTAssertEqual(interaction.tap(.bunny, at: 22), .pet)
        XCTAssertEqual(interaction.tap(.panda, at: 23), .greet)
        XCTAssertEqual(interaction.tap(.bunny, at: 24), .play)
    }
    func testDailySequenceHasVarietyAndCausalTransitions() {
        for _ in 0..<20 {
            var sequence = CompanionActivitySequence()
            var previous: CompanionActivity?, seen = Set<CompanionActivity>()
            for _ in 0..<60 {
                let activity = sequence.next()
                if previous == nil || previous == .hungry { XCTAssertEqual(activity, .snack) }
                if previous == .sleep { XCTAssertEqual(activity, .stretch) }
                XCTAssertNotEqual(activity, previous)
                seen.insert(activity); previous = activity
            }
            XCTAssertEqual(seen, Set(CompanionActivity.daily))
        }
    }
    func testEveryPetSupportsEveryDailyActivityWithoutUnboundedAnimations() {
        func inspect(_ layer: CALayer) {
            for key in layer.animationKeys() ?? [] {
                guard let animation = layer.animation(forKey: key) else { continue }
                XCTAssertTrue(animation.duration.isFinite)
                XCTAssertTrue(animation.repeatCount.isFinite)
                XCTAssertLessThanOrEqual(animation.duration * Double(max(1, animation.repeatCount)), 10.01)
                XCTAssertTrue(animation.isRemovedOnCompletion)
            }
            layer.sublayers?.forEach(inspect)
        }
        let emblem = SidebarEmblem()
        for style in SidebarAppearance.selectable {
            emblem.configure(style)
            let restingLayerCount = emblem.sublayers?.count
            for activity in CompanionActivity.allCases {
                emblem.playActivity(activity)
                XCTAssertEqual(emblem.currentActivity, activity)
                XCTAssertTrue(emblem.hasMotion)
                inspect(emblem)
                emblem.update(remaining: 42, scale: 2)
                XCTAssertEqual(emblem.currentActivity, activity, "Cached quota refresh must not restart the story")
                emblem.stopMotion()
                XCTAssertFalse(emblem.hasMotion)
                XCTAssertNil(emblem.currentActivity)
                XCTAssertEqual(emblem.sublayers?.count, restingLayerCount, "Transient props must be released")
            }
            emblem.playActivity(.sleep)
            emblem.playActivity(.music)
            XCTAssertEqual(emblem.sublayers?.count, restingLayerCount, "All props stay on their joints; no transient layer accumulation")
            emblem.configure(.capsule)
            XCTAssertNil(emblem.currentActivity)
            XCTAssertFalse(emblem.hasMotion)
        }
    }
    func testEachCharacterHasItsOwnPlayChoreographyAndTranslatedCaptions() {
        let choreographies = SidebarAppearance.selectable.map { CompanionPuppet.make($0)!.pose(.play, progress: 0.45).sorted { $0.key < $1.key }.description }
        XCTAssertEqual(Set(choreographies).count, SidebarAppearance.selectable.count)
        for language in AppLanguage.supported {
            for key in ["小伙伴日常动作", "活泼互动模式", "摸摸脑袋", "蹭蹭你的手，好开心", "眯一会儿，陪着你", "有点饿了，找点零食", "这首歌，轻轻摇", "咕嘟，喝一小口"] {
                XCTAssertNotNil(L10n.catalogs[language]?[key])
            }
        }
    }
}
