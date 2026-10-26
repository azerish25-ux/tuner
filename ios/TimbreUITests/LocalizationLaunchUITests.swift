import CoreGraphics
import UIKit
import XCTest

/// A first launch opens in the device's language and runs in its direction: German reads German from the welcome on,
/// Arabic lays out right to left with note names still read left to right, and no text on the welcome screen or the
/// tuner bypasses the string tables. Each test launches on storage of its own, as a fresh install does, with no language
/// picked in Timbre.
final class LocalizationLaunchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func launch(language: String, locale: String, onboarded: Bool, extra: [String] = []) {
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale] + extra
        if onboarded { app.launchEnvironment["TIMBRE_SKIP_ONBOARDING"] = "1" }
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }

    /// The first element whose whole label matches `pattern` (a regular expression).
    private func labeled(_ pattern: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", pattern)).firstMatch
    }

    private func settle(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    /// Attaches `picture` (a new screenshot when nil) as `name`.
    @discardableResult
    private func shot(_ name: String, picture: XCUIScreenshot? = nil) -> XCUIScreenshot {
        let screenshot = picture ?? XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return screenshot
    }

    func testAGermanDeviceWelcomesInGerman() {
        launch(language: "de", locale: "de_DE", onboarded: false)
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        XCTAssertFalse(start.label.isEmpty)
        XCTAssertNotEqual(start.label, "Get started", "the welcome's button is in German, not English")
        settle(1)
        shot("l10n-de-welcome")
        XCTAssertFalse(labeled("(?s)Tune in seconds\\..*").exists, "the welcome's headline is English")
        XCTAssertFalse(labeled("Timbre listens and tells you exactly how you did\\.").exists, "the line under the headline is English")
    }

    func testAGermanRegionalPhoneAutomaticallyWelcomesInGerman() {
        launch(language: "de-DE", locale: "de_DE", onboarded: false)
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        XCTAssertEqual(start.label, "Los geht's")
        shot("l10n-de-DE-automatic-welcome")
    }

    func testAGermanDeviceNamesTheTabsInGerman() {
        launch(language: "de", locale: "de_DE", onboarded: true)
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 25))
        XCTAssertTrue(tabs.buttons["Stimmen"].exists, "Tune")
        XCTAssertTrue(tabs.buttons["Lernen"].exists, "Learn")
        XCTAssertTrue(tabs.buttons["Fortschritt"].exists, "Progress")
        XCTAssertFalse(tabs.buttons["Learn"].exists)
        shot("l10n-de-tabs")
    }

    func testAnArabicDeviceRunsRightToLeft() {
        launch(language: "ar", locale: "ar_SA", onboarded: true)
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 25))
        // "Tune" and "Progress" in Arabic: the first tab and the last.
        let tune = tabs.buttons["\u{636}\u{628}\u{637}"]
        let progress = tabs.buttons["\u{627}\u{644}\u{62A}\u{642}\u{62F}\u{651}\u{645}"]
        XCTAssertTrue(tune.exists)
        XCTAssertTrue(progress.exists)
        if tune.exists && progress.exists {
            XCTAssertGreaterThan(tune.frame.midX, progress.frame.midX, "the first tab sits on the right")
        }
        shot("l10n-ar-tabs")
    }

    /// The tuner's big note reads "E₂" in Arabic too, never "₂E": the octave sits to the right of the note's letter.
    /// Read from the picture, since the readout is one element for VoiceOver: the note is drawn in the brightest ink,
    /// the octave beside it in a quieter grey on the same baseline (NoteReadout, Tune/Readout.swift). The demo pitch
    /// plays the string, so the readout is up whether or not the microphone starts (its alert would cover the tuner);
    /// while that string is locked the octave turns mint, so pictures are read until one shows it grey (unlocked).
    func testAnArabicTunerKeepsTheOctaveRightOfTheNote() {
        app.launchEnvironment["TIMBRE_DEMO_PITCH"] = "1"
        launch(language: "ar", locale: "ar_SA", onboarded: true)
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 30), "the tuner didn't open")
        let status = element("tune.status")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        settle(3)
        guard let line = (try? status.snapshot())?.frame, !line.isEmpty else {
            shot("l10n-ar-tune")
            return XCTFail("no status line under the readout to measure from")
        }
        let width = app.frame.width
        var picture = XCUIScreen.main.screenshot()
        var found = OctaveSide.measure(picture.image, above: line, screenWidth: width)
        // The demo pitch's six-second cycle locks for under half of it: eight looks 0.7 s apart span more than one.
        for _ in 0..<8 where found.side == .unknown {
            settle(0.7)
            picture = XCUIScreen.main.screenshot()
            found = OctaveSide.measure(picture.image, above: line, screenWidth: width)
        }
        shot("l10n-ar-tune", picture: picture)
        XCTAssertEqual(found.side, .right, "the octave isn't to the right of the note: \(found.summary)")
    }

    /// Pseudo-localization: with Foundation's bounded pseudolanguage every string looked up in the string tables reads
    /// "[# … #]", so a text without the brackets never went through them and would stay English in every language.
    /// The welcome screen and the tuner are checked; each offender is listed in the attached report.
    func testNoTextOnTheWelcomeOrTheTunerBypassesTheStringTables() throws {
        launch(language: "en", locale: "en_US", onboarded: false, extra: ["-NSSurroundLocalizedStrings", "YES"])
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 25))
        guard start.label.contains("[#") else {
            throw XCTSkip("The bounded pseudolanguage didn't apply to this run (the button reads \"\(start.label)\"), so nothing can be checked")
        }
        settle(1.5)
        var offenders = bypassing("welcome")
        app.terminate()

        app.launchEnvironment["TIMBRE_TEST_STORAGE_ID"] = UUID().uuidString
        launch(language: "en", locale: "en_US", onboarded: true, extra: ["-NSSurroundLocalizedStrings", "YES"])
        XCTAssertTrue(element("tune.stage").waitForExistence(timeout: 30), "the tuner didn't open")
        settle(3)
        offenders += bypassing("tuner")

        let report = XCTAttachment(string: (["Texts that bypass the string tables:"] + (offenders.isEmpty ? ["none"] : offenders))
            .joined(separator: "\n"))
        report.name = "l10n-pseudo-offenders.txt"
        report.lifetime = .keepAlways
        add(report)
        XCTAssertTrue(offenders.isEmpty, "\(offenders.count) texts bypass the string tables: \(offenders.prefix(8).joined(separator: "; "))")
    }

    /// Words a pseudo-localized run may show outside the brackets: the brand, and units that are the same everywhere.
    private static let verbatim: Set<String> = ["Timbre", "BPM"]

    /// Every visible text on the screen in front (one snapshot) that has a word outside a "[# … #]" span.
    private func bypassing(_ screen: String) -> [String] {
        shot("l10n-pseudo-\(screen)")
        guard let root = try? app.snapshot() else { return ["\(screen): the screen could not be read"] }
        var found: [String] = []
        var pending: [XCUIElementSnapshot] = [root]
        let bracketed = try? NSRegularExpression(pattern: "\\[#.*?#\\]", options: [.dotMatchesLineSeparators])
        let word = try? NSRegularExpression(pattern: "[A-Za-z]{3,}")
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children)
            guard node.elementType == .staticText, !node.label.isEmpty, let bracketed, let word else { continue }
            let text = node.label as NSString
            let outside = bracketed.stringByReplacingMatches(in: node.label, range: NSRange(location: 0, length: text.length), withTemplate: " ")
            let rest = outside as NSString
            let words = word.matches(in: outside, range: NSRange(location: 0, length: rest.length)).map { rest.substring(with: $0.range) }
            if words.contains(where: { !Self.verbatim.contains($0) }) {
                found.append("\(screen): \"\(node.label)\"")
            }
        }
        return found
    }
}

