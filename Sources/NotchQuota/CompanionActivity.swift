import AppKit
import QuartzCore

/// Local theatre, never account state, a notification, or a simulated care obligation.
enum CompanionActivity: String, CaseIterable {
    case snack, drink, sleep, hungry, music, stretch, play, groom, read, walk, look, yawn, greet, pickup, land, pet
    static var daily: [Self] { allCases.filter { ![.greet, .pickup, .land, .pet].contains($0) } }
    var title: String {
        let key: String
        switch self {
        case .snack: key = "吃点零食"
        case .drink: key = "喝一杯水"
        case .sleep: key = "打个小盹"
        case .hungry: key = "找找吃的"
        case .music: key = "听听音乐"
        case .stretch: key = "伸个懒腰"
        case .play: key = "玩一会儿"
        case .groom: key = "整理毛毛"
        case .read: key = "翻翻小书"
        case .walk: key = "散个小步"
        case .look: key = "四处看看"
        case .yawn: key = "打个哈欠"
        case .greet: key = "打个招呼"
        case .pickup: key = "轻轻提起"
        case .land: key = "轻轻落地"
        case .pet: key = "摸摸脑袋"
        }
        return L10n.text(key)
    }
    var duration: TimeInterval {
        switch self {
        case .sleep: return 10
        case .music: return 7
        case .hungry, .yawn: return 3.5
        case .greet: return 2.4
        case .pickup: return 2
        case .land: return 0.9
        case .pet: return 2.6
        case .read: return 8
        default: return 5
        }
    }
    func caption(for style: SidebarAppearance, quota: Double? = nil) -> String {
        if let quota {
            if quota <= 20 {
                if let text = lowQuotaCaption(for: style) { return text }
            } else if quota >= 80 {
                if let text = highQuotaCaption(for: style) { return text }
            }
        }
        return defaultCaption(for: style)
    }
    private func lowQuotaCaption(for style: SidebarAppearance) -> String? {
        switch self {
        case .sleep, .yawn:
            switch style {
            case .turtle: return L10n.text("额度见底啦，缩进壳里充会儿电")
            case .fox: return L10n.text("耳朵软趴趴... 额度快见底了，先睡一觉")
            case .ghost: return L10n.text("星星灯快熄了，飘下来小睡一会儿")
            default: return nil
            }
        case .snack, .hungry:
            switch style {
            case .turtle: return L10n.text("粮仓见底，慢慢嚼一片小叶子")
            case .fox: return L10n.text("浆果快吃完啦，省着点力气")
            case .ghost: return L10n.text("星星糖只剩一颗了，小口尝尝")
            default: return nil
            }
        case .pet:
            switch style {
            case .turtle: return L10n.text("蹭蹭你，就算额度不多也一直陪着你")
            case .fox: return L10n.text("下巴搭在你手心，想从你这里充点电")
            case .ghost: return L10n.text("冰凉凉地贴贴你，心里暖洋洋的")
            default: return nil
            }
        case .greet:
            switch style {
            case .turtle: return L10n.text("揉揉眼睛，电量不多也要陪着你")
            case .fox: return L10n.text("晃晃耳朵，今天也要照顾好自己哦")
            case .ghost: return L10n.text("光芒微弱，但我一直都在呢")
            default: return nil
            }
        case .play:
            switch style {
            case .turtle: return L10n.text("慢悠悠晃一下，省点电")
            case .fox: return L10n.text("轻轻扑两下，力气留着下一次")
            case .ghost: return L10n.text("星星有点暗，轻轻飘一下")
            default: return nil
            }
        case .pickup:
            return L10n.text("把我揣进兜里充会儿电吧")
        case .land:
            return L10n.text("轻轻趴下，休息一下好舒服")
        default:
            return nil
        }
    }
    private func highQuotaCaption(for style: SidebarAppearance) -> String? {
        switch self {
        case .play:
            switch style {
            case .turtle: return L10n.text("电量超满，慢吞吞也是元气十足！")
            case .fox: return L10n.text("尾巴摇成螺旋桨！快去探险！")
            case .ghost: return L10n.text("能量满格，连幽灵尾巴都在发光！")
            default: return nil
            }
        case .pet:
            switch style {
            case .turtle: return L10n.text("蹭蹭你！今天状态超级棒！")
            case .fox: return L10n.text("咕噜咕噜~ 尾巴兴奋地拍打你的手！")
            case .ghost: return L10n.text("绕着你的指尖欢快地转圈圈！")
            default: return nil
            }
        case .greet:
            switch style {
            case .turtle: return L10n.text("抹茶小龟报到！今天精力充沛！")
            case .fox: return L10n.text("枫糖小狐来啦！能量拉满，准备出发！")
            case .ghost: return L10n.text("幽灵闪亮登场！能量像银河一样满！")
            default: return nil
            }
        case .music:
            switch style {
            case .turtle: return L10n.text("欢快的旋律，连小龟壳都要跳起来了")
            case .fox: return L10n.text("欢快打拍子，尾巴跳起欢送舞")
            case .ghost: return L10n.text("大合奏响起来，星星都跟着跳舞啦")
            default: return nil
            }
        case .snack:
            switch style {
            case .turtle: return L10n.text("大口嚼嫩叶，今天胃口特别好")
            case .fox: return L10n.text("满满一大捧浆果，开心大餐！")
            case .ghost: return L10n.text("满天星星糖，甜滋滋的一天！")
            default: return nil
            }
        case .pickup:
            return L10n.text("起飞咯！今天动力十足！")
        case .land:
            return L10n.text("超稳落地！接下来做什么？")
        default:
            return nil
        }
    }
    private func defaultCaption(for style: SidebarAppearance) -> String {
        switch self {
        case .snack:
            switch style {
            case .panda: return L10n.text("竹子咔嚓咔嚓")
            case .bunny: return L10n.text("胡萝卜好甜呀")
            case .fox: return L10n.text("闻到浆果香了")
            case .turtle: return L10n.text("慢慢嚼一片叶子")
            case .ghost: return L10n.text("尝一口星星糖")
            case .cloud: return L10n.text("棉花糖一样的下午")
            case .bear: return L10n.text("一点点蜂蜜就很甜")
            case .cat: return L10n.text("小鱼干时间")
            default: return L10n.text("今天的小鱼真新鲜")
            }
        case .groom: return L10n.text("整理一下，蓬蓬松松")
        case .read: return L10n.text("陪你翻几页小书")
        case .walk: return L10n.text("在这里散个小步")
        case .look: return L10n.text("看看你在忙什么")
        case .yawn: return L10n.text("啊呜，有一点困了")
        case .greet: return L10n.text("嘿，我在这里呀")
        case .pickup: return L10n.text("带我去哪儿呀")
        case .land: return L10n.text("稳稳落地啦")
        case .pet: return L10n.text("蹭蹭你的手，好开心")
        case .drink:
            switch style {
            case .panda: return L10n.text("双爪捧好，慢慢喝")
            case .bunny: return L10n.text("蹦累啦，喝口水")
            case .fox: return L10n.text("闻一闻，再尝一口")
            case .turtle: return L10n.text("不着急，一小口就好")
            case .ghost: return L10n.text("幽灵也有自己的小杯子")
            case .cloud: return L10n.text("给云朵补一点水")
            case .bear: return L10n.text("抱紧杯子，暖暖的")
            case .cat: return L10n.text("先尝一口，喵")
            case .penguin: return L10n.text("小翅膀也能捧杯子")
            default: return title
            }
        case .sleep:
            switch style {
            case .panda: return L10n.text("抱着圆肚子，眯一会儿")
            case .bunny: return L10n.text("耳朵垂下来，晚安呀")
            case .fox: return L10n.text("用大尾巴守住小梦")
            case .turtle: return L10n.text("缩回壳边，慢慢入睡")
            case .ghost: return L10n.text("飘着也能做个甜梦")
            case .cloud: return L10n.text("软软地团成一朵梦")
            case .bear: return L10n.text("爪子抱好，呼噜呼噜")
            case .cat: return L10n.text("尾巴收好，猫猫午睡")
            case .penguin: return L10n.text("小脚站稳，点头打盹")
            default: return title
            }
        case .hungry: return L10n.text("有点饿了，找点零食")
        case .music:
            switch style {
            case .panda: return L10n.text("跟着慢拍，轻轻点头")
            case .bunny: return L10n.text("耳朵也听见节拍啦")
            case .fox: return L10n.text("尾巴跟着旋律摇")
            case .turtle: return L10n.text("慢慢听，一首就好")
            case .ghost: return L10n.text("飘着听一首小夜曲")
            case .cloud: return L10n.text("让旋律托着云朵")
            case .bear: return L10n.text("舒服到眯起眼睛")
            case .cat: return L10n.text("尾巴打拍，小脚轻点")
            case .penguin: return L10n.text("小脚一左一右打拍")
            default: return title
            }
        case .stretch: return L10n.text("伸个懒腰，慢慢来")
        case .play:
            switch style {
            case .panda: return L10n.text("竹叶也会跳舞")
            case .bunny: return L10n.text("蹦一下，再蹦一下")
            case .fox: return L10n.text("追一片小枫叶")
            case .turtle: return L10n.text("慢一点，也很开心")
            case .ghost: return L10n.text("接住一颗小星星")
            case .cloud: return L10n.text("把星星轻轻举高")
            case .bear: return L10n.text("抱抱今天的好心情")
            case .cat: return L10n.text("毛线球，别跑呀")
            default: return L10n.text("小碎步，滑一下")
            }
        }
    }
}

