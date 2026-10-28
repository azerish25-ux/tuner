import SwiftUI
import UIKit
import XCTest
@testable import Timbre

@MainActor
final class EdgeFadeDirectionTests: XCTestCase {
    func testPhysicalEndsMapToSemanticEndsInBothDirections() {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let rtl = direction == .rightToLeft
            for left in [false, true] {
                for right in [false, true] {
                    let value = EdgeOverflow(physicalLeft: left, physicalRight: right, direction: direction)
                    XCTAssertEqual(value.leading, rtl ? right : left)
                    XCTAssertEqual(value.trailing, rtl ? left : right)
                }
            }
        }
    }

    func testUnequalInsetsRestingEndsMiddleAndOverscroll() {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let restingOffset: CGFloat = direction == .rightToLeft ? 32 : -20
            let range: CGFloat = 900 + 20 + 32 - 300
            for progress in [-12, 0, 200, range, range + 12] {
                let value = EdgeOverflow(offset: restingOffset + progress,
                    contentSize: CGSize(width: 900, height: 44),
                    viewportSize: CGSize(width: 300, height: 44),
                    insets: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 32), direction: direction)
                XCTAssertEqual(value, EdgeOverflow(leading: progress > 1, trailing: progress < range - 1))
            }
        }
    }

    func testContentGeometryPathHasSameSemanticEndContract() {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let rtl = direction == .rightToLeft
            let start = CGRect(x: rtl ? 620 : -20, y: 0, width: 300, height: 44)
            let end = CGRect(x: rtl ? -20 : 620, y: 0, width: 300, height: 44)
            XCTAssertEqual(EdgeOverflow(viewport: start, contentWidth: 900, direction: direction),
                           EdgeOverflow(leading: false, trailing: true))
            XCTAssertEqual(EdgeOverflow(viewport: end, contentWidth: 900, direction: direction),
                           EdgeOverflow(leading: true, trailing: false))
            XCTAssertEqual(EdgeOverflow(viewport: CGRect(x: 200, y: 0, width: 300, height: 44),
                                        contentWidth: 900, direction: direction),
                           EdgeOverflow(leading: true, trailing: true))
        }
    }

    func testShortContentDoesNotInventAContinuationFade() {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let value = EdgeOverflow(offset: direction == .rightToLeft ? 20 : -20,
                contentSize: CGSize(width: 100, height: 44), viewportSize: CGSize(width: 300, height: 44),
                insets: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20), direction: direction)
            XCTAssertEqual(value, EdgeOverflow())
        }
    }

    func testNativeMaskKeepsRestingEndOpaqueAndFadesOnlyContinuation() throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for leading in [false, true] {
                for trailing in [false, true] {
                    let overflow = EdgeOverflow(leading: leading, trailing: trailing)
                    let pixels = try renderMask(overflow, direction: direction)
                    let physicalLeft = direction == .rightToLeft ? trailing : leading
                    let physicalRight = direction == .rightToLeft ? leading : trailing
                    XCTAssertEqual(pixels[100], 255, "Middle must stay completely opaque")
                    for (faded, outer, inner) in [(physicalLeft, 2, 30), (physicalRight, 197, 169)] {
                        if faded {
                            XCTAssertLessThan(pixels[outer], 64, "Real offscreen continuation must fade at the outside edge")
                            XCTAssertGreaterThan(pixels[inner], 230, "Ramp must join the solid centre without a dark seam")
                            XCTAssertLessThan(pixels[outer], pixels[inner])
                        } else {
                            XCTAssertEqual(pixels[outer], 255, "A resting end must not dim its fully visible selected chip")
                            XCTAssertEqual(pixels[inner], 255)
                        }
                    }
                }
            }
            // Negative control: semantic end inversion must be detected, not accepted as RTL styling.
            let correct = try renderMask(EdgeOverflow(leading: false, trailing: true), direction: direction)
            let reversed = try renderMask(EdgeOverflow(leading: true, trailing: false), direction: direction)
            XCTAssertNotEqual(correct, reversed)
        }
    }

    /// A real scroll view supplies the initial RTL offset; synthetic geometry alone cannot establish
    /// whether the platform reports a physical or a semantic offset. Preserve this native contract.
    func testLiveScrollGeometryReportsRestingLeadingEdgeWithoutFade() async throws {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let probe = EdgeFadeGeometryProbe()
            let driver = EdgeFadeScrollDriver()
            let host = UIHostingController(rootView: ScrollViewReader { scroller in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(0..<12) { index in
                            Text("Item \(index)").frame(width: 100, height: 44).id(index)
                        }
                    }
                    .onGeometryChange(for: CGRect?.self) { proxy in
                        proxy.bounds(of: .scrollView)
                    } action: { probe.viewport = $0 }
                }
                .contentMargins(.leading, 20, for: .scrollContent)
                .contentMargins(.trailing, 32, for: .scrollContent)
                .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, value in
                    probe.value = value
                }
                .onAppear { driver.scroll = { id, anchor in scroller.scrollTo(id, anchor: anchor) } }
            }
            .frame(width: 300, height: 44)
            .environment(\.layoutDirection, direction))
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive })
            let previous = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
            host.view.layoutIfNeeded()
            let measured = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let geometry = probe.value, let viewport = probe.viewport else { return false }
                // The content proxy sees the inset container, not the margin-inclusive visibleRect.
                // Both directions report 248 + 20 + 32 = 300; requiring a 300-point proxy never settles.
                return abs(geometry.contentSize.width - 1288) < 1
                    && abs(geometry.visibleRect.width - 300) < 1 && abs(viewport.width - 248) < 1
                    && abs(viewport.width - geometry.containerSize.width) < 1
            }, object: nil)
            await fulfillment(of: [measured], timeout: 3)
            let geometry = try XCTUnwrap(probe.value)
            XCTAssertEqual(geometry.containerSize.width, 248, accuracy: 1)
            XCTAssertEqual(geometry.visibleRect.width, geometry.containerSize.width
                           + geometry.contentInsets.leading + geometry.contentInsets.trailing, accuracy: 1)
            XCTAssertEqual(geometry.contentOffset.x, direction == .rightToLeft ? 32 : -20, accuracy: 1)
            let overflow = EdgeOverflow(geometry, direction: direction)
            XCTAssertFalse(overflow.leading, "Initial selected first item is fully visible at semantic leading")
            XCTAssertTrue(overflow.trailing, "Remaining catalogue still needs its continuation fade")
            try assertLiveOverflow(probe, direction: direction, expected: .init(leading: false, trailing: true), stage: "initial")
            // The content's physical bounds are an independent oracle. These stages establish that
            // logical x grows toward trailing in RTL too; a synthetic offset cannot prove that contract.
            for (id, anchor, expected) in [(5, UnitPoint.center, EdgeOverflow(leading: true, trailing: true)),
                                           (11, UnitPoint.trailing, EdgeOverflow(leading: true, trailing: false)),
                                           (0, UnitPoint.leading, EdgeOverflow(leading: false, trailing: true))] {
                try XCTUnwrap(driver.scroll)(id, anchor)
                let arrived = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    guard let viewport = probe.viewport else { return false }
                    return EdgeOverflow(viewport: viewport, contentWidth: 1288, direction: direction) == expected
                }, object: nil)
                await fulfillment(of: [arrived], timeout: 3)
                try assertLiveOverflow(probe, direction: direction, expected: expected, stage: "item-\(id)")
            }
        }
    }

    private func assertLiveOverflow(_ probe: EdgeFadeGeometryProbe, direction: LayoutDirection,
                                    expected: EdgeOverflow, stage: String) throws {
        let geometry = try XCTUnwrap(probe.value)
        let viewport = try XCTUnwrap(probe.viewport)
        let actual = EdgeOverflow(geometry, direction: direction)
        let report = "EDGE-FADE native direction=\(direction) stage=\(stage) geometry=\(geometry) "
            + "contentViewport=\(viewport) overflow=\(actual)"
        print(report)
        let attachment = XCTAttachment(string: report)
        attachment.name = "edge-fade-live-\(direction)-\(stage)"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(viewport.width, 248, accuracy: 1, "Content bounds exclude the 20/32-point margins")
        XCTAssertEqual(viewport.width, geometry.containerSize.width, accuracy: 1)
        XCTAssertEqual(geometry.visibleRect.width, 300, accuracy: 1)
        XCTAssertEqual(geometry.visibleRect.width, viewport.width
                       + geometry.contentInsets.leading + geometry.contentInsets.trailing, accuracy: 1)
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual, EdgeOverflow(viewport: viewport, contentWidth: 1288, direction: direction))
    }

    /// White content on black makes RGB an independent observation of the actual mask opacity.
    private func renderMask(_ overflow: EdgeOverflow, direction: LayoutDirection) throws -> [UInt8] {
        let renderer = ImageRenderer(content: Color.white.frame(width: 200, height: 20)
            .mask { EdgeFadeMask(overflow: overflow, leading: 36, trailing: 36) }
            .background(Color.black).environment(\.layoutDirection, direction))
        renderer.scale = 1
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "edge-fade-\(direction)-\(overflow.leading)-\(overflow.trailing)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let cgImage = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: 200 * 20 * 4)
        try bytes.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: 200, height: 20,
                bitsPerComponent: 8, bytesPerRow: 800, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 200, height: 20))
        }
        return (0..<200).map { bytes[(10 * 200 + $0) * 4] }
    }
}

/// XCTest may evaluate its predicate away from the SwiftUI callback. The payload is Sendable;
/// synchronize its storage rather than assuming both escaping closures always share an executor.
private final class EdgeFadeGeometryProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: ScrollGeometry?
    private var viewportStorage: CGRect?

    var viewport: CGRect? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return viewportStorage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            viewportStorage = newValue
        }
    }

    var value: ScrollGeometry? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage = newValue
        }
    }
}

@MainActor
private final class EdgeFadeScrollDriver {
    var scroll: ((Int, UnitPoint) -> Void)?
}
