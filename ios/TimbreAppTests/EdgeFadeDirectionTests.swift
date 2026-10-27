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
            let leftInset: CGFloat = direction == .rightToLeft ? 32 : 20
            let rightInset: CGFloat = direction == .rightToLeft ? 20 : 32
            let maxOffset: CGFloat = 900 + rightInset - 300
            for offset in [-leftInset - 12, -leftInset, 200, maxOffset, maxOffset + 12] {
                let geometry = ScrollGeometry(contentOffset: CGPoint(x: offset, y: 0),
                    contentSize: CGSize(width: 900, height: 44),
                    contentInsets: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 32),
                    containerSize: CGSize(width: 300, height: 44))
                let value = EdgeOverflow(geometry, direction: direction)
                let expected = EdgeOverflow(physicalLeft: offset > -leftInset + 1,
                                            physicalRight: offset < maxOffset - 1, direction: direction)
                XCTAssertEqual(value, expected)
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
        let geometry = ScrollGeometry(contentOffset: CGPoint(x: -20, y: 0),
            contentSize: CGSize(width: 100, height: 44),
            contentInsets: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20),
            containerSize: CGSize(width: 300, height: 44))
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            XCTAssertEqual(EdgeOverflow(geometry, direction: direction), EdgeOverflow())
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
            let host = UIHostingController(rootView: ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(0..<12) { index in
                        Text("Item \(index)").frame(width: 100, height: 44)
                    }
                }
            }
            .contentMargins(.leading, 20, for: .scrollContent)
            .contentMargins(.trailing, 32, for: .scrollContent)
            .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, value in
                probe.value = value
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
                guard let geometry = probe.value else { return false }
                let overflow = EdgeOverflow(geometry, direction: direction)
                return geometry.contentSize.width > 1000 && geometry.containerSize.width >= 300
                    && !overflow.leading && overflow.trailing
            }, object: nil)
            await fulfillment(of: [measured], timeout: 3)
            let geometry = try XCTUnwrap(probe.value)
            let overflow = EdgeOverflow(geometry, direction: direction)
            print("EDGE-FADE native direction=\(direction) geometry=\(geometry) overflow=\(overflow)")
            XCTAssertFalse(overflow.leading, "Initial selected first item is fully visible at semantic leading")
            XCTAssertTrue(overflow.trailing, "Remaining catalogue still needs its continuation fade")
        }
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