/// A shuffled bag gives variety without repeated random choices. Small story links
/// make hunger lead to a snack and a nap lead to stretching, without timers per pet.
struct CompanionActivitySequence {
    private var bag: [CompanionActivity] = []
    private(set) var previous: CompanionActivity?
    mutating func next(style: SidebarAppearance = .panda, hour: Int = 12, quota: Double? = nil) -> CompanionActivity {
        let next: CompanionActivity
        if previous == nil || previous == .hungry { next = .snack }
        else if previous == .sleep { next = .stretch }
        else if previous == .yawn { next = .sleep }
        else {
            if bag.isEmpty {
                bag = CompanionActivity.daily.shuffled()
                let favorite: CompanionActivity
                if let quota {
                    if quota <= 20 {
                        favorite = .yawn
                    } else if quota >= 80 {
                        favorite = (style == .ghost ? .music : .play)
                    } else {
                        favorite = defaultFavorite(for: style)
                    }
                } else {
                    favorite = defaultFavorite(for: style)
                }
                let first = (hour >= 22 || hour < 7) ? CompanionActivity.yawn : favorite
                bag.removeAll { $0 == first }; bag.append(first)
            }
            if let quota {
                let preferred: Set<CompanionActivity>
                if quota <= 20 {
                    preferred = [.yawn, .hungry, .drink, .read]
                } else if quota >= 80 {
                    preferred = [.play, .music, .walk]
                } else {
                    preferred = []
                }
                if let index = bag.lastIndex(where: { preferred.contains($0) && $0 != previous }) {
                    bag.swapAt(index, bag.count - 1)
                }
            }
            if bag.last == previous, bag.count > 1 { bag.swapAt(0, bag.count - 1) }
            next = bag.removeLast()
        }
        bag.removeAll { $0 == next }
        previous = next
        return next
    }