/// Which side of a note's letter its octave is drawn on, read from a screenshot of the tuner. The note is the largest
/// shape in the brightest ink just above the status line; the octave is a neutral grey shape on the note's baseline,
/// beside it. Grey pixels touching bright ones are the letter's own antialiasing and don't count.
enum OctaveSide {
    enum Side: String { case left, right, unknown }

    struct Finding {
        let side: Side
        let summary: String
    }

    /// A connected shape's pixel count and bounding box, in pixels.
    private struct Shape {
        var count = 0
        var minX: Int
        var maxX = 0
        var minY: Int
        var maxY = 0
    }

    /// `line`: the status line's frame and `screenWidth` the screen's width, in points; the readout is the band of up to
    /// 320 pt above the line.
    static func measure(_ image: UIImage, above line: CGRect, screenWidth: CGFloat) -> Finding {
        guard let cgImage = image.cgImage, screenWidth > 0 else { return Finding(side: .unknown, summary: "no image") }
        let scale = CGFloat(cgImage.width) / screenWidth
        let top = max(0, (line.minY - 320) * scale)
        let bottom = min(CGFloat(cgImage.height), line.minY * scale)
        let box = CGRect(x: 0, y: top, width: CGFloat(cgImage.width), height: bottom - top).integral
        guard box.height > 20, let band = cgImage.cropping(to: box) else { return Finding(side: .unknown, summary: "no room above the status line") }
        let width = band.width, height = band.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(band, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return Finding(side: .unknown, summary: "the picture couldn't be read") }

        // Classify: 2 bright ink, 1 neutral grey, 0 anything else. Rows run top to bottom in the buffer.
        var kind = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            let r = Int(pixels[index * 4]), g = Int(pixels[index * 4 + 1]), b = Int(pixels[index * 4 + 2])
            let high = max(r, g, b), low = min(r, g, b)
            let level = (r * 299 + g * 587 + b * 114) / 1000
            if level >= 220 && high - low <= 24 { kind[index] = 2 } else if level >= 100 && level <= 205 && high - low <= 26 { kind[index] = 1 }
        }

