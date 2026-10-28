import CoreText
import CryptoKit
import SwiftUI
import UIKit
import XCTest
@testable import Timbre

/// Diagnostic only: records exact disagreements without turning exploratory variants into acceptance gates.
/// Existing production acceptance tests remain separate and unchanged; a green harness cannot accept a repair.
/// UIKit captures original bounded scroll viewports, never an oversized hosting view or stitched image.
@MainActor
final class WelcomeRendererGeometryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Per-case diagnostic watchdog: local polling deadlines cannot interrupt a blocked UIKit draw/layout.
        // The app workflow enables XCTest timeouts; timeout is a failure, never a skipped/accepted variant.
        executionTimeAllowance = 120
        continueAfterFailure = true
    }

    func testRTL280Large() { matrix(width: 280, size: .large) }
    func testRTL280AX5() { matrix(width: 280, size: .accessibility5) }
    func testRTL362Large() { matrix(width: 362, size: .large) }
    func testRTL362AX5() { matrix(width: 362, size: .accessibility5) }

    private enum Backend: String, CaseIterable { case imageRenderer, attachedScrollViewport }
    private struct Bitmap {
        let width: Int
        let height: Int
        let rgba: Data
        let inkCount: Int
    }
    private struct Raster {
        let image: UIImage
        let scale: CGFloat
        let geometry: ScrollGeometry?
        let requested: CGPoint?
        let reserved: CGRect
        let valid: Bool
    }
    private struct Reference {
        let bitmap: Bitmap
        let geometry: ScrollGeometry?
        let requested: CGPoint?
    }

    private func matrix(width: CGFloat, size: DynamicTypeSize) {
        var visited = 0
        for backend in Backend.allCases {
            var baseline: [Reference] = []
            var positions: [CGPoint]?
            for variant in GeometryVariant.allCases {
                let name = "urdu-geometry-\(Int(width))-\(size)-\(backend.rawValue)-\(variant.rawValue)"
                let log = GeometryRecorder()
                provenance(width: width, size: size, backend: backend, variant: variant, log: log)
                do {
                    try autoreleasepool {
                        let content = GeometryCanvas(width: width, log: log) {
                            GeometryHeadline(variant: variant, log: log)
                                .foregroundStyle(Color.black)
                                .environment(\.layoutDirection, .rightToLeft)
                        }
                        .background(Color.white)
                        .environment(\.locale, Locale(identifier: "ur"))
                        .environment(\.dynamicTypeSize, size)
                        .environment(\.displayScale, 3)
                        .environment(\.layoutDirection, .leftToRight)
                        let rasters = try capture(AnyView(content), backend: backend, width: width,
                                                  isPlain: variant == .plain, positions: &positions, log: log)
                        var references: [Reference] = []
                        var validReference = !rasters.isEmpty
                        for (index, raster) in rasters.enumerated() {
                            let tile = name + (backend == .imageRenderer ? "-full" : "-viewport-\(index)")
                            let attachment = XCTAttachment(image: raster.image)
                            attachment.name = tile
                            attachment.lifetime = .keepAlways
                            add(attachment)
                            do {
                                let actual = try canonical(raster.image, scale: raster.scale, reserved: raster.reserved, tile: tile, log: log)
                                let valid = raster.valid && actual.inkCount > 100
                                validReference = validReference && valid
                                XCTAssertTrue(raster.valid, "Incomplete or geometrically invalid original capture: " + tile)
                                XCTAssertGreaterThan(actual.inkCount, 100, "Blank raster is not valid evidence: " + tile)
                                references.append(Reference(bitmap: actual, geometry: raster.geometry, requested: raster.requested))
                                if variant != .plain {
                                    guard baseline.indices.contains(index) else {
                                        XCTFail("No valid independent reference for " + tile)
                                        continue
                                    }
                                    let reference = baseline[index]
                                    // Hosted plain Text may itself clip ink; exact disagreement is evidence, not repair eligibility.
                                    let sameGeometry = reference.geometry == raster.geometry && reference.requested == raster.requested
                                    let same = reference.bitmap.width == actual.width && reference.bitmap.height == actual.height
                                        && reference.bitmap.rgba == actual.rgba
                                    let changed = zip(reference.bitmap.rgba, actual.rgba).reduce(0) { $0 + ($1.0 == $1.1 ? 0 : 1) }
                                        + abs(reference.bitmap.rgba.count - actual.rgba.count)
                                    log.add(["kind": "strictComparison", "tile": tile, "reference": GeometryVariant.plain.rawValue,
                                             "sameBackendOnly": true, "sameActualGeometry": sameGeometry,
                                             "sameRGBA": same, "changedRGBABytes": changed, "captureValid": valid,
                                             "coordinateEquivalentComparison": valid && sameGeometry,
                                             "diagnosticOnly": true, "noEligibility": true])
                                }
                            } catch {
                                validReference = false
                                log.add(["kind": "rasterFailure", "tile": tile, "error": String(describing: error)])
                                XCTFail("Cannot read original raster: \(tile): \(error)")
                            }
                        }
                        if variant == .plain {
                            if validReference { baseline = references }
                            else { log.add(["kind": "invalidBaseline", "reason": "Incomplete drawing, geometry or actual glyph ink"]) }
                        } else {
                            XCTAssertEqual(rasters.count, baseline.count, "Every source-defined reference viewport must be captured")
                        }
                    }
                } catch {
                    log.add(["kind": "captureFailure", "error": String(describing: error)])
                    XCTFail("Native diagnostic capture failed: \(name): \(error)")
                }
                do {
                    let data = try JSONSerialization.data(withJSONObject: log.snapshot(), options: [.prettyPrinted, .sortedKeys])
                    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                    attachment.name = name + "-geometry"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                } catch { XCTFail("Geometry evidence must serialize: \(name): \(error)") }
                visited += 1
            }
        }
        XCTAssertEqual(visited, 14, "Every variant and both backends must be evaluated despite earlier failures")
    }

    private func provenance(width: CGFloat, size: DynamicTypeSize, backend: Backend,
                            variant: GeometryVariant, log: GeometryRecorder) {
        let environment = ProcessInfo.processInfo.environment
        log.add(["kind": "provenance", "diagnosticOnly": true, "sourceFile": #fileID,
                 "declaredSourceSHA": environment["TIMBRE_DIAGNOSTIC_SOURCE_SHA"] ?? environment["GITHUB_SHA"] ?? "not-provided",
                 "declaredSourceSHAIsIndependentlyVerified": false,
                 "appBundle": Bundle.main.bundleIdentifier ?? "unknown",
                 "appBuild": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                 "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
                 "backend": backend.rawValue, "variant": variant.rawValue,
                 "width": Double(width), "dynamicType": String(describing: size), "direction": "rightToLeft",
                 "textMetricDisplayScale": 3, "imageRendererScale": 3, "hostedRasterScale": "actual-window-screen-scale",
                 "rendererCallbacksObservable": variant == .zeroDefaultSize || variant == .zeroExplicitSize
                    || variant == .measuredDefaultSize || variant == .measuredExplicitSize,
                 "realOnboardingCoverage": false, "stitchedOrScaledAcceptance": false,
                 "productionEligibilityClaim": false, "comparisonIsDiagnosticOnly": true])
    }

    private func capture(_ content: AnyView, backend: Backend, width: CGFloat, isPlain: Bool,
                         positions: inout [CGPoint]?, log: GeometryRecorder) throws -> [Raster] {
        if backend == .imageRenderer {
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: width + 160, height: nil)
            renderer.scale = 3
            renderer.isOpaque = true
            let image = try XCTUnwrap(renderer.uiImage, "ImageRenderer must return a real image")
            let pixels = try XCTUnwrap(image.cgImage)
            return [Raster(image: image, scale: 3, geometry: nil, requested: nil,
                           reserved: CGRect(x: 80, y: 80, width: width, height: CGFloat(pixels.height) / 3 - 160), valid: true)]
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }, "Require the test app's existing active window scene")
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow && !$0.isHidden })
        let parent = try XCTUnwrap(window.rootViewController)
        window.layoutIfNeeded()
        let viewport = window.safeAreaLayoutGuide.layoutFrame.intersection(window.bounds)
        _ = try XCTUnwrap(Self.finite(viewport) ? true : nil, "Require a real positive window safe-area viewport")
        let model = GeometryScrollModel(log: log)
        let host = UIHostingController(rootView: GeometryScrollHost(content: content, model: model))
        host.safeAreaRegions = []
        host.loadViewIfNeeded()
        let container = UIView(frame: parent.view.convert(viewport, from: window))
        container.backgroundColor = .white
        container.isUserInteractionEnabled = false
        parent.addChild(host)
        host.view.frame = container.bounds
        host.view.backgroundColor = .white
        container.addSubview(host.view)
        parent.view.addSubview(container)
        host.didMove(toParent: parent)
        defer {
            host.willMove(toParent: nil)
            host.view.removeFromSuperview()
            host.removeFromParent()
            container.removeFromSuperview()
        }
        let initial = try settled(model, host: host, after: nil)
        let hostFrame = host.view.convert(host.view.bounds, to: window)
        let contained = host.view.window === window && window.bounds.contains(hostFrame) && viewport.contains(hostFrame)
        let nativeScaleMatches = window.screen.scale == 3
        log.add(["kind": "boundedHost", "attachedToExpectedWindow": host.view.window === window,
                 "windowViewport": GeometryRecorder.rect(window.bounds), "windowSafeArea": GeometryRecorder.rect(viewport),
                 "hostFrameInWindow": GeometryRecorder.rect(hostFrame), "hostBounds": GeometryRecorder.rect(host.view.bounds),
                 "hostClipsToBounds": host.view.clipsToBounds, "hostLayerMasksToBounds": host.view.layer.masksToBounds,
                 "hostContained": contained, "windowScreenScale": Double(window.screen.scale),
                 "nativeScaleMatchesFixedMetrics": nativeScaleMatches, "safeAreaRegions": "empty",
                 "hostingViewIsWindowBounded": true, "realOnboardingCoverage": false, "layers": layers(host.view.layer)])
        XCTAssertTrue(contained, "The hosting view itself must fit inside the actual window safe area")
        XCTAssertTrue(nativeScaleMatches, "This matrix requires an actual 3x window; a 2x capture cannot silently substitute")
        if isPlain {
            do { positions = try Self.grid(content: initial.contentSize, viewport: initial.containerSize) }
            catch {
                log.add(["kind": "sourceGridInvalid", "truncated": false, "error": String(describing: error)])
                throw error
            }
            log.add(["kind": "sourceGrid", "origin": "plain-native-scroll-geometry-not-image-data",
                     "content": GeometryRecorder.size(initial.contentSize), "viewport": GeometryRecorder.size(initial.containerSize),
                     "positions": (positions ?? []).map { [$0.x, $0.y].map(GeometryRecorder.scalar) }, "truncated": false])
        }
        let plan = positions ?? [.zero]
        if positions == nil { XCTFail("Independent source geometry is missing; only an invalid diagnostic viewport can be captured") }
        var rasters: [Raster] = []
        for (index, target) in plan.enumerated() {
            let before = model.geometry
            let generation = model.generation
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { model.position.scrollTo(x: target.x, y: target.y) }
            let needsChange = before.map {
                $0.contentOffset != CGPoint(x: min(target.x, max(0, $0.contentSize.width - $0.containerSize.width)),
                                            y: min(target.y, max(0, $0.contentSize.height - $0.containerSize.height)))
            } ?? true
            let geometry: ScrollGeometry?
            var didSettle = true
            do { geometry = try settled(model, host: host, after: needsChange ? generation : nil, target: target) }
            catch {
                didSettle = false
                geometry = model.geometry
                log.add(["kind": "scrollFailure", "index": index, "error": String(describing: error)])
                XCTFail("Source-defined scroll position did not settle: \(index): \(error)")
            }
            let captureFrame = host.view.convert(host.view.bounds, to: window)
            let bounded = host.view.window === window && viewport.contains(captureFrame) && window.bounds.contains(captureFrame)
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.screen.scale
            format.opaque = true
            format.preferredRange = .standard
            var drawn = false
            let image = UIGraphicsImageRenderer(size: host.view.bounds.size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(host.view.bounds)
                drawn = host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let unchanged = geometry != nil && geometry == model.geometry
            let viewportMatches = geometry.map { $0.containerSize == host.view.bounds.size && $0.contentInsets == EdgeInsets() } ?? false
            let reached = geometry.map { $0.contentOffset == Self.clamped(target, geometry: $0) } ?? false
            let valid = contained && bounded && nativeScaleMatches && drawn && didSettle && unchanged
                && viewportMatches && reached && positions != nil
            log.add(["kind": "originalViewport", "index": index, "requestedOffset": [target.x, target.y].map(GeometryRecorder.scalar),
                     "actualScrollGeometry": geometry.map(GeometryRecorder.scroll) ?? [:],
                     "clampedExpectedOffset": geometry.map {
                         [Self.clamped(target, geometry: $0).x, Self.clamped(target, geometry: $0).y].map(GeometryRecorder.scalar)
                     } ?? [], "requestedOrClampedOffsetReached": reached,
                     "drawHierarchyReturned": drawn, "nativeScrollSettled": didSettle, "geometryUnchangedDuringCapture": unchanged,
                     "rasterScale": Double(window.screen.scale),
                     "hostContained": bounded, "nativeContainerMatchesHost": viewportMatches, "validReferenceCandidate": valid])
            var reserved = CGRect.null
            if let geometry {
                let source = CGRect(x: 80, y: 80, width: width, height: geometry.contentSize.height - 160)
                reserved = source.intersection(geometry.visibleRect)
                    .offsetBy(dx: -geometry.visibleRect.minX, dy: -geometry.visibleRect.minY)
            }
            rasters.append(Raster(image: image, scale: window.screen.scale, geometry: geometry,
                                  requested: target, reserved: reserved, valid: valid))
        }
        let rects = rasters.compactMap { $0.geometry?.visibleRect }
        let covered = Self.covers(rects, content: initial.contentSize)
        log.add(["kind": "sourceCoverage", "everySourceCellVisible": covered, "viewportCount": rasters.count,
                 "coverageRequiredForReference": isPlain, "planAlwaysDerivedFromPlain": true])
        if isPlain {
            XCTAssertTrue(covered, "Original native viewports must cover the full source canvas without stitching")
            if !covered {
                return rasters.map {
                    Raster(image: $0.image, scale: $0.scale, geometry: $0.geometry, requested: $0.requested, reserved: $0.reserved, valid: false)
                }
            }
        }
        return rasters
    }

    private func settled(_ model: GeometryScrollModel, host: UIViewController, after generation: Int?,
                         target: CGPoint? = nil) throws -> ScrollGeometry {
        let deadline = Date().addingTimeInterval(5)
        var previous: ScrollGeometry?
        while Date() < deadline {
            host.view.layoutIfNeeded()
            CATransaction.flush()
            RunLoop.main.run(until: Date().addingTimeInterval(0.04))
            guard let current = model.geometry,
                  generation.map({ model.generation > $0 }) ?? true else { continue }
            let reached = target.map { current.contentOffset == Self.clamped($0, geometry: current) } ?? true
            if current == previous, reached, Self.finite(current.visibleRect),
               current.contentSize.width > 0, current.contentSize.height > 0 {
                return current
            }
            previous = current
        }
        throw GeometryFailure(description: "No stable native ScrollGeometry after the requested source position")
    }

    private static func finite(_ value: CGRect) -> Bool {
        !value.isNull && !value.isEmpty && [value.minX, value.minY, value.width, value.height].allSatisfy(\.isFinite)
    }
    private static func clamped(_ target: CGPoint, geometry: ScrollGeometry) -> CGPoint {
        CGPoint(x: min(max(0, target.x), max(0, geometry.contentSize.width - geometry.containerSize.width)),
                y: min(max(0, target.y), max(0, geometry.contentSize.height - geometry.containerSize.height)))
    }
    private static func grid(content: CGSize, viewport: CGSize) throws -> [CGPoint] {
        func axis(_ total: CGFloat, _ length: CGFloat) throws -> [CGFloat] {
            guard total.isFinite, length.isFinite, total > 0, length > 0 else {
                throw GeometryFailure(description: "Source grid requires finite positive native geometry")
            }
            let end = max(0, total - length)
            var points: [CGFloat] = [0]
            while let last = points.last, last < end {
                let next = min(end, last + length)
                guard points.count < 64, next > last else {
                    throw GeometryFailure(description: "Source grid exceeds 64 tiles or cannot advance; never truncate coverage")
                }
                points.append(next)
            }
            return points
        }
        let xs = try axis(content.width, viewport.width), ys = try axis(content.height, viewport.height)
        guard xs.count * ys.count <= 64 else {
            throw GeometryFailure(description: "Source grid exceeds 64 total tiles; never truncate coverage")
        }
        return ys.flatMap { y in xs.map { CGPoint(x: $0, y: y) } }
    }
    private static func covers(_ rects: [CGRect], content: CGSize) -> Bool {
        let source = CGRect(origin: .zero, size: content)
        guard finite(source), !rects.isEmpty else { return false }
        let visible = rects.map { $0.intersection(source) }.filter { finite($0) }
        let xs = Set([CGFloat(0), content.width] + visible.flatMap { [$0.minX, $0.maxX] }).sorted()
        let ys = Set([CGFloat(0), content.height] + visible.flatMap { [$0.minY, $0.maxY] }).sorted()
        for x in 0..<(xs.count - 1) {
            for y in 0..<(ys.count - 1) {
                let point = CGPoint(x: (xs[x] + xs[x + 1]) / 2, y: (ys[y] + ys[y + 1]) / 2)
                if !visible.contains(where: { $0.contains(point) }) { return false }
            }
        }
        return true
    }

    private func layers(_ root: CALayer) -> [[String: Any]] {
        var result: [[String: Any]] = []
        func visit(_ layer: CALayer, depth: Int) {
            guard depth <= 8, result.count < 128 else { return }
            result.append(["type": String(describing: type(of: layer)), "depth": depth,
                           "frame": GeometryRecorder.rect(layer.frame), "bounds": GeometryRecorder.rect(layer.bounds),
                           "masksToBounds": layer.masksToBounds, "contentsScale": Double(layer.contentsScale)])
            for child in layer.sublayers ?? [] { visit(child, depth: depth + 1) }
        }
        visit(root, depth: 0)
        return result
    }

    private func canonical(_ image: UIImage, scale: CGFloat, reserved: CGRect, tile: String, log: GeometryRecorder) throws -> Bitmap {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.interpolationQuality = .none
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var ink = 0, left = width, right = -1, top = height, bottom = -1
        for offset in stride(from: 0, to: bytes.count, by: 4)
            where bytes[offset] < 128 && bytes[offset + 1] < 128 && bytes[offset + 2] < 128 {
            ink += 1
            let pixel = offset / 4, x = pixel % width, y = pixel / width
            left = min(left, x); right = max(right, x)
            top = min(top, y); bottom = max(bottom, y)
        }
        let bounds = ink > 0 ? CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1) : .null
        let reservedPixels = reserved.isNull ? CGRect.null : CGRect(x: reserved.minX * scale, y: reserved.minY * scale,
                                                                    width: reserved.width * scale, height: reserved.height * scale)
        let data = Data(bytes)
        log.add(["kind": "canonicalRaster", "tile": tile, "pixels": [width, height], "inkPixels": ink,
                 "inkBoundsPixels": GeometryRecorder.rect(bounds), "visibleReservedContentPixels": GeometryRecorder.rect(reservedPixels),
                 "reservedContainsVisibleInk": !bounds.isNull && reservedPixels.contains(bounds),
                 "boundsThresholdOnly": "RGB channels below128; equality still compares every unmodified RGBA byte",
                 "rgbaSHA256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                 "registrationOrTolerance": false])
        return Bitmap(width: width, height: height, rgba: data, inkCount: ink)
    }
}

