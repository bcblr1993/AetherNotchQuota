import AppKit
import ImageIO
import QuartzCore

/// Production storybook illustrations, decoded once at the largest size the UI needs.
/// The cache is shared by the floating pet, reminder cameo and menu thumbnails.
enum SidebarMascotArtwork {
    static let maximumPixelSize = 256
    private static let images: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.countLimit = SidebarAppearance.selectable.count
        cache.totalCostLimit = SidebarAppearance.selectable.count * maximumPixelSize * maximumPixelSize * 4
        return cache
    }()
    static func image(for style: SidebarAppearance) -> CGImage? {
        let key = style.rawValue as NSString
        if let image = images.object(forKey: key) { return image }
        guard let url = ResourceLocator.icon("storybook-" + style.rawValue),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        images.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
    static func make(style: SidebarAppearance) -> CALayer {
        let scene = CALayer(); scene.bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        scene.contents = image(for: style)
        scene.contentsGravity = .resizeAspect
        scene.minificationFilter = .trilinear; scene.magnificationFilter = .linear
        return scene
    }
    static func star(at center: CGPoint, radius: CGFloat, color: NSColor, in scene: CALayer) {
        let path = CGMutablePath()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let r = index.isMultiple(of: 2) ? radius : radius * 0.35
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        let layer = CAShapeLayer(); layer.path = path; layer.fillColor = color.cgColor; scene.addSublayer(layer)
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