        // The largest bright shape: the note's letter.
        var label = [Int32](repeating: 0, count: width * height)
        var best = Shape(minX: 0, minY: 0)
        var next: Int32 = 0
        var stack: [Int] = []
        for start in 0..<(width * height) where kind[start] == 2 && label[start] == 0 {
            next += 1
            label[start] = next
            stack.append(start)
            var shape = Shape(minX: width, minY: height)
            while let index = stack.popLast() {
                let x = index % width, y = index / width
                shape.count += 1
                shape.minX = min(shape.minX, x); shape.maxX = max(shape.maxX, x)
                shape.minY = min(shape.minY, y); shape.maxY = max(shape.maxY, y)
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let neighbour = ny * width + nx
                    if kind[neighbour] == 2 && label[neighbour] == 0 { label[neighbour] = next; stack.append(neighbour) }
                }
            }
            if shape.count > best.count { best = shape }
        }
        let tall = best.maxY - best.minY
        guard best.count >= 1, CGFloat(tall) >= 30 * scale else {
            return Finding(side: .unknown, summary: "no note letter found above the status line (largest bright shape \(tall) px tall)")
        }

        // Grey level with the letter (the octave shares its baseline), clear of the letter's box and of any bright pixel.
        let margin = Int(3 * scale)
        let rowLow = max(0, best.minY - tall * 15 / 100), rowHigh = min(height - 1, best.maxY + tall * 15 / 100)
        let reach = tall * 12 / 10
        var left = 0, right = 0
        for y in rowLow...rowHigh {
            for x in max(0, best.minX - reach)..<min(width, best.maxX + reach) where kind[y * width + x] == 1 {
                if x >= best.minX - margin && x <= best.maxX + margin { continue }
                var nearBright = false
                for ny in max(0, y - 2)...min(height - 1, y + 2) where !nearBright {
                    for nx in max(0, x - 2)...min(width - 1, x + 2) where kind[ny * width + nx] == 2 { nearBright = true; break }
                }
                if nearBright { continue }
                if x < best.minX { left += 1 } else { right += 1 }
            }
        }
        let summary = "note letter \(best.maxX - best.minX)×\(tall) px at x \(best.minX)–\(best.maxX); "
            + "grey beside it: \(left) px left, \(right) px right"
        if right >= 20 && right >= left * 3 { return Finding(side: .right, summary: summary) }
        if left >= 20 && left >= right * 3 { return Finding(side: .left, summary: summary) }
        return Finding(side: .unknown, summary: summary)
    }
}
