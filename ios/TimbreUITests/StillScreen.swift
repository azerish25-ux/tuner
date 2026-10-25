import CoreGraphics
import UIKit
import XCTest

/// Captures that wait for the screen to come to rest: entrances, staggers and transitions finish before the picture
/// is taken, instead of a fixed sleep that is too short on a busy runner and too long everywhere else.
///
/// Motion is read from the screen itself, so nothing queries the app (a query stalls its main thread, which can restart
/// a tuner's hold): each screenshot is shrunk to a small grey thumbnail, and the screen counts as still once two
/// comparisons in a row barely differ. The ambient motion every stage has (the drifting motes, a breathing glow) stays
/// well under the threshold; a sliding row, a page transition or a ringing string doesn't. Changes too small to see in
/// a thumbnail (a counting number, a fingertip landing) need a cue from the screen as well: the tests wait for it first.
extension XCTestCase {
    /// Waits until the screen is still, at most `timeout`, and returns the last screenshot: the still picture itself,
    /// or the latest one when the screen never came to rest (a live tuner never does).
    @discardableResult
    func stillScreenshot(timeout: TimeInterval = 4, interval: TimeInterval = 0.15, tolerance: Double = 0.2) -> XCUIScreenshot {
        let deadline = Date().addingTimeInterval(timeout)
        var screenshot = XCUIScreen.main.screenshot()
        var previous = StillScreen.thumbnail(screenshot)
        var quiet = 0
        while Date() < deadline {
            Thread.sleep(forTimeInterval: interval)
            screenshot = XCUIScreen.main.screenshot()
            let current = StillScreen.thumbnail(screenshot)
            quiet = StillScreen.motion(previous, current) < tolerance ? quiet + 1 : 0
            if quiet >= 2 { return screenshot }
            previous = current
        }
        return screenshot
    }
}

enum StillScreen {
    /// Thumbnail width in pixels: about one per four points across a phone.
    static let columns = 100

    /// The screenshot as a small grey bitmap (empty when it can't be drawn).
    static func thumbnail(_ screenshot: XCUIScreenshot) -> [UInt8] {
        guard let image = screenshot.image.cgImage, image.width > 0, image.height > 0 else { return [] }
        let width = columns
        let height = max(1, image.height * width / image.width)
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? pixels : []
    }

    /// The mean difference per pixel between two thumbnails, in grey levels (0–255); infinite when they can't be compared.
    static func motion(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return .infinity }
        var total = 0
        for index in a.indices { total += abs(Int(a[index]) - Int(b[index])) }
        return Double(total) / Double(a.count)
    }
}
