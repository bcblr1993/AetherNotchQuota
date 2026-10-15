import AppKit
import QuartzCore

/// Original, resolution-independent mochi characters. Every visible appendage is
/// a separate joint; expression changes deform geometry rather than cover a bitmap.
enum CompanionDrawing {
    static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
    }
    static let ink = color(0x493C50), cream = color(0xFFF8E9), blush = color(0xF5A5A8)
    @discardableResult static func shape(_ path: CGPath, _ color: NSColor, in parent: CALayer, stroke: NSColor? = nil, width: CGFloat = 0.4) -> CAShapeLayer {
        let layer = CAShapeLayer(); layer.path = path; layer.fillColor = color.cgColor
        layer.strokeColor = stroke?.cgColor; layer.lineWidth = width; layer.lineJoin = .round; layer.lineCap = .round
        parent.addSublayer(layer); return layer
    }
    @discardableResult static func oval(_ rect: CGRect, _ color: NSColor, in parent: CALayer) -> CAShapeLayer {
        shape(CGPath(ellipseIn: rect, transform: nil), color, in: parent)
    }
    static func line(_ points: [CGPoint], _ color: NSColor, width: CGFloat, in parent: CALayer) {
        let path = CGMutablePath(); path.addLines(between: points); shape(path, .clear, in: parent, stroke: color, width: width)
    }
    static func round(_ rect: CGRect, radius: CGFloat, _ color: NSColor, in parent: CALayer) {
        shape(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil), color, in: parent)
    }
    /// Subtle fixed highlight and outline, no offscreen shadow/filter pass.
    static func plush(_ rect: CGRect, _ color: NSColor, in parent: CALayer) {
        oval(rect, color, in: parent)
        let rim = CAShapeLayer(); rim.path = CGPath(ellipseIn: rect.insetBy(dx: 0.3, dy: 0.3), transform: nil)
        rim.fillColor = nil; rim.strokeColor = color.blended(withFraction: 0.14, of: ink)!.cgColor; rim.lineWidth = 0.45; parent.addSublayer(rim)
        oval(CGRect(x: rect.minX + rect.width * 0.18, y: rect.maxY - rect.height * 0.23, width: rect.width * 0.32, height: rect.height * 0.1), .white.withAlphaComponent(0.28), in: parent)
    }
}

