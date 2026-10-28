import CryptoKit
import UIKit

/// Two independently reviewed native states, not a palette-only or identifier-only exception.
/// Any changed pixel, pose, scale, identity or capture-time snapshot leaves the issue enforced.
enum ReviewedPracticeLevelRaster {
    struct Reference {
        let identifier: String
        let name: String
        let pngSHA256: String
        let frame: CGRect
        let crop: CGRect
    }

    static let references = [
        Reference(identifier: "screen.header.level.mark", name: "practice-header-lv1-31bcd",
                  pngSHA256: "5d88e8ca39a114bafe811dd4a92748192f1905d8d4b727ff25d08da966fb3984",
                  frame: CGRect(x: 349.1666666666667, y: 85.83333333333334,
                                width: 21.666666666666686, height: 20.33333333333333),
                  crop: CGRect(x: 1047, y: 257, width: 66, height: 62)),
        Reference(identifier: "practice.level.card.mark", name: "practice-card-lv1-31bcd",
                  pngSHA256: "1b5858628680c4ac5e6bec8760e496420b85ba2beb2a89f968c6fae996263d03",
                  frame: CGRect(x: 52.66666666666667, y: 392.66666666666663,
                                width: 32.66666666666667, height: 28),
                  crop: CGRect(x: 158, y: 1178, width: 98, height: 84))
    ]

    static func supports(screen: String, identifier: String, label: String) -> Bool {
        screen == "tab-4-practice" && label == "LV 1" && references.contains { $0.identifier == identifier }
    }

    static func verify(screen: String, identifier: String, label: String, frame: CGRect,
                       viewport: CGRect, image: UIImage, staticText: Bool, stable: Bool) -> String? {
        guard staticText, stable, supports(screen: screen, identifier: identifier, label: label),
              let reference = references.first(where: { $0.identifier == identifier }), frame == reference.frame,
              viewport == CGRect(x: 0, y: 0, width: 402, height: 874), viewport.contains(frame),
              image.imageOrientation == .up, let source = image.cgImage,
              source.width == 1206, source.height == 2622,
              let expected = load(reference), let actual = source.cropping(to: reference.crop),
              actual.width == expected.width, actual.height == expected.height,
              let expectedPixels = rgba(expected), let actualPixels = rgba(actual),
              actualPixels == expectedPixels else { return nil }
        return "exact reviewed native Practice LV1 pixels (\(reference.name)); intended paint minimum 5.0:1; callback state, not SDK internal raster"
    }

    static func load(_ reference: Reference) -> CGImage? {
        guard let url = Bundle(for: ResourceAnchor.self).url(forResource: reference.name, withExtension: "png"),
              let data = try? Data(contentsOf: url),
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == reference.pngSHA256,
              let image = UIImage(data: data), image.imageOrientation == .up,
              let cg = image.cgImage, cg.width == Int(reference.crop.width), cg.height == Int(reference.crop.height) else { return nil }
        return cg
    }

    private static func rgba(_ image: CGImage) -> Data? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var pixels = Data(count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? pixels : nil
    }

    private final class ResourceAnchor: NSObject {}
}
