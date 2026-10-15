import Foundation

/// Pointer-driven reactions use event timestamps, never another polling timer.
/// Each companion remembers its own small interaction sequence.
struct CompanionInteraction {
    private var lastApproach = -Double.infinity
    private var lastTap = -Double.infinity
    private var taps: [SidebarAppearance: (time: TimeInterval, count: Int)] = [:]
    mutating func approach(at now: TimeInterval) -> Bool {
        guard now - lastApproach >= 20 else { return false }
        lastApproach = now; return true
    }
    mutating func tap(_ style: SidebarAppearance, at now: TimeInterval) -> CompanionActivity? {
        guard now - lastTap >= 0.25 else { return nil }
        lastTap = now
        let previous = taps[style]
        let count = previous.map { now - $0.time < 8 ? $0.count : 0 } ?? 0
        let sequence: [CompanionActivity]
        switch style {
        case .panda: sequence = [.pet, .greet, .play, .stretch]
        case .bunny: sequence = [.pet, .play, .greet, .music]
        case .fox: sequence = [.pet, .play, .look, .greet]
        case .turtle: sequence = [.pet, .look, .stretch, .read]
        case .ghost: sequence = [.pet, .greet, .music, .play]
        case .cloud: sequence = [.pet, .stretch, .play, .greet]
        case .bear: sequence = [.pet, .greet, .stretch, .play]
        case .cat: sequence = [.pet, .play, .groom, .greet]
        default: sequence = [.pet, .walk, .play, .greet]
        }
        taps[style] = (now, count + 1)
        return sequence[count % sequence.count]
    }
}