private struct GeometryFailure: Error, CustomStringConvertible { let description: String }

@MainActor
private final class GeometryScrollModel: ObservableObject {
    @Published var position = ScrollPosition(idType: Int.self, point: .zero)
    var geometry: ScrollGeometry?
    var generation = 0
    let log: GeometryRecorder
    init(log: GeometryRecorder) { self.log = log }
}

private struct GeometryScrollHost: View {
    let content: AnyView
    @ObservedObject var model: GeometryScrollModel
    var body: some View {
        ScrollView([.horizontal, .vertical]) { content }
            .scrollIndicators(.hidden)
            .contentMargins(0, for: .scrollContent)
            .scrollPosition($model.position)
            .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, value in
                model.geometry = value
                model.generation += 1
                model.log.add(["kind": "nativeScrollGeometry", "generation": model.generation,
                               "geometry": GeometryRecorder.scroll(value)])
            }
            .background(Color.white)
            .environment(\.layoutDirection, .leftToRight)
    }
}

private enum GeometryVariant: String, CaseIterable {
    case plain, zeroDefaultSize, zeroExplicitSize, measuredDefaultSize, measuredExplicitSize, actualProduction, paddedDrawingGroup
}

/// The only shared production helper is the measured outer allowance. Font selection and native Text are independent.
private struct GeometryHeadline: View {
    let variant: GeometryVariant
    let log: GeometryRecorder
    @ScaledMetric(relativeTo: .largeTitle) private var points: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var horizontal: CGFloat = 12