/// Character anatomy is shared, silhouettes and accessories are species-specific.
final class CompanionCharacter {
    let root = CALayer(), torso = CALayer(), head = CALayer(), tail = CALayer()
    let leftEar = CALayer(), rightEar = CALayer(), leftFoot = CALayer(), rightFoot = CALayer()
    let left = CompanionLimb(), right = CompanionLimb()
    let leftEye = CALayer(), rightEye = CALayer(), mouth = CALayer()
    let cup = CALayer(), food = CALayer(), headphones = CALayer(), book = CALayer(), toy = CALayer()
    let page = CALayer(), shadow = CALayer()
    let style: SidebarAppearance
    var floating: Bool { style == .ghost || style == .cloud }
    var fur: NSColor {
        switch style {
        case .turtle: return CompanionDrawing.color(0xB0D682) // 鲜嫩抹茶绿
        case .fox: return CompanionDrawing.color(0xEF8130)    // 暖枫糖橙
        case .ghost: return CompanionDrawing.color(0xF3ECFD)  // 梦幻淡月白紫
        case .panda: return CompanionDrawing.cream
        case .bunny: return CompanionDrawing.color(0xFFF0DB)
        case .bear: return CompanionDrawing.color(0xD7AC76)
        case .cat: return CompanionDrawing.color(0xF4C080)
        case .penguin: return CompanionDrawing.color(0xA5CBE1)
        case .cloud: return CompanionDrawing.color(0xF0F0FF)
        default: return CompanionDrawing.color(0xB0D682)
        }
    }
    init(style: SidebarAppearance) {
        self.style = style
        root.bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        root.position = CGPoint(x: 18, y: 18)
        for (name, layer) in [("body", torso), ("head", head), ("tail", tail), ("leftEar", leftEar), ("rightEar", rightEar), ("leftFoot", leftFoot), ("rightFoot", rightFoot), ("leftEye", leftEye), ("rightEye", rightEye), ("mouth", mouth), ("cup", cup), ("headphones", headphones), ("book", book), ("toy", toy)] { layer.name = name }
        left.name = "leftShoulder"; right.name = "rightShoulder"
        let d = CompanionDrawing.self, dark = d.color(0x625768)
        d.oval(CGRect(x: 7, y: 0, width: 22, height: 3), style.accent.withAlphaComponent(0.13), in: shadow)
        shadow.bounds = CGRect(x: 0, y: 0, width: 36, height: 4); shadow.position = CGPoint(x: 18, y: 2)
        root.addSublayer(shadow)
        tail.position = CGPoint(x: 24, y: 8); root.addSublayer(tail)
        if style == .fox {
            // Fox soul: large, lush, curved tail with prominent snowy white tip
            let p = CGMutablePath()
            p.move(to: .zero)
            p.addCurve(to: CGPoint(x: 10, y: 19), control1: CGPoint(x: 15, y: 0), control2: CGPoint(x: 17, y: 11))
            p.addCurve(to: .zero, control1: CGPoint(x: 4, y: 15), control2: CGPoint(x: 3, y: 6))
            p.closeSubpath()
            d.shape(p, fur, in: tail, stroke: d.color(0xDB7024), width: 0.5)
            // Snow white fluffy tail tip
            let tip = CGMutablePath()
            tip.move(to: CGPoint(x: 5, y: 12))
            tip.addCurve(to: CGPoint(x: 10, y: 19), control1: CGPoint(x: 7, y: 14), control2: CGPoint(x: 13, y: 15))
            tip.addCurve(to: CGPoint(x: 5, y: 12), control1: CGPoint(x: 7, y: 17), control2: CGPoint(x: 4, y: 14))
            tip.closeSubpath()
            d.shape(tip, d.cream, in: tail)
        } else if style == .turtle {
            // Tiny, cute rounded turtle tail
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 1))
            p.addQuadCurve(to: CGPoint(x: 4, y: 4), control: CGPoint(x: 3, y: 0))
            p.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: 1, y: 5))
            p.closeSubpath()
            d.shape(p, fur, in: tail, stroke: d.color(0x8FA866), width: 0.4)
        } else if style == .cat {
            let p = CGMutablePath(); p.move(to: .zero); p.addCurve(to: CGPoint(x: 6, y: 13), control1: CGPoint(x: 12, y: -1), control2: CGPoint(x: 13, y: 13))
            d.shape(p, .clear, in: tail, stroke: fur, width: 4); d.line([CGPoint(x: 7, y: 9), CGPoint(x: 9, y: 10)], d.color(0xD89454), width: 1.5, in: tail)
        } else if style == .bunny { d.plush(CGRect(x: 0, y: 0, width: 7, height: 7), .white, in: tail) }

        torso.position = CGPoint(x: 18, y: 10); root.addSublayer(torso)
        if style == .ghost {
            // Three continuous soft ripples forming a floating jelly hem
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -10, y: 6))
            p.addCurve(to: CGPoint(x: -11, y: -6), control1: CGPoint(x: -11, y: 2), control2: CGPoint(x: -12, y: -2))
            p.addQuadCurve(to: CGPoint(x: -4, y: -6), control: CGPoint(x: -7.5, y: -2))
            p.addQuadCurve(to: CGPoint(x: 3, y: -6), control: CGPoint(x: -0.5, y: -10))
            p.addQuadCurve(to: CGPoint(x: 11, y: -6), control: CGPoint(x: 7, y: -2))
            p.addCurve(to: CGPoint(x: 10, y: 6), control1: CGPoint(x: 12, y: -2), control2: CGPoint(x: 11, y: 2))
            p.closeSubpath()
            d.shape(p, fur, in: torso, stroke: d.color(0xDDD3F5), width: 0.5)
            // Subtle glossy sheen on ghost's belly
            d.oval(CGRect(x: -6, y: -2, width: 12, height: 5), .white.withAlphaComponent(0.35), in: torso)
        } else if style == .turtle {
            // Rounded matcha turtle shell base
            d.plush(CGRect(x: -11, y: -7, width: 22, height: 19), d.color(0x567E47), in: torso)
            // Light cream plastron
            d.oval(CGRect(x: -6.5, y: -5, width: 13, height: 13), d.color(0xE9F0AE), in: torso)
            // Distinct geometric dorsal scute pattern
            let p = CGMutablePath()
            p.addLines(between: [.init(x: -4.5, y: 0), .init(x: -4.5, y: 6), .init(x: 0, y: 9.5), .init(x: 4.5, y: 6), .init(x: 4.5, y: 0), .init(x: 0, y: -3.5)])
            p.closeSubpath()
            d.shape(p, d.color(0x82A66C), in: torso, stroke: d.color(0xC2DE9E), width: 0.6)
            // Radial scute accents
            d.line([.init(x: -4.5, y: 3), .init(x: -8, y: 3)], d.color(0xC2DE9E), width: 0.5, in: torso)
            d.line([.init(x: 4.5, y: 3), .init(x: 8, y: 3)], d.color(0xC2DE9E), width: 0.5, in: torso)
        } else if style == .fox {
            // Warm fox body with lush white chest fluff
            d.plush(CGRect(x: -9, y: -8, width: 18, height: 20), fur, in: torso)
            d.oval(CGRect(x: -5, y: -4, width: 10, height: 13), d.cream, in: torso)
            // Fluff accents
            d.line([.init(x: 0, y: 3), .init(x: -2, y: 0)], d.color(0xEDC39F), width: 0.45, in: torso)
            d.line([.init(x: 0, y: 3), .init(x: 2, y: 0)], d.color(0xEDC39F), width: 0.45, in: torso)
        } else {
            d.plush(CGRect(x: -9, y: -8, width: 18, height: 20), style == .panda ? dark : fur, in: torso)
            d.oval(CGRect(x: -6, y: -5, width: 12, height: 13), d.cream, in: torso)
        }

        for (index, foot) in [leftFoot, rightFoot].enumerated() {
            foot.position = CGPoint(x: index == 0 ? 12 : 24, y: 3); root.addSublayer(foot)
            if !floating {
                let footColor = style == .turtle ? fur : (style == .fox ? d.color(0xD96D20) : fur)
                d.plush(CGRect(x: -3.5, y: -2, width: 7, height: 5), footColor, in: foot)
            }
        }

        head.position = CGPoint(x: 18, y: 23); root.addSublayer(head)
        for (index, ear) in [leftEar, rightEar].enumerated() {
            ear.position = CGPoint(x: index == 0 ? -7 : 7, y: 6); head.addSublayer(ear)
            if style == .fox {
                // Pointy perky fox ears with pink inner and dark caramel tip
                let p = CGMutablePath()
                p.move(to: CGPoint(x: -4.5, y: -1))
                p.addQuadCurve(to: CGPoint(x: index == 0 ? -2.5 : 2.5, y: 10.5), control: CGPoint(x: -6, y: 7.5))
                p.addQuadCurve(to: CGPoint(x: 4.5, y: -1), control: CGPoint(x: 5.5, y: 7))
                p.closeSubpath()
                d.shape(p, fur, in: ear, stroke: d.color(0xDB7024), width: 0.5)
                // Soft pink inner ear
                d.oval(CGRect(x: -1.8, y: 1, width: 3.6, height: 5.5), d.blush.withAlphaComponent(0.85), in: ear)
                // Dark caramel ear tip
                let tip = CGMutablePath()
                tip.move(to: CGPoint(x: index == 0 ? -1.5 : -0.5, y: 7.5))
                tip.addLine(to: CGPoint(x: index == 0 ? -2.5 : 2.5, y: 10.5))
                tip.addLine(to: CGPoint(x: index == 0 ? 0.5 : 1.5, y: 7.5))
                tip.closeSubpath()
                d.shape(tip, d.color(0x4A2C1C), in: ear)
            } else if style == .bunny {
                d.plush(CGRect(x: -2.8, y: -1, width: 5.6, height: 12), fur, in: ear); d.oval(CGRect(x: -1.3, y: 1, width: 2.6, height: 8), d.blush.withAlphaComponent(0.65), in: ear)
            } else if style == .cat {
                let p = CGMutablePath(); p.move(to: CGPoint(x: -4, y: -1)); p.addQuadCurve(to: CGPoint(x: index == 0 ? -2 : 2, y: 9), control: CGPoint(x: -5, y: 7)); p.addQuadCurve(to: CGPoint(x: 4, y: -1), control: CGPoint(x: 5, y: 6)); p.closeSubpath(); d.shape(p, fur, in: ear); d.oval(CGRect(x: -1.5, y: 1, width: 3, height: 5), d.blush, in: ear)
            } else if style == .panda || style == .bear {
                d.plush(CGRect(x: -4, y: -1, width: 8, height: 8), style == .panda ? dark : fur, in: ear); d.oval(CGRect(x: -2, y: 1, width: 4, height: 4), style == .panda ? d.color(0x8C7F8E) : d.color(0xBB8B64), in: ear)
            }
        }

        if style == .cloud {
            for r in [CGRect(x: -13, y: -7, width: 15, height: 16), CGRect(x: -7, y: -6, width: 15, height: 19), CGRect(x: 1, y: -7, width: 13, height: 15)] { d.oval(r, fur, in: head) }
        } else if style == .turtle {
            // Smooth matcha turtle dome
            d.plush(CGRect(x: -11, y: -9, width: 22, height: 17), fur, in: head)
        } else if style == .fox {
            // Fox head with snowy white cheek fluffs
            d.plush(CGRect(x: -12, y: -9, width: 24, height: 20), fur, in: head)
            d.oval(CGRect(x: -11, y: -7.5, width: 11, height: 11), d.cream, in: head)
            d.oval(CGRect(x: 0, y: -7.5, width: 11, height: 11), d.cream, in: head)
        } else {
            d.plush(CGRect(x: -12, y: -9, width: 24, height: 20), fur, in: head)
        }

        // Sparkling watery eyes with primary & secondary specular highlights
        for (index, eye) in [leftEye, rightEye].enumerated() {
            eye.position = CGPoint(x: index == 0 ? -4.8 : 4.8, y: 1); head.addSublayer(eye)
            d.oval(CGRect(x: -1.1, y: -1.5, width: 2.2, height: 3.2), d.ink, in: eye)
            // Main sparkle highlight
            d.oval(CGRect(x: -0.65, y: 0.35, width: 0.8, height: 1.0), .white, in: eye)
            // Secondary cute sub-sparkle
            d.oval(CGRect(x: 0.2, y: -1.0, width: 0.45, height: 0.45), .white.withAlphaComponent(0.85), in: eye)
            // Rosy blush on cheeks
            let blushColor = style == .turtle ? d.blush.withAlphaComponent(0.55) : (style == .ghost ? d.blush.withAlphaComponent(0.75) : d.blush.withAlphaComponent(0.65))
            d.oval(CGRect(x: index == 0 ? -9 : 6, y: -3.3, width: 3.2, height: 1.8), blushColor, in: head)
        }

        // Nose: tiny dark triangle for fox, subtle point for others
        if style == .fox {
            let nosePath = CGMutablePath()
            nosePath.move(to: CGPoint(x: -1, y: -1.6))
            nosePath.addLine(to: CGPoint(x: 1, y: -1.6))
            nosePath.addLine(to: CGPoint(x: 0, y: -2.6))
            nosePath.closeSubpath()
            d.shape(nosePath, d.ink, in: head)
        } else if style != .ghost {
            d.oval(CGRect(x: -0.8, y: -2.1, width: 1.6, height: 1), d.ink, in: head)
        }

        mouth.position = CGPoint(x: 0, y: -3.6); head.addSublayer(mouth)
        let smile = CGMutablePath(); smile.move(to: CGPoint(x: -1, y: 0.4)); smile.addQuadCurve(to: CGPoint(x: 1, y: 0.4), control: CGPoint(x: 0, y: -0.7)); d.shape(smile, .clear, in: mouth, stroke: d.ink, width: 0.45)

        // Accent scarf / neckline ornament
        d.round(CGRect(x: -7, y: -9, width: 14, height: 2), radius: 1, style.accent, in: head)
        d.round(CGRect(x: 4, y: -13, width: 2.5, height: 5), radius: 0.8, style.accent, in: head)

        let paw = style == .fox ? d.color(0xD96D20) : fur
        left.configure(at: CGPoint(x: 9.7, y: 15), color: paw, flipper: false)
        right.configure(at: CGPoint(x: 26.3, y: 15), color: paw, flipper: false)
        root.addSublayer(left); root.addSublayer(right)
        makeProps()
    }
    private func makeProps() {
        let d = CompanionDrawing.self
        // Object origins sit at the grasp point; paws stay in physical contact.
        // Cup tailored to each character: green ceramic for turtle, wood for fox, crystal lilac for ghost
        let cupColor = style == .turtle ? d.color(0x658E55) : (style == .fox ? d.color(0xC46B2C) : style.accent)
        d.shape(CGPath(ellipseIn: CGRect(x: 1, y: -2, width: 4, height: 4), transform: nil), .clear, in: cup, stroke: cupColor, width: 0.9)
        d.round(CGRect(x: -5, y: -3.5, width: 7, height: 7), radius: 1.8, cupColor, in: cup)
        d.oval(CGRect(x: -5, y: 2, width: 7, height: 2), d.cream, in: cup)
        d.oval(CGRect(x: -4.3, y: 2.35, width: 5.6, height: 1), d.color(0xBDDBDE), in: cup)
        d.oval(CGRect(x: -2.8, y: -1, width: 2.5, height: 2.5), .white.withAlphaComponent(0.7), in: cup)
        cup.opacity = 0; right.grip.addSublayer(cup)
        drawFood(in: food); food.position = CGPoint(x: -3.5, y: 1); food.opacity = 0; right.grip.addSublayer(food)
        let band = CGMutablePath(); band.addArc(center: CGPoint(x: 0, y: 0), radius: 10, startAngle: 0, endAngle: .pi, clockwise: false)
        d.shape(band, .clear, in: headphones, stroke: d.ink, width: 1.4)
        for x: CGFloat in [-11, 8] { d.round(CGRect(x: x, y: -3, width: 3, height: 7), radius: 1.5, style.accent, in: headphones); d.line([CGPoint(x: x + 1, y: -0.5), CGPoint(x: x + 1, y: 1.5)], .white.withAlphaComponent(0.7), width: 0.7, in: headphones) }
        headphones.opacity = 0; head.addSublayer(headphones)
        book.position = CGPoint(x: 18, y: 10); book.opacity = 0; root.addSublayer(book)
        d.round(CGRect(x: -7, y: -3, width: 14, height: 8), radius: 1, style.accent, in: book)
        d.round(CGRect(x: -6.5, y: -2, width: 13, height: 7), radius: 0.5, d.cream, in: book)
        d.line([CGPoint(x: 0, y: -2), CGPoint(x: 0, y: 5)], style.accent, width: 0.5, in: book)
        for x: CGFloat in [-5, 1] { for y: CGFloat in [0, 2, 3.5] { d.line([CGPoint(x: x, y: y), CGPoint(x: x + 3.5, y: y)], style.accent.withAlphaComponent(0.4), width: 0.35, in: book) } }
        book.addSublayer(page); d.round(CGRect(x: 0, y: -2, width: 6.4, height: 7), radius: 0.4, d.cream, in: page)
        toy.position = CGPoint(x: 28, y: 5); toy.opacity = 0; root.insertSublayer(toy, below: left)
        if style == .turtle {
            // Fresh, detailed green leaf toy
            d.oval(CGRect(x: -3.5, y: -1.5, width: 7, height: 4.5), d.color(0x7EA85E), in: toy)
            d.line([.init(x: -3.5, y: -1.5), .init(x: 3.5, y: 3)], d.color(0xEBF4BE), width: 0.5, in: toy)
        } else if style == .fox {
            // Bright red autumn maple leaf
            let leaf = CGMutablePath()
            leaf.addLines(between: [.init(x: 0, y: -4), .init(x: -4.5, y: 0), .init(x: -2, y: 1.5), .init(x: -2.5, y: 4), .init(x: 0, y: 3), .init(x: 2.5, y: 6), .init(x: 3.5, y: 1.5), .init(x: 5.5, y: 2.5), .init(x: 3.5, y: -1.5)])
            leaf.closeSubpath()
            d.shape(leaf, d.color(0xD65338), in: toy)
            d.line([.init(x: 0, y: -5), .init(x: 1.5, y: 3)], d.cream, width: 0.45, in: toy)
        } else if style == .ghost {
            // Glowing golden five-pointed sugar star
            SidebarMascotArtwork.star(at: .zero, radius: 3.5, color: d.color(0xFFCE44), in: toy)
            d.oval(CGRect(x: -1, y: 0.5, width: 1.5, height: 1.5), .white.withAlphaComponent(0.8), in: toy)
        } else {
            drawFood(in: toy)
        }
    }
    private func drawFood(in layer: CALayer) {
        let d = CompanionDrawing.self, green = d.color(0x7FA75E), gold = d.color(0xFFCE44)
        switch style {
        case .turtle:
            // Tender two-tone leaf with cream veins
            d.oval(CGRect(x: -3.5, y: -1.5, width: 7, height: 4.5), green, in: layer)
            d.line([.init(x: -3.5, y: -1.5), .init(x: 3.5, y: 3)], d.cream, width: 0.5, in: layer)
        case .fox:
            // Autumn maple leaf snack
            let leaf = CGMutablePath()
            leaf.addLines(between: [.init(x: 0, y: -3.5), .init(x: -4, y: 0), .init(x: -2, y: 1.5), .init(x: -2, y: 3.5), .init(x: 0, y: 2.5), .init(x: 2, y: 5), .init(x: 3, y: 1), .init(x: 5, y: 2), .init(x: 3, y: -1)])
            leaf.closeSubpath()
            d.shape(leaf, d.color(0xD85A3D), in: layer)
            d.line([.init(x: 0, y: -4), .init(x: 1, y: 2.5)], d.cream, width: 0.45, in: layer)
        case .ghost:
            // Glowing star candy
            SidebarMascotArtwork.star(at: .zero, radius: 3.5, color: gold, in: layer)
            d.oval(CGRect(x: -1, y: 0.5, width: 1.2, height: 1.2), .white.withAlphaComponent(0.8), in: layer)
        case .panda:
            d.round(CGRect(x: -1, y: -3, width: 2, height: 12), radius: 0.6, green, in: layer)
            for y: CGFloat in [-1, 3, 7] { d.line([CGPoint(x: -1, y: y), CGPoint(x: 1, y: y)], d.cream, width: 0.45, in: layer) }
            d.oval(CGRect(x: 0, y: 5, width: 5, height: 2), green, in: layer)
        case .bunny:
            let p = CGMutablePath(); p.addLines(between: [.init(x: -2, y: 3), .init(x: 2, y: 3), .init(x: 0, y: -4)]); p.closeSubpath(); d.shape(p, d.color(0xEB9C5C), in: layer)
            d.line([.init(x: 0, y: 3), .init(x: -1, y: 6), .init(x: 0, y: 3), .init(x: 2, y: 5)], green, width: 1, in: layer)
        case .bear: d.round(CGRect(x: -3, y: -3, width: 6, height: 6), radius: 1.8, gold, in: layer); d.round(CGRect(x: -2.5, y: 2, width: 5, height: 1.5), radius: 0.4, d.color(0xAC8258), in: layer); d.oval(CGRect(x: -1, y: -1, width: 2, height: 2), d.cream, in: layer)
        case .cat, .penguin:
            d.oval(CGRect(x: -4, y: -1.5, width: 6, height: 3), style == .cat ? gold : d.color(0x7FA8BC), in: layer)
            let p = CGMutablePath(); p.addLines(between: [.init(x: 1, y: 0), .init(x: 4, y: 2), .init(x: 4, y: -2)]); p.closeSubpath(); d.shape(p, style == .cat ? gold : d.color(0x7FA8BC), in: layer)
            d.oval(CGRect(x: -3, y: 0, width: 0.5, height: 0.5), d.ink, in: layer)
        case .cloud: for x: CGFloat in [-2, 0, 2] { d.oval(CGRect(x: x - 2, y: x == 0 ? 0 : -1, width: 4, height: 4), x == 0 ? d.cream : d.blush, in: layer) }
        default: SidebarMascotArtwork.star(at: .zero, radius: 3.2, color: gold, in: layer)
        }
    }
}

