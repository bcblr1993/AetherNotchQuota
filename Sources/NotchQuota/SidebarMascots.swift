import AppKit
import QuartzCore

/// Small static vector scenes. No image downloads, display links, filters or idle timers.
enum SidebarMascotArtwork {
    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    private static let ink = color(0.28, 0.23, 0.29)
    private static let cream = color(1, 0.97, 0.90)
    private static let pink = color(0.96, 0.63, 0.69)

    static func make(style: SidebarAppearance, eyes: CALayer) -> CALayer {
        let scene = CALayer(); scene.bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        switch style {
        case .bunny:
            // Uneven ears and a generous head make the silhouette readable even in the menu.
            let left = CGMutablePath(); left.move(to: CGPoint(x: 9, y: 23))
            left.addCurve(to: CGPoint(x: 9, y: 34), control1: CGPoint(x: 4, y: 33), control2: CGPoint(x: 6, y: 36))
            left.addCurve(to: CGPoint(x: 15, y: 23), control1: CGPoint(x: 13, y: 35), control2: CGPoint(x: 15, y: 28)); left.closeSubpath()
            let right = CGMutablePath(); right.move(to: CGPoint(x: 22, y: 24))
            right.addCurve(to: CGPoint(x: 27, y: 35), control1: CGPoint(x: 22, y: 31), control2: CGPoint(x: 24, y: 36))
            right.addCurve(to: CGPoint(x: 28, y: 23), control1: CGPoint(x: 32, y: 35), control2: CGPoint(x: 31, y: 28)); right.closeSubpath()
            for path in [left, right] { gradient(path, [cream, color(0.95, 0.86, 0.84)], in: scene) }
            oval(CGRect(x: 9, y: 26, width: 2.4, height: 7), pink, in: scene)
            oval(CGRect(x: 25.8, y: 27, width: 2.4, height: 6), pink, in: scene)
            gradient(CGPath(roundedRect: CGRect(x: 8, y: 3, width: 21, height: 21), cornerWidth: 10, cornerHeight: 10, transform: nil),
                     [cream, color(0.96, 0.86, 0.87)], in: scene)
            gradient(CGPath(ellipseIn: CGRect(x: 3, y: 10, width: 30, height: 20), transform: nil),
                     [color(1, 0.99, 0.95), color(0.98, 0.90, 0.87)], in: scene)
            oval(CGRect(x: 8, y: 2.5, width: 8, height: 4), cream, in: scene)
            oval(CGRect(x: 21, y: 2.5, width: 8, height: 4), cream, in: scene)
            face(eyes, at: 21, in: scene)
            oval(CGRect(x: 16.9, y: 16.5, width: 2.4, height: 1.7), pink, in: scene)
            smile(at: CGPoint(x: 18, y: 16.3), in: scene)
        case .bear:
            let honey = color(0.96, 0.72, 0.45)
            for x: CGFloat in [3, 25] {
                gradient(CGPath(ellipseIn: CGRect(x: x, y: 24, width: 9, height: 10), transform: nil), [cream, honey], in: scene)
                oval(CGRect(x: x + 2, y: 26, width: 5, height: 5), color(0.83, 0.51, 0.38), in: scene)
            }
            gradient(CGPath(roundedRect: CGRect(x: 5, y: 3, width: 26, height: 27), cornerWidth: 12, cornerHeight: 12, transform: nil),
                     [color(1, 0.88, 0.63), honey, color(0.85, 0.58, 0.36)], in: scene)
            oval(CGRect(x: 11, y: 12, width: 14, height: 9), cream, in: scene)
            face(eyes, at: 23, in: scene)
            oval(CGRect(x: 16.2, y: 17.8, width: 3.6, height: 2.4), ink, in: scene)
            smile(at: CGPoint(x: 18, y: 16.4), in: scene)
            oval(CGRect(x: 8, y: 2, width: 7, height: 4), honey, in: scene)
            oval(CGRect(x: 22, y: 2, width: 7, height: 4), honey, in: scene)
            // A tiny honey drop replaces a badge or quota indicator on the character itself.
            let drop = CGMutablePath(); drop.move(to: CGPoint(x: 27, y: 12))
            drop.addCurve(to: CGPoint(x: 27, y: 6), control1: CGPoint(x: 22, y: 6), control2: CGPoint(x: 24, y: 5))
            drop.addCurve(to: CGPoint(x: 27, y: 12), control1: CGPoint(x: 31, y: 6), control2: CGPoint(x: 30, y: 8)); drop.closeSubpath()
            shape(drop, color(1, 0.88, 0.52), in: scene)
        case .cloud:
            let p = CGMutablePath(); p.move(to: CGPoint(x: 7, y: 8))
            p.addCurve(to: CGPoint(x: 3, y: 21), control1: CGPoint(x: -1, y: 9), control2: CGPoint(x: -1, y: 18))
            p.addCurve(to: CGPoint(x: 12, y: 28), control1: CGPoint(x: 2, y: 28), control2: CGPoint(x: 7, y: 31))
            p.addCurve(to: CGPoint(x: 25, y: 28), control1: CGPoint(x: 15, y: 35), control2: CGPoint(x: 23, y: 34))
            p.addCurve(to: CGPoint(x: 33, y: 18), control1: CGPoint(x: 33, y: 30), control2: CGPoint(x: 36, y: 23))
            p.addCurve(to: CGPoint(x: 29, y: 8), control1: CGPoint(x: 39, y: 10), control2: CGPoint(x: 34, y: 6))
            p.addCurve(to: CGPoint(x: 18, y: 6), control1: CGPoint(x: 27, y: 2), control2: CGPoint(x: 21, y: 2))
            p.addCurve(to: CGPoint(x: 7, y: 8), control1: CGPoint(x: 13, y: 2), control2: CGPoint(x: 8, y: 3)); p.closeSubpath()
            gradient(p, [color(1, 0.98, 1), color(0.87, 0.86, 0.98), color(0.73, 0.80, 0.95)], in: scene)
            face(eyes, at: 21, in: scene)
            smile(at: CGPoint(x: 18, y: 17), in: scene)
            let star = CGMutablePath()
            star.move(to: CGPoint(x: 28, y: 34)); star.addQuadCurve(to: CGPoint(x: 32, y: 29), control: CGPoint(x: 28, y: 30))
            star.addQuadCurve(to: CGPoint(x: 28, y: 24), control: CGPoint(x: 28, y: 28))
            star.addQuadCurve(to: CGPoint(x: 24, y: 29), control: CGPoint(x: 28, y: 28))
            star.addQuadCurve(to: CGPoint(x: 28, y: 34), control: CGPoint(x: 28, y: 30)); star.closeSubpath()
            gradient(star, [cream, color(1, 0.80, 0.46)], in: scene)
        case .cat:
            let orange = color(0.98, 0.69, 0.39)
            let tail = CGMutablePath(); tail.move(to: CGPoint(x: 27, y: 5))
            tail.addCurve(to: CGPoint(x: 31, y: 15), control1: CGPoint(x: 38, y: 2), control2: CGPoint(x: 35, y: 13))
            stroke(tail, orange, width: 4, in: scene)
            gradient(CGPath(roundedRect: CGRect(x: 8, y: 3, width: 21, height: 23), cornerWidth: 9, cornerHeight: 9, transform: nil), [cream, orange], in: scene)
            for points in [[CGPoint(x: 5, y: 24), CGPoint(x: 5, y: 35), CGPoint(x: 16, y: 29)],
                           [CGPoint(x: 21, y: 29), CGPoint(x: 30, y: 35), CGPoint(x: 32, y: 23)]] {
                shape(polygon(points), orange, in: scene)
            }
            gradient(CGPath(ellipseIn: CGRect(x: 3, y: 12, width: 30, height: 20), transform: nil), [color(1, 0.87, 0.62), orange], in: scene)
            shape(polygon([CGPoint(x: 7, y: 29), CGPoint(x: 7, y: 32), CGPoint(x: 11, y: 29)]), pink, in: scene)
            shape(polygon([CGPoint(x: 26, y: 29), CGPoint(x: 29, y: 32), CGPoint(x: 29, y: 28)]), pink, in: scene)
            for x: CGFloat in [15, 19, 23] {
                let stripe = CGMutablePath(); stripe.move(to: CGPoint(x: x, y: 30)); stripe.addLine(to: CGPoint(x: x - 1, y: 27))
                stroke(stripe, color(0.82, 0.43, 0.25), width: 1.2, in: scene)
            }
            oval(CGRect(x: 11, y: 13, width: 14, height: 6), cream, in: scene)
            face(eyes, at: 22, in: scene)
            shape(polygon([CGPoint(x: 16.5, y: 18), CGPoint(x: 19.5, y: 18), CGPoint(x: 18, y: 16)]), pink, in: scene)
            smile(at: CGPoint(x: 18, y: 15.7), in: scene)
            for x: CGFloat in [5, 27] {
                let whisker = CGMutablePath(); whisker.move(to: CGPoint(x: x, y: 17)); whisker.addLine(to: CGPoint(x: x + 4, y: 16.5))
                stroke(whisker, color(0.68, 0.40, 0.30), width: 0.6, in: scene)
            }
        case .fox:
            let rust = color(0.85, 0.39, 0.24)
            // Sharper ears and cheek tufts distinguish the fox from the soft round animals.
            shape(polygon([CGPoint(x: 8, y: 6), CGPoint(x: 1, y: 13), CGPoint(x: 5, y: 23),
                           CGPoint(x: 4, y: 35), CGPoint(x: 16, y: 29), CGPoint(x: 23, y: 29),
                           CGPoint(x: 32, y: 35), CGPoint(x: 31, y: 23), CGPoint(x: 35, y: 13), CGPoint(x: 27, y: 6)]), rust, in: scene)
            shape(polygon([CGPoint(x: 6, y: 31), CGPoint(x: 8, y: 24), CGPoint(x: 13, y: 27)]), ink, in: scene)
            shape(polygon([CGPoint(x: 29, y: 31), CGPoint(x: 24, y: 27), CGPoint(x: 29, y: 24)]), ink, in: scene)
            shape(polygon([CGPoint(x: 5, y: 19), CGPoint(x: 17, y: 15), CGPoint(x: 30, y: 19),
                           CGPoint(x: 26, y: 8), CGPoint(x: 18, y: 3), CGPoint(x: 9, y: 8)]), cream, in: scene)
            face(eyes, at: 23, in: scene)
            oval(CGRect(x: 16, y: 14, width: 4, height: 2.5), ink, in: scene)
            smile(at: CGPoint(x: 18, y: 12.8), in: scene)
        case .panda:
            let charcoal = color(0.24, 0.27, 0.31)
            for x: CGFloat in [3, 25] { oval(CGRect(x: x, y: 26, width: 9, height: 9), charcoal, in: scene) }
            oval(CGRect(x: 8, y: 2, width: 8, height: 6), charcoal, in: scene)
            oval(CGRect(x: 22, y: 2, width: 8, height: 6), charcoal, in: scene)
            gradient(CGPath(roundedRect: CGRect(x: 7, y: 4, width: 23, height: 24), cornerWidth: 10, cornerHeight: 10, transform: nil), [cream, color(0.86, 0.90, 0.87)], in: scene)
            gradient(CGPath(ellipseIn: CGRect(x: 3, y: 11, width: 30, height: 22), transform: nil), [color(1, 1, 0.97), color(0.90, 0.93, 0.91)], in: scene)
            for x: CGFloat in [8, 20] { oval(CGRect(x: x, y: 18, width: 8, height: 9), charcoal, in: scene) }
            face(eyes, at: 23, in: scene)
            oval(CGRect(x: 16.4, y: 16, width: 3.2, height: 2.3), charcoal, in: scene)
            smile(at: CGPoint(x: 18, y: 14.6), in: scene)
            // Small mint leaf, kept behind the face, gives the monochrome character an accent.
            shape(polygon([CGPoint(x: 27, y: 8), CGPoint(x: 34, y: 13), CGPoint(x: 32, y: 5)]), color(0.47, 0.72, 0.55), in: scene)
        case .penguin:
            let blue = color(0.34, 0.49, 0.66)
            oval(CGRect(x: 4, y: 9, width: 8, height: 16), blue, in: scene)
            oval(CGRect(x: 25, y: 9, width: 8, height: 16), blue, in: scene)
            gradient(CGPath(roundedRect: CGRect(x: 6, y: 4, width: 25, height: 29), cornerWidth: 12, cornerHeight: 12, transform: nil), [color(0.65, 0.79, 0.89), blue], in: scene)
            oval(CGRect(x: 10, y: 6, width: 17, height: 22), cream, in: scene)
            face(eyes, at: 23, in: scene)
            shape(polygon([CGPoint(x: 15, y: 18), CGPoint(x: 21, y: 18), CGPoint(x: 18, y: 14)]), color(1, 0.72, 0.35), in: scene)
            for x: CGFloat in [9, 22] { oval(CGRect(x: x, y: 2, width: 7, height: 4), color(1, 0.72, 0.35), in: scene) }
        default: break
        }
        return scene
    }