    var body: some View {
        let face = Typeface.boldText ? Typeface.Face.semiBold.heavier : Typeface.Face.semiBold
        let base = CTFontCreateWithName(face.fontName as CFString, points, nil)
        let word = "سیکھیں۔"
        let font = CTFontCreateForStringWithLanguage(base, word as CFString,
            CFRange(location: 0, length: (word as NSString).length), "ur" as CFString)
        let ink = WelcomeHeadline.nativeUrduInkInsets(font: font,
            text: "سیکنڈوں میں ٹیون کریں۔\nپھر بجانا سیکھیں۔", displayScale: 3)
        let reserve = WelcomeHeadline.nativeUrduLayoutInsets(ink: ink, minimumHorizontal: horizontal)
        let text = Text("Tune in seconds.\nThen learn to play.").font(Font(font)).tracking(-1)
            .typesettingLanguage(Locale(identifier: "ur").language)
        log.add(["kind": "independentFont", "postScriptName": CTFontCopyPostScriptName(font) as String,
                 "points": Double(CTFontGetSize(font)), "boldText": Typeface.boldText,
                 "inkInsets": GeometryRecorder.insets(ink),
                 "outerReserve": GeometryRecorder.insets(reserve)])
        return Group {
            switch variant {
            case .plain:
                text.padding(reserve).fixedSize(horizontal: false, vertical: true)
            case .zeroDefaultSize:
                text.textRenderer(DefaultGeometryRenderer(displayPadding: EdgeInsets(), log: log))
                    .padding(reserve).fixedSize(horizontal: false, vertical: true)
            case .zeroExplicitSize:
                text.textRenderer(ExplicitGeometryRenderer(displayPadding: EdgeInsets(), log: log))
                    .padding(reserve).fixedSize(horizontal: false, vertical: true)
            case .measuredDefaultSize:
                text.textRenderer(DefaultGeometryRenderer(displayPadding: ink, log: log))
                    .padding(reserve).fixedSize(horizontal: false, vertical: true)
            case .measuredExplicitSize:
                text.textRenderer(ExplicitGeometryRenderer(displayPadding: ink, log: log))
                    .padding(reserve).fixedSize(horizontal: false, vertical: true)
            case .actualProduction:
                WelcomeHeadline()
            case .paddedDrawingGroup:
                text.padding(reserve).fixedSize(horizontal: false, vertical: true)
                    .drawingGroup(opaque: false, colorMode: .nonLinear)
            }
        }
    }
}

