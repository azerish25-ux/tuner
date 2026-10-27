import UIKit

/// Two investigated callback identities only. This is a fail-closed raster check, not a static exemption.
/// Unknown text, missing ink, unexpected paint, clipped bounds or an unsupported image stay audit failures.
enum AuditContrastPixelProof {
    struct Proof {
        let ratio: Double
        let foregroundPixels: Int
        let backgroundPixels: Int
        let totalPixels: Int
        var summary: String {
            "callback pixels: contrast=\(ratio), ink=\(foregroundPixels), backing=\(backgroundPixels), total=\(totalPixels)"
        }
    }

    static func verify(screen: String, identifier: String, label: String, frame: CGRect, viewport: CGRect, image: UIImage) -> Proof? {
        let ink: [Int]
        let backing: [Int]
        switch (screen, identifier, label) {
        case ("settings", "settings.notation.title", "Note names"):
            ink = [245, 243, 239]; backing = [17, 19, 23]
        case ("paywall", "paywall.plan.yearly.saving", "SAVE 58%"):
            ink = [27, 18, 6]; backing = [255, 208, 138]
        default: return nil
        }
        guard image.imageOrientation == .up, let source = image.cgImage,
              [viewport.minX, viewport.minY, viewport.width, viewport.height,
               frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite),
              viewport.origin == .zero, viewport.width > 0, viewport.height > 0,
              frame.width >= 40, frame.height >= 12,
              viewport.contains(frame) else { return nil }
        // XCUIScreenshot may expose a UIImage with scale=1 even on a3x device.
        // Map from the verified pre-audit app viewport, never from UIImage point metadata.
        let scaleX = CGFloat(source.width) / viewport.width
        let scaleY = CGFloat(source.height) / viewport.height
        guard abs(scaleX - scaleY) < 0.01, scaleX >= 1 else { return nil }
        let rect = CGRect(x: (frame.minX * scaleX).rounded(), y: (frame.minY * scaleY).rounded(),
                          width: (frame.width * scaleX).rounded(), height: (frame.height * scaleY).rounded())
        guard let crop = source.cropping(to: rect), crop.width > 0, crop.height > 0,
              crop.width == Int(rect.width), crop.height == Int(rect.height),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var rgba = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: crop.width, height: crop.height,
                bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: CGFloat(crop.width), height: CGFloat(crop.height)))
            return true
        }
        guard drawn else { return nil }
        return inspect(rgba, width: crop.width, height: crop.height, ink: ink, backing: backing)
    }

    private static func inspect(_ pixels: [UInt8], width: Int, height: Int, ink: [Int], backing: [Int]) -> Proof? {
        let total = width * height
        var foreground = 0, background = 0, interpolated = 0
        var inkColumns = Set<Int>(), inkRows = Set<Int>()
        var inkMask = Set<Int>()
        var foregroundLuminances: [Double] = [], backgroundLuminances: [Double] = []
        let dominant = (0..<3).max { abs(ink[$0] - backing[$0]) < abs(ink[$1] - backing[$1]) } ?? 0
        let denominator = Double(ink[dominant] - backing[dominant])
        guard denominator != 0 else { return nil }
        for pixel in 0..<total {
            let offset = pixel * 4
            guard pixels[offset + 3] == 255 else { return nil }
            let rgb = (0..<3).map { Int(pixels[offset + $0]) }
            if (0..<3).allSatisfy({ abs(rgb[$0] - ink[$0]) <= 3 }) {
                foreground += 1; inkColumns.insert(pixel % width); inkRows.insert(pixel / width); inkMask.insert(pixel)
                foregroundLuminances.append(luminance(rgb))
            }
            if (0..<3).allSatisfy({ abs(rgb[$0] - backing[$0]) <= 3 }) {
                background += 1; backgroundLuminances.append(luminance(rgb))
            }
            let blend = min(1, max(0, Double(rgb[dominant] - backing[dominant]) / denominator))
            if (0..<3).allSatisfy({ abs(Double(rgb[$0]) - (Double(backing[$0]) + blend * Double(ink[$0] - backing[$0]))) <= 12 }) {
                interpolated += 1
            }
        }
        // Actual letter strokes must span the target, not a few matching pixels in an unrelated region.
        guard Double(foreground) / Double(total) >= 0.05,
              Double(foreground) / Double(total) <= 0.40,
              Double(background) / Double(total) >= 0.45,
              Double(interpolated) / Double(total) >= 0.95,
              Double(inkColumns.count) / Double(width) >= 0.35,
              Double(inkRows.count) / Double(height) >= 0.35,
              let fgMin = foregroundLuminances.min(), let fgMax = foregroundLuminances.max(),
              let bgMin = backgroundLuminances.min(), let bgMax = backgroundLuminances.max() else { return nil }
        var components = 0
        while let seed = inkMask.first {
            var pending = [seed], count = 0
            inkMask.remove(seed)
            while let pixel = pending.popLast() {
                count += 1
                let x = pixel % width, y = pixel / width
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = x + dx, ny = y + dy
                        guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                        let neighbor = ny * width + nx
                        if inkMask.remove(neighbor) != nil { pending.append(neighbor) }
                    }
                }
            }
            if count >= max(2, total / 5000) { components += 1 }
        }
        guard (6...30).contains(components) else { return nil }
        let ratio: Double
        if fgMin > bgMax { ratio = (fgMin + 0.05) / (bgMax + 0.05) }
        else if bgMin > fgMax { ratio = (bgMin + 0.05) / (fgMax + 0.05) }
        else { return nil }
        guard ratio >= 4.5 else { return nil }
        return Proof(ratio: ratio, foregroundPixels: foreground, backgroundPixels: background, totalPixels: total)
    }

    private static func luminance(_ rgb: [Int]) -> Double {
        let linear = rgb.map { component -> Double in
            let value = Double(component) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return zip(linear, [0.2126, 0.7152, 0.0722]).reduce(0) { $0 + $1.0 * $1.1 }
    }
}
