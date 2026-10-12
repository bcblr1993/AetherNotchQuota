import AppKit
import ImageIO
import UniformTypeIdentifiers

// Asset packing only: extract connected full-body poses without redrawing them.
// AI atlas spacing is not exact. Fixed grid crops can include a neighbour's foot.
guard CommandLine.arguments.count == 3 else { fatalError("usage: swift compile-soft-panda.swift source.png output.png") }
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let bitmap = NSBitmapImageRep(data: try Data(contentsOf: input)),
      bitmap.samplesPerPixel == 4, bitmap.bitsPerSample == 8,
      !bitmap.bitmapFormat.contains(.alphaFirst), let pixels = bitmap.bitmapData else { fatalError("RGBA8 required") }
let width = bitmap.pixelsWide, height = bitmap.pixelsHigh, stride = bitmap.bytesPerRow
var visited = [Bool](repeating: false, count: width * height)
struct Component { let indices: [Int]; let x: Int; let y: Int; let maxX: Int; let maxY: Int }
var components: [Component] = []
for index in 0..<visited.count where !visited[index] {
    visited[index] = true
    guard pixels[index / width * stride + index % width * 4 + 3] > 32 else { continue }
    var queue = [index], cursor = 0, x0 = index % width, y0 = index / width, x1 = x0, y1 = y0
    while cursor < queue.count {
        let n = queue[cursor]; cursor += 1
        let x = n % width, y = n / width
        x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        for (nx, ny) in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)] where nx >= 0 && ny >= 0 && nx < width && ny < height {
            let next = ny * width + nx
            if !visited[next] {
                visited[next] = true
                if pixels[ny * stride + nx * 4 + 3] > 32 { queue.append(next) }
            }
        }
    }
    if queue.count > 10_000 { components.append(Component(indices: queue, x: x0, y: y0, maxX: x1, maxY: y1)) }
}
guard components.count == 16 else { fatalError("Expected 16 complete poses, got \(components.count)") }
components.sort { $0.y < $1.y }
let ordered = (0..<4).flatMap { Array(components[($0*4)..<($0*4+4)]).sorted { $0.x < $1.x } }
let scale = 218.0 / Double(ordered.map { max($0.maxX - $0.x, $0.maxY - $0.y) + 1 }.max()!)
let atlas = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
atlas.interpolationQuality = .high
for (index, component) in ordered.enumerated() {
    let x0 = max(0, component.x - 2), y0 = max(0, component.y - 2)
    let w = min(width - 1, component.maxX + 2) - x0 + 1, h = min(height - 1, component.maxY + 2) - y0 + 1
    let crop = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bitmapFormat: bitmap.bitmapFormat, bytesPerRow: w * 4, bitsPerPixel: 32)!
    memset(crop.bitmapData!, 0, w * h * 4)
    var included = Set(component.indices)
    // Keep one pixel of antialias fringe around this component only.
    for n in component.indices {
        let x = n % width, y = n / width
        for (nx, ny) in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)] where nx >= x0 && ny >= y0 && nx < x0+w && ny < y0+h {
            included.insert(ny * width + nx)
        }
    }
    for n in included {
        let x = n % width, y = n / width
        guard x >= x0 && y >= y0 && x < x0+w && y < y0+h else { continue }
        memcpy(crop.bitmapData! + (y-y0)*w*4 + (x-x0)*4, pixels + y*stride + x*4, 4)
    }
    // Dark paw pixels near the floor establish a stable body anchor independently
    // of a cup moving outside the silhouette. Use one scale for the entire clip.
    let paw = component.indices.filter { n in
        let y = n / width, p = y * stride + n % width * 4
        return y > component.maxY - 42 && pixels[p] < 105 && pixels[p+1] < 100 && pixels[p+2] < 100
    }
    guard !paw.isEmpty else { fatalError("Missing ground anchor in frame \(index)") }
    let anchorX = Double(paw.map { $0 % width }.min()! + paw.map { $0 % width }.max()!) / 2
    let x = Double(index % 4 * 256) + 119 - (anchorX - Double(x0)) * scale
    let y = Double((3-index/4) * 256) + 17 - Double(y0 + h - 1 - component.maxY) * scale
    atlas.draw(crop.cgImage!, in: CGRect(x: x, y: y, width: Double(w)*scale, height: Double(h)*scale))
    print("frame \(index): source=(\(x0),\(y0),\(w),\(h)) anchor=\(anchorX),\(component.maxY) scale=\(scale)")
}
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, atlas.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write atlas") }