    private func defaultFavorite(for style: SidebarAppearance) -> CompanionActivity {
        switch style {
        case .panda, .bear: return .snack
        case .bunny, .fox: return .play
        case .turtle: return .read
        case .cat: return .groom
        case .penguin: return .walk
        case .ghost: return .music
        default: return .look
        }
    }
}

struct CompanionPersonality {
    let tempo: Double
    let tilt: Double
    let lift: Double
    let playX: [Double]
    let playY: [Double]
    static func profile(_ style: SidebarAppearance) -> Self {
        switch style {
        case .panda: return .init(tempo: 1.15, tilt: 0.045, lift: 0.35, playX: [0, -0.4, 0.5, -0.2, 0], playY: [0, -0.4, 0.8, 0.2, 0])
        case .bunny: return .init(tempo: 0.8, tilt: 0.055, lift: 1.5, playX: [0, -0.6, 0.4, 0.5, 0], playY: [0, 2.4, 0, 1.6, 0])
        case .fox: return .init(tempo: 0.95, tilt: 0.10, lift: 0.55, playX: [0, -1.2, 1.2, 0.5, 0], playY: [0, 0.6, 1, 0.3, 0])
        case .turtle: return .init(tempo: 1.6, tilt: 0.025, lift: 0.15, playX: [0, 0.2, 0.6, 0.3, 0], playY: [0, 0, 0.2, 0.1, 0])
        case .ghost: return .init(tempo: 1.25, tilt: 0.07, lift: 1.2, playX: [0, -1, 0, 1, 0], playY: [0, 1.5, 0.6, 1.8, 0])
        case .cloud: return .init(tempo: 1.45, tilt: 0.035, lift: 0.8, playX: [0, 0.8, 1.4, 0.6, 0], playY: [0, 0.5, 1.3, 0.8, 0])
        case .bear: return .init(tempo: 1.3, tilt: 0.06, lift: 0.3, playX: [0, -0.5, 0, 0.5, 0], playY: [0, -0.5, 0.4, -0.3, 0])
        case .cat: return .init(tempo: 0.9, tilt: 0.085, lift: 0.65, playX: [0, 1, -1.1, 0.4, 0], playY: [0, -0.4, 1.4, 0.2, 0])
        default: return .init(tempo: 1, tilt: 0.12, lift: 0.6, playX: [0, -1.3, 1.3, 0.7, 0], playY: [0, 0.4, 0.2, 0.4, 0])
        }
    }
}