/// Truly default sizing: observing it by overriding sizeThatFits would defeat this control.
private struct DefaultGeometryRenderer: TextRenderer {
    let displayPadding: EdgeInsets
    let log: GeometryRecorder
    nonisolated func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        log.drawing(layout, context: context, padding: displayPadding)
        for line in layout { context.draw(line) }
    }
}

private struct ExplicitGeometryRenderer: TextRenderer {
    let displayPadding: EdgeInsets
    let log: GeometryRecorder
    nonisolated func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize {
        let result = text.sizeThatFits(proposal)
        log.add(["kind": "explicitTextProxySize", "proposal": GeometryRecorder.proposal(proposal),
                 "returned": GeometryRecorder.size(result), "displayPadding": GeometryRecorder.insets(displayPadding)])
        return result
    }
    nonisolated func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        log.drawing(layout, context: context, padding: displayPadding)
        for line in layout { context.draw(line) }
    }
}

/// Same physical canvas and logical RTL leading anchor for every variant; no measured pixel offset enters placement.
private struct GeometryCanvas: Layout {
    let width: CGFloat
    let log: GeometryRecorder
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let childProposal = ProposedViewSize(width: width, height: nil)
        let child = subviews[0].sizeThatFits(childProposal)
        let result = CGSize(width: width + 160, height: child.height + 160)
        log.add(["kind": "wrapperSize", "outerProposal": GeometryRecorder.proposal(proposal),
                 "subviewProposal": GeometryRecorder.proposal(childProposal), "subviewReturned": GeometryRecorder.size(child),
                 "canvasReturned": GeometryRecorder.size(result), "observationLevel": "outside-padded-headline"])
        return result
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let at = CGPoint(x: bounds.minX + 80 + width, y: bounds.minY + 80)
        log.add(["kind": "wrapperPlacement", "bounds": GeometryRecorder.rect(bounds),
                 "at": [at.x, at.y].map(GeometryRecorder.scalar), "anchor": [1, 0],
                 "subviewProposal": GeometryRecorder.proposal(ProposedViewSize(width: width, height: nil))])
        subviews[0].place(at: at, anchor: UnitPoint(x: 1, y: 0), proposal: ProposedViewSize(width: width, height: nil))
    }
}

