import SwiftUI
import UIKit
import XCTest

/// Diagnostic platform controls only. Original production regressions are unchanged.
/// Observed binding writeback is recorded, never written from the requested target or assumed to pass.
@MainActor
final class NativeScrollTrackingControlTests: XCTestCase {
    func testSingleReaderLeftToRight() async throws { try await exercise(nested: false, direction: .leftToRight) }
    func testSingleReaderRightToLeft() async throws { try await exercise(nested: false, direction: .rightToLeft) }
    func testNestedReaderLeftToRight() async throws { try await exercise(nested: true, direction: .leftToRight) }
    func testNestedReaderRightToLeft() async throws { try await exercise(nested: true, direction: .rightToLeft) }

    private final class Model: ObservableObject {
        @Published var requested: Int?
        @Published var observed: Int?
        var frames: [Int: CGRect] = [:]
        var history: [Int?] = []
    }

    private struct Control: View {
        @ObservedObject var model: Model
        let nested: Bool

        var body: some View {
            ScrollViewReader { outer in
                Group {
                    if nested {
                        ScrollViewReader { _ in page }
                    } else {
                        page
                    }
                }
                .onChange(of: model.requested) { _, value in
                    guard let value else { return }
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { outer.scrollTo(value, anchor: .center) }
                }
            }
            .background(Color.white)
        }

        private var page: some View {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(0..<12, id: \.self) { id in
                        Text(verbatim: "Control row \(id)")
                            .foregroundStyle(Color.black)
                            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                            .background(Color.blue.opacity(0.15))
                            .id(id)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                                model.frames[id] = frame
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $model.observed, anchor: .center)
            .onChange(of: model.observed) { _, value in model.history.append(value) }
        }
    }

    private func exercise(nested: Bool, direction: LayoutDirection) async throws {
        executionTimeAllowance = 120
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let previous = scene.windows.first { $0.isKeyWindow }
        let model = Model()
        let host = UIHostingController(rootView: Control(model: model, nested: nested)
            .environment(\.layoutDirection, direction).ignoresSafeArea())
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            model.frames[0]?.height == 120
        }, object: nil)
        await fulfillment(of: [loaded], timeout: 3)
        XCTAssertTrue(window.bounds.contains(host.view.convert(host.view.bounds, to: window)))
        let target = 6
        model.requested = target
        let placed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let row = model.frames[target] else { return false }
            return window.bounds.contains(row) && abs(row.midY - window.bounds.midY) <= 1
        }, object: nil)
        await fulfillment(of: [placed], timeout: 3)
        let row = try XCTUnwrap(model.frames[target])
        XCTAssertTrue(window.bounds.contains(row), "The command must place real content before interpreting writeback")
        let report: [String: Any] = [
            "diagnosticOnly": true, "productionAcceptance": false,
            "nestedPrivateReader": nested, "direction": String(describing: direction),
            "requestedID": target, "observedID": model.observed as Any? ?? NSNull(),
            "history": model.history.map { $0 as Any? ?? NSNull() },
            "row": [row.minX, row.minY, row.width, row.height],
            "window": [window.bounds.width, window.bounds.height],
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "geometryPlaced": window.bounds.contains(row),
            "bindingWasNotAssignedByTest": true
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
        print("NATIVE_SCROLL_PLATFORM_CONTROL " + String(decoding: data, as: UTF8.self))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "platform-scroll-\(nested)-\(direction)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
