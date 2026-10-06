import AppKit
import QuartzCore

/// Original compact silhouettes, drawn as native vectors at every display scale.
enum SidebarMascotArtwork {
    private static let ink = NSColor(srgbRed: 0.25, green: 0.22, blue: 0.29, alpha: 1)
    private static let cream = NSColor(srgbRed: 1, green: 0.97, blue: 0.91, alpha: 1)
    private static let blush = NSColor(srgbRed: 0.98, green: 0.65, blue: 0.70, alpha: 1)
    static func make(style: SidebarAppearance, eyes: CALayer) -> CALayer {
        if [.panda, .bunny, .fox, .turtle, .ghost].contains(style) { return companion(style: style, eyes: eyes) }
        let scene = CALayer(); scene.bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        let fur: NSColor
        switch style {
        case .cat: fur = NSColor(srgbRed: 1, green: 0.76, blue: 0.48, alpha: 1)
        case .fox: fur = NSColor(srgbRed: 0.96, green: 0.60, blue: 0.39, alpha: 1)
        case .bear: fur = NSColor(srgbRed: 0.88, green: 0.68, blue: 0.48, alpha: 1)
        case .penguin: fur = NSColor(srgbRed: 0.48, green: 0.66, blue: 0.80, alpha: 1)
        case .cloud: fur = NSColor(srgbRed: 0.88, green: 0.88, blue: 1, alpha: 1)
        default: fur = cream
        }
        let dark = NSColor(srgbRed: 0.33, green: 0.34, blue: 0.40, alpha: 1)
        if style == .bunny {
            ellipse(8, 23, 7, 12, fur, in: scene)
            ellipse(22, 24, 7, 11, fur, in: scene)
            ellipse(10, 26, 3, 7, blush, in: scene)
            ellipse(24, 27, 3, 6, blush, in: scene)
        } else if [.bear, .panda].contains(style) {
            for x: CGFloat in [4, 24] {
                ellipse(x, 24, 8, 8, style == .panda ? dark : fur, in: scene)
                if style == .bear { ellipse(x + 2, 26, 4, 4, blush, in: scene) }
            }
        } else if [.cat, .fox].contains(style) {
            for x: CGFloat in [5, 23] {
                let ear = CGMutablePath(); ear.move(to: CGPoint(x: x, y: 23))
                ear.addQuadCurve(to: CGPoint(x: x + 1, y: 33), control: CGPoint(x: x - 1, y: 35))
                ear.addQuadCurve(to: CGPoint(x: x + 9, y: 25), control: CGPoint(x: x + 4, y: 34)); ear.closeSubpath()
                shape(ear, fur, in: scene)
                ellipse(x + 2, 26, 3, 4, blush, in: scene)
            }
        }
        if style == .cloud {
            for r in [CGRect(x: 3, y: 14, width: 14, height: 14), CGRect(x: 11, y: 20, width: 16, height: 13), CGRect(x: 23, y: 13, width: 11, height: 14)] {
                shape(CGPath(ellipseIn: r, transform: nil), fur, in: scene)
            }
        }
        // One generous, soft outline replaces the old stacked head/body shapes.
        let rect = CGRect(x: 4, y: 4, width: 28, height: style == .penguin ? 28 : 25)
        let body = CGPath(roundedRect: rect, cornerWidth: 13, cornerHeight: 13, transform: nil)
        let paint = CAGradientLayer(); paint.frame = scene.bounds
        paint.colors = [fur.blended(withFraction: 0.20, of: .white)!.cgColor, fur.cgColor]
        paint.startPoint = CGPoint(x: 0.3, y: 1); paint.endPoint = CGPoint(x: 0.7, y: 0)
        let mask = CAShapeLayer(); mask.path = body; paint.mask = mask; scene.addSublayer(paint)
        if [.fox, .penguin, .bear].contains(style) { ellipse(9, 7, 18, style == .penguin ? 21 : 12, cream, in: scene) }
        if style == .panda {
            for x: CGFloat in [8, 21] { ellipse(x, 17, 7, 8, dark, in: scene) }
        }
        if style == .cat {
            for x: CGFloat in [14, 18, 22] {
                let stripe = CGMutablePath(); stripe.move(to: CGPoint(x: x, y: 28)); stripe.addLine(to: CGPoint(x: x - 0.6, y: 25))
                line(stripe, fur.blended(withFraction: 0.3, of: ink)!, width: 1.3, in: scene)
            }
        }
        if ![SidebarAppearance.cloud, .ghost].contains(style) {
            for x: CGFloat in [9, 21] { ellipse(x, 3, 6, 4, style == .panda ? dark : fur, in: scene) }
        }
        if style == .ghost {
            for x: CGFloat in [5, 13, 21] { ellipse(x, 2, 10, 8, fur, in: scene) }
        }
        // Eye-local geometry makes blinking close the lids without moving the face.
        eyes.bounds = CGRect(x: 0, y: 0, width: 16, height: 5)
        eyes.position = CGPoint(x: 18, y: 21)
        for x: CGFloat in [1, 12] {
            ellipse(x, 0, 3, 5, style == .panda ? cream : ink, in: eyes)
            if style == .panda { ellipse(x + 0.65, 0.6, 1.7, 3.6, ink, in: eyes) }
            ellipse(x + 0.6, 3.2, 0.9, 1, .white, in: eyes)
        }
        scene.addSublayer(eyes)
        for x: CGFloat in [7, 25] { ellipse(x, 16, 4, 2.3, blush.withAlphaComponent(0.65), in: scene) }
        if style == .penguin {
            ellipse(16, 15, 4, 3, NSColor(srgbRed: 1, green: 0.73, blue: 0.39, alpha: 1), in: scene)
        } else {
            let smile = CGMutablePath(); smile.move(to: CGPoint(x: 16, y: 16.5))
            smile.addQuadCurve(to: CGPoint(x: 20, y: 16.5), control: CGPoint(x: 18, y: 13.5))
            line(smile, ink, width: 0.85, in: scene)
        }
        return scene
    }
    /// Large cheeks, a small body and asymmetric poses give each companion a personality.
    private static func companion(style: SidebarAppearance, eyes: CALayer) -> CALayer {
        let scene = CALayer(); scene.bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        let charcoal = NSColor(srgbRed: 0.25, green: 0.27, blue: 0.32, alpha: 1)
        let milk = NSColor(srgbRed: 1, green: 0.98, blue: 0.94, alpha: 1)
        let orange = NSColor(srgbRed: 0.97, green: 0.65, blue: 0.41, alpha: 1)
        let mint = NSColor(srgbRed: 0.73, green: 0.85, blue: 0.57, alpha: 1)
        var faceY: CGFloat = 20
        switch style {
        case .panda:
            ellipse(9, 2, 7, 6, charcoal, in: scene); ellipse(21, 2, 7, 6, charcoal, in: scene)
            soft(CGPath(ellipseIn: CGRect(x: 9, y: 4, width: 18, height: 15), transform: nil), milk, in: scene)
            ellipse(3, 23, 9, 9, charcoal, in: scene); ellipse(24, 23, 9, 9, charcoal, in: scene)
            ellipse(5.5, 25.5, 3, 3, blush.withAlphaComponent(0.6), in: scene)
            ellipse(27, 25.5, 3, 3, blush.withAlphaComponent(0.6), in: scene)
            soft(CGPath(ellipseIn: CGRect(x: 2, y: 11, width: 32, height: 20), transform: nil), milk, in: scene)
            // Angled eye patches, with small glossy eyes rather than white rings.
            for (x, angle) in [(CGFloat(7), CGFloat(-0.23)), (CGFloat(21), CGFloat(0.23))] {
                let patch = CALayer(); patch.bounds = CGRect(x: 0, y: 0, width: 8, height: 10)
                patch.position = CGPoint(x: x + 4, y: 21); patch.setAffineTransform(CGAffineTransform(rotationAngle: angle))
                ellipse(0, 0, 8, 10, charcoal, in: patch); scene.addSublayer(patch)
            }
            ellipse(16.4, 16.2, 3.2, 2, charcoal, in: scene)
            // Little hands hug a bamboo shoot below the cheeks.
            let bamboo = CGMutablePath(); bamboo.move(to: CGPoint(x: 13, y: 7)); bamboo.addLine(to: CGPoint(x: 25, y: 10))
            line(bamboo, NSColor(srgbRed: 0.49, green: 0.69, blue: 0.43, alpha: 1), width: 2.3, in: scene)
            ellipse(6, 7, 7, 5, charcoal, in: scene); ellipse(23, 7, 7, 5, charcoal, in: scene)
            ellipse(24, 10, 5, 2.5, mint, in: scene)
        case .bunny:
            ellipse(8, 1.5, 7, 4, milk, in: scene); ellipse(21, 1.5, 7, 4, milk, in: scene)
            soft(CGPath(ellipseIn: CGRect(x: 9, y: 3, width: 18, height: 14), transform: nil), milk, in: scene)
            ellipse(7, 23, 7, 12, milk, in: scene); ellipse(9, 26, 3, 7, blush.withAlphaComponent(0.75), in: scene)
            // One folded ear instead of two identical upright sticks.
            let ear = CGMutablePath(); ear.move(to: CGPoint(x: 23, y: 24))
            ear.addCurve(to: CGPoint(x: 28, y: 34), control1: CGPoint(x: 20, y: 32), control2: CGPoint(x: 24, y: 36))
            ear.addCurve(to: CGPoint(x: 33, y: 27), control1: CGPoint(x: 33, y: 34), control2: CGPoint(x: 35, y: 27))
            ear.addCurve(to: CGPoint(x: 27, y: 29), control1: CGPoint(x: 31, y: 23), control2: CGPoint(x: 28, y: 25))
            ear.addLine(to: CGPoint(x: 27, y: 23)); ear.closeSubpath(); soft(ear, milk, in: scene)
            ellipse(27, 28, 4, 3, blush.withAlphaComponent(0.75), in: scene)
            soft(CGPath(ellipseIn: CGRect(x: 2.5, y: 9, width: 31, height: 21), transform: nil), milk, in: scene)
            ellipse(6, 5, 6, 6, milk, in: scene); ellipse(24, 5, 6, 6, milk, in: scene)
            ellipse(16.7, 15.9, 2.6, 1.7, blush, in: scene)
        case .fox:
            // A sweeping cream-tipped tail is visible behind a tiny sitting body.
            let tail = CGMutablePath(); tail.move(to: CGPoint(x: 20, y: 4))
            tail.addCurve(to: CGPoint(x: 34, y: 17), control1: CGPoint(x: 34, y: 1), control2: CGPoint(x: 36, y: 9))
            tail.addCurve(to: CGPoint(x: 23, y: 11), control1: CGPoint(x: 30, y: 18), control2: CGPoint(x: 27, y: 13)); tail.closeSubpath()
            soft(tail, orange, in: scene); ellipse(29, 12, 5, 5, milk, in: scene)
            soft(CGPath(ellipseIn: CGRect(x: 9, y: 3, width: 17, height: 15), transform: nil), orange, in: scene)
            ellipse(12, 4, 11, 10, milk, in: scene)
            for x: CGFloat in [4, 23] {
                let ear = CGMutablePath(); ear.move(to: CGPoint(x: x, y: 24))
                ear.addQuadCurve(to: CGPoint(x: x + 1, y: 34), control: CGPoint(x: x - 2, y: 37))
                ear.addQuadCurve(to: CGPoint(x: x + 10, y: 26), control: CGPoint(x: x + 7, y: 34)); ear.closeSubpath()
                soft(ear, orange, in: scene); ellipse(x + 2, 27, 3, 5, charcoal, in: scene)
            }
            let head = CGMutablePath(); head.move(to: CGPoint(x: 2, y: 21))
            head.addCurve(to: CGPoint(x: 18, y: 30), control1: CGPoint(x: 5, y: 31), control2: CGPoint(x: 11, y: 31))
            head.addCurve(to: CGPoint(x: 34, y: 21), control1: CGPoint(x: 25, y: 31), control2: CGPoint(x: 31, y: 30))
            head.addQuadCurve(to: CGPoint(x: 30, y: 17), control: CGPoint(x: 36, y: 17))
            head.addQuadCurve(to: CGPoint(x: 18, y: 10), control: CGPoint(x: 29, y: 11))
            head.addQuadCurve(to: CGPoint(x: 6, y: 17), control: CGPoint(x: 7, y: 11))
            head.addQuadCurve(to: CGPoint(x: 2, y: 21), control: CGPoint(x: 0, y: 17)); head.closeSubpath(); soft(head, orange, in: scene)
            let muzzle = CGMutablePath(); muzzle.move(to: CGPoint(x: 3, y: 20))
            muzzle.addQuadCurve(to: CGPoint(x: 18, y: 16), control: CGPoint(x: 10, y: 23))
            muzzle.addQuadCurve(to: CGPoint(x: 33, y: 20), control: CGPoint(x: 26, y: 23))
            muzzle.addQuadCurve(to: CGPoint(x: 18, y: 10), control: CGPoint(x: 30, y: 10))
            muzzle.addQuadCurve(to: CGPoint(x: 3, y: 20), control: CGPoint(x: 6, y: 10)); muzzle.closeSubpath(); shape(muzzle, milk, in: scene)
            ellipse(16.5, 15.7, 3, 2.2, charcoal, in: scene)
            ellipse(10, 2, 6, 4, orange, in: scene); ellipse(20, 2, 6, 4, orange, in: scene)
            faceY = 22
        case .turtle:
            let shell = NSColor(srgbRed: 0.40, green: 0.64, blue: 0.49, alpha: 1)
            for x: CGFloat in [6, 24] { ellipse(x, 2, 6, 5, mint, in: scene) }
            soft(CGPath(ellipseIn: CGRect(x: 5, y: 3, width: 26, height: 21), transform: nil), shell, in: scene)
            let tile = CGMutablePath(); tile.addLines(between: [CGPoint(x: 18, y: 20), CGPoint(x: 23, y: 16), CGPoint(x: 23, y: 10), CGPoint(x: 18, y: 7), CGPoint(x: 13, y: 10), CGPoint(x: 13, y: 16)]); tile.closeSubpath()
            shape(tile, shell.blended(withFraction: 0.25, of: mint)!, in: scene)
            ellipse(3, 9, 7, 5, mint, in: scene); ellipse(26, 9, 7, 5, mint, in: scene)
            soft(CGPath(ellipseIn: CGRect(x: 4, y: 14, width: 28, height: 19), transform: nil), mint, in: scene)
            ellipse(13, 28, 10, 3, mint.blended(withFraction: 0.35, of: milk)!, in: scene)
            faceY = 24
        case .ghost:
            let lavender = NSColor(srgbRed: 0.93, green: 0.90, blue: 0.99, alpha: 1)
            let body = CGMutablePath(); body.move(to: CGPoint(x: 5, y: 8))
            body.addCurve(to: CGPoint(x: 18, y: 32), control1: CGPoint(x: 2, y: 29), control2: CGPoint(x: 9, y: 33))
            body.addCurve(to: CGPoint(x: 31, y: 10), control1: CGPoint(x: 29, y: 33), control2: CGPoint(x: 32, y: 24))
            body.addQuadCurve(to: CGPoint(x: 33, y: 4), control: CGPoint(x: 32, y: 5))
            body.addQuadCurve(to: CGPoint(x: 24, y: 7), control: CGPoint(x: 29, y: 2))
            body.addQuadCurve(to: CGPoint(x: 16, y: 4), control: CGPoint(x: 22, y: 1))
            body.addQuadCurve(to: CGPoint(x: 9, y: 6), control: CGPoint(x: 12, y: 8))
            body.addQuadCurve(to: CGPoint(x: 5, y: 8), control: CGPoint(x: 4, y: 2)); body.closeSubpath(); soft(body, lavender, in: scene)
            ellipse(1.5, 12, 7, 5, lavender, in: scene); ellipse(28, 15, 6, 5, lavender, in: scene)
            ellipse(9, 25, 6, 3, milk.withAlphaComponent(0.65), in: scene)
            faceY = 21
        default: break
        }
        eyes.bounds = CGRect(x: 0, y: 0, width: 18, height: 5)
        eyes.position = CGPoint(x: 18, y: faceY)
        for x: CGFloat in [1, 13] {
            ellipse(x, 0, 3.6, 4.8, style == .panda ? .black : ink, in: eyes)
            ellipse(x + 0.5, 3, 1.3, 1.3, milk, in: eyes)
            ellipse(x + 2, 0.8, 0.65, 0.65, milk.withAlphaComponent(0.8), in: eyes)
        }
        scene.addSublayer(eyes)
        for x: CGFloat in [5.5, 26] { ellipse(x, faceY - 5.3, 4.5, 2.4, blush.withAlphaComponent(0.75), in: scene) }
        let mouth = CGMutablePath(); mouth.move(to: CGPoint(x: 15.5, y: faceY - 5))
        mouth.addQuadCurve(to: CGPoint(x: 18, y: faceY - 6), control: CGPoint(x: 16.5, y: faceY - 7))
        mouth.addQuadCurve(to: CGPoint(x: 20.5, y: faceY - 5), control: CGPoint(x: 19.5, y: faceY - 7))
        line(mouth, ink, width: 0.65, in: scene)
        return scene
    }
    private static func soft(_ path: CGPath, _ color: NSColor, in scene: CALayer) {
        let paint = CAGradientLayer(); paint.frame = scene.bounds
        paint.colors = [color.blended(withFraction: 0.15, of: .white)!.cgColor, color.cgColor]
        paint.startPoint = CGPoint(x: 0.3, y: 1); paint.endPoint = CGPoint(x: 0.65, y: 0)
        let mask = CAShapeLayer(); mask.path = path; paint.mask = mask; scene.addSublayer(paint)
        let edge = CAShapeLayer(); edge.path = path; edge.fillColor = nil
        edge.strokeColor = color.blended(withFraction: 0.16, of: ink)!.withAlphaComponent(0.5).cgColor
        edge.lineWidth = 0.35; scene.addSublayer(edge)
    }
    private static func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor, in scene: CALayer) {
        shape(CGPath(ellipseIn: CGRect(x: x, y: y, width: w, height: h), transform: nil), color, in: scene)
    }
    private static func shape(_ path: CGPath, _ color: NSColor, in scene: CALayer) {
        let layer = CAShapeLayer(); layer.path = path; layer.fillColor = color.cgColor; scene.addSublayer(layer)
    }
    private static func line(_ path: CGPath, _ color: NSColor, width: CGFloat, in scene: CALayer) {
        let layer = CAShapeLayer(); layer.path = path; layer.fillColor = nil; layer.strokeColor = color.cgColor
        layer.lineWidth = width; layer.lineCap = .round; scene.addSublayer(layer)
    }
}

extension SidebarAppearance {
    /// Cache tiny raster thumbnails, not live character scenes.
    var menuIcon: NSImage? { Self.menuIcons[self] }
    private static let menuIcons: [Self: NSImage] = {
        var icons: [Self: NSImage] = [:]
        for style in selectable {
            guard let context = CGContext(data: nil, width: 48, height: 48, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            let emblem = SidebarEmblem(); emblem.configure(style); emblem.update(remaining: 75, scale: 2)
            context.scaleBy(x: 48 / 36.0, y: 48 / 36.0); emblem.render(in: context)
            if let image = context.makeImage() { icons[style] = NSImage(cgImage: image, size: NSSize(width: 24, height: 24)) }
        }
        return icons
    }()
}