/// Renderer callbacks need not run on the main actor. Every read and write is protected by this lock.
private final class GeometryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [[String: Any]] = []
    func add(_ event: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }
    func snapshot() -> [[String: Any]] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
    func drawing(_ layout: Text.Layout, context: GraphicsContext, padding: EdgeInsets) {
        let lines: [[String: Any]] = layout.enumerated().map { index, line in
            let bounds = line.typographicBounds
            return ["index": index, "rect": Self.rect(bounds.rect), "origin": [bounds.origin.x, bounds.origin.y].map(Self.scalar),
                    "width": Self.scalar(bounds.width), "ascent": Self.scalar(bounds.ascent),
                    "descent": Self.scalar(bounds.descent), "leading": Self.scalar(bounds.leading)]
        }
        let transform = context.transform
        add(["kind": "rendererDraw", "lineCount": layout.count, "lines": lines,
             "displayPadding": Self.insets(padding), "clipBoundingRect": Self.rect(context.clipBoundingRect),
             "contextTransform": [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty].map(Self.scalar)])
    }
    /// Layout probes and graphics clip bounds may legitimately be infinite. Preserve that fact in JSON.
    static func scalar(_ value: CGFloat) -> Any { value.isFinite ? Double(value) as Any : String(describing: value) }
    static func rect(_ value: CGRect) -> [Any] { [value.minX, value.minY, value.width, value.height].map(Self.scalar) }
    static func size(_ value: CGSize) -> [Any] { [value.width, value.height].map(Self.scalar) }
    static func insets(_ value: EdgeInsets) -> [Any] {
        [value.top, value.leading, value.bottom, value.trailing].map(Self.scalar)
    }
    static func scroll(_ value: ScrollGeometry) -> [String: Any] {
        ["contentOffset": [value.contentOffset.x, value.contentOffset.y].map(Self.scalar),
         "contentSize": size(value.contentSize), "containerSize": size(value.containerSize),
         "contentInsets": insets(value.contentInsets), "visibleRect": rect(value.visibleRect)]
    }
    static func proposal(_ value: ProposedViewSize) -> [String: Any] {
        ["width": value.width.map(Self.scalar) ?? NSNull(),
         "height": value.height.map(Self.scalar) ?? NSNull()]
    }
}