/// Owns exactly one tolerant, one-shot timer. Idle gaps are long and render nothing.
@MainActor final class SidebarCompanionLife {
    private let emblem: SidebarEmblem
    private var timer: Timer?
    private var sequences: [SidebarAppearance: CompanionActivitySequence] = [:]
    private var nextActivityAt: TimeInterval = 0
    private(set) var activity: CompanionActivity?
    var eligible: (() -> Bool)?
    var lively: (() -> Bool)?
    private var welcomed: Set<SidebarAppearance> = []
    var location: (() -> (NSRect, NSRect))?
    private var bubble: NSPanel?
    var hasScheduledWork: Bool { timer != nil }
    var isCaptionVisible: Bool { bubble?.isVisible == true }
    init(emblem: SidebarEmblem) { self.emblem = emblem }
    deinit { timer?.invalidate() }
    func sync() {
        guard eligible?() == true else { stop(); return }
        guard timer == nil else { return }
        schedule(after: max(2, nextActivityAt - ProcessInfo.processInfo.systemUptime)) { $0.beginNext() }
    }
    func stop() {
        timer?.invalidate(); timer = nil
        if activity != nil { emblem.stopMotion() }
        activity = nil; bubble?.orderOut(nil)
    }
    private func schedule(after delay: TimeInterval, action: @escaping @MainActor (SidebarCompanionLife) -> Void) {
        timer?.invalidate()
        let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.timer = nil
                guard self.eligible?() == true else { self.stop(); return }
                action(self)
            }
        }
        next.tolerance = min(1, delay * 0.1); timer = next
        RunLoop.main.add(next, forMode: .common)
    }
    private func beginNext() {
        let style = emblem.appearance
        if lively?() == true, welcomed.insert(style).inserted { begin(.greet); return }
        var sequence = sequences[style] ?? CompanionActivitySequence()
        let next = sequence.next(style: style, hour: Calendar.current.component(.hour, from: Date()), quota: emblem.remainingQuota)
        sequences[style] = sequence
        begin(next)
    }
    func perform(_ next: CompanionActivity) {
        if next == .greet { welcomed.insert(emblem.appearance) }
        stop(); begin(next)
    }
    private func begin(_ next: CompanionActivity) {
        activity = next
        nextActivityAt = ProcessInfo.processInfo.systemUptime + next.duration + ([CompanionActivity.hungry, .yawn, .sleep].contains(next) ? 3 : (lively?() == true ? Double.random(in: 18...36) : Double.random(in: 35...65)))
        emblem.playActivity(next)
        if let (anchor, screen) = location?() { showCaption(next.caption(for: emblem.appearance, quota: emblem.remainingQuota), anchor: anchor, screen: screen) }
        // Text disappears first; the remaining gesture is quiet visual company.
        schedule(after: min(3.5, next.duration)) { life in
            life.bubble?.orderOut(nil)
            life.schedule(after: max(0.1, next.duration - min(3.5, next.duration))) { life in
                life.emblem.stopMotion(); life.activity = nil
                life.schedule(after: max(2, life.nextActivityAt - ProcessInfo.processInfo.systemUptime)) { $0.beginNext() }
            }
        }
    }
    private func showCaption(_ text: String, anchor: NSRect, screen: NSRect) {
        let panel = bubble ?? NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        bubble = panel; panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11, weight: .medium); label.textColor = NSColor(srgbRed: 0.25, green: 0.22, blue: 0.29, alpha: 1)
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 24, height: 30)
        let surface = NSView(frame: NSRect(origin: .zero, size: size)); surface.wantsLayer = true
        surface.layer?.backgroundColor = emblem.appearance.accent.blended(withFraction: 0.9, of: .white)!.cgColor
        surface.layer?.cornerRadius = 15
        surface.layer?.borderColor = emblem.appearance.accent.withAlphaComponent(0.25).cgColor; surface.layer?.borderWidth = 0.5
        label.frame.origin = NSPoint(x: 12, y: (30 - label.frame.height) / 2); surface.addSubview(label)
        panel.contentView = surface
        let y = anchor.maxY + size.height + 6 <= screen.maxY ? anchor.maxY + 6 : anchor.minY - size.height - 6
        panel.setFrame(NSRect(x: min(screen.maxX - size.width - 6, max(screen.minX + 6, anchor.midX - size.width / 2)), y: max(screen.minY + 6, y), width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        let fade = CABasicAnimation(keyPath: "opacity"); fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.25
        surface.layer?.add(fade, forKey: "caption")
    }
}