    private static func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath(); path.addLines(between: points); path.closeSubpath(); return path
    }
    private static func stroke(_ path: CGPath, _ color: NSColor, width: CGFloat, in scene: CALayer) {
        let layer = CAShapeLayer(); layer.path = path; layer.fillColor = nil
        layer.strokeColor = color.cgColor; layer.lineWidth = width; layer.lineCap = .round; scene.addSublayer(layer)
    }
    private static func face(_ eyes: CALayer, at y: CGFloat, in scene: CALayer) {
        eyes.frame = scene.bounds
        for x: CGFloat in [11.5, 22] {
            oval(CGRect(x: x, y: y - 2.5, width: 3, height: 4.6), ink, in: eyes)
            oval(CGRect(x: x + 0.7, y: y + 0.2, width: 0.8, height: 1), cream, in: eyes)
        }
        scene.addSublayer(eyes)
        for x: CGFloat in [6.5, 25.5] { oval(CGRect(x: x, y: y - 6, width: 4.5, height: 2.2), color(0.95, 0.59, 0.65, 0.65), in: scene) }
    }
    private static func smile(at point: CGPoint, in scene: CALayer) {
        let p = CGMutablePath(); p.move(to: CGPoint(x: point.x - 2, y: point.y))
        p.addQuadCurve(to: CGPoint(x: point.x + 2, y: point.y), control: CGPoint(x: point.x, y: point.y - 2.7))
        let layer = CAShapeLayer(); layer.path = p; layer.fillColor = nil; layer.strokeColor = ink.cgColor
        layer.lineWidth = 0.7; layer.lineCap = .round; scene.addSublayer(layer)
    }
    private static func oval(_ rect: CGRect, _ color: NSColor, in scene: CALayer) {
        shape(CGPath(ellipseIn: rect, transform: nil), color, in: scene)
    }
    private static func shape(_ path: CGPath, _ color: NSColor, in scene: CALayer) {
        let layer = CAShapeLayer(); layer.path = path; layer.fillColor = color.cgColor; scene.addSublayer(layer)
    }
    private static func gradient(_ path: CGPath, _ colors: [NSColor], in scene: CALayer) {
        let layer = CAGradientLayer(); layer.frame = scene.bounds; layer.colors = colors.map(\.cgColor)
        layer.startPoint = CGPoint(x: 0.2, y: 1); layer.endPoint = CGPoint(x: 0.8, y: 0)
        let mask = CAShapeLayer(); mask.path = path; layer.mask = mask; scene.addSublayer(layer)
        let rim = CAShapeLayer(); rim.path = path; rim.fillColor = nil
        rim.strokeColor = NSColor(white: 1, alpha: 0.3).cgColor; rim.lineWidth = 0.5; scene.addSublayer(rim)
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
