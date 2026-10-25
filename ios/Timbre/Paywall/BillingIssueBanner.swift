import StoreKit
import SwiftUI

/// A subscription payment the App Store couldn't collect, said plainly with its one fix: the App Store's own
/// subscription sheet, where the payment method is updated. It shows only while there is such a problem
/// (`CommerceService.billingIssue`): in the Billing Grace Period Pro carries on and the banner says until when; in
/// Billing Retry Pro has paused. Back from the sheet, entitlements are checked again, so a fixed payment clears it at
/// once. The app shell places it above the content; it keeps to the screen's gutters itself.
struct BillingIssueBanner: View {
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var managing = false

    var body: some View {
        // A stack rather than a group: the sheet stays attached while it is open, even once the problem is fixed.
        VStack(spacing: 0) {
            if let issue = commerce.billingIssue {
                card(issue)
                    .transition(.adaptive(.move(edge: .top).combined(with: .opacity), reduceMotion: reduceMotion))
            }
        }
        .adaptiveAnimation(Motion.settle, value: commerce.billingIssue)
        .manageSubscriptionsSheet(isPresented: $managing)
        .onChange(of: managing) { _, open in
            guard !open else { return }
            Task { await commerce.refreshEntitlements() }
        }
    }

    private func card(_ issue: BillingIssue) -> some View {
        Button {
            Haptics.shared.selection()
            managing = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "creditcard.trianglebadge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(Palette.amber)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    title(issue)
                        .font(Typeface.cardTitle)
                        .foregroundStyle(Palette.ink)
                    message(issue)
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSoft)
                    Text("Update payment")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.amber)
                        .padding(.top, 2)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding, tint: Palette.amber)
        }
        .buttonStyle(PressScaleStyle())
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens your App Store subscription"))
        .accessibilityIdentifier("billing.banner")
    }

    private func title(_ issue: BillingIssue) -> Text {
        switch issue {
        case .gracePeriod: return Text("Your payment didn't go through")
        case .billingRetry: return Text("Timbre Pro is paused")
        }
    }

    private func message(_ issue: BillingIssue) -> Text {
        switch issue {
        case .gracePeriod(let until?):
            return Text("Pro stays on until \(until, format: .dateTime.month(.wide).day()). Update your payment method to keep it.")
        case .gracePeriod:
            return Text("Update your payment method to keep Timbre Pro.")
        case .billingRetry:
            return Text("The App Store couldn't renew your subscription. Update your payment method to pick up where you left off.")
        }
    }
}