final class CompanionLimb: CALayer {
    let forearm = CALayer(), grip = CALayer()
    override init() { super.init() }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }
    func configure(at point: CGPoint, color: NSColor, flipper: Bool) {
        position = point; forearm.name = "elbow"; grip.name = "grip"
        CompanionDrawing.plush(CGRect(x: -2.5, y: -6.5, width: 5, height: 8), color, in: self)
        forearm.position = CGPoint(x: 0, y: -5)
        CompanionDrawing.plush(CGRect(x: flipper ? -2.2 : -2.5, y: -5.5, width: flipper ? 4.4 : 5, height: 7.5), color, in: forearm)
        addSublayer(forearm); forearm.addSublayer(grip); grip.position = CGPoint(x: 0, y: -4.5)
    }
    func reach(_ target: CGPoint, outer: Bool) -> (Double, Double) {
        let a = 5.0, b = 4.5, dx = Double(target.x - position.x), dy = Double(target.y - position.y)
        let distance = min(a + b - 0.001, max(abs(a - b) + 0.001, hypot(dx, dy)))
        let offset = acos(min(1, max(-1, (distance * distance + a * a - b * b) / (2 * a * distance))))
        let shoulder = atan2(dy, dx) + (outer ? offset : -offset) + .pi / 2
        let elbow = atan2(dy + a * cos(shoulder), dx - a * sin(shoulder)) + .pi / 2 - shoulder
        return (atan2(sin(shoulder), cos(shoulder)), atan2(sin(elbow), cos(elbow)))
    }
}
