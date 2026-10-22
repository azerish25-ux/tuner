import SwiftUI
import StoreKit

struct PlusView: View {
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("TIMBRE PLUS").font(.caption.weight(.semibold)).tracking(3).foregroundStyle(TimbreTheme.action)
                        Spacer()
                        Image(systemName: "sparkle").foregroundStyle(TimbreTheme.action)
                    }
                    Text(commerce.isPlus ? "timbre_owned_heading" : "timbre_paywall_full_access_heading").font(TimbreTheme.title(36))
                    Text("One purchase opens every instrument, alternate tuning, singing practice and Studio.")
                        .foregroundStyle(TimbreTheme.secondary)
                    Panel {
                        benefit("music.note.list", title: "timbre_benefit_instruments", detail: "timbre_benefit_instruments_detail")
                        Divider()
                        benefit("waveform", title: "timbre_benefit_practice", detail: "timbre_benefit_practice_detail")
                        Divider()
                        benefit("checkmark.seal", title: "Permanent access", detail: "One payment. No subscription.")
                    }
                    if commerce.isPlus {
                        Label("timbre_entitlement_lifetime", systemImage: "checkmark.seal.fill").foregroundStyle(TimbreTheme.success)
                        Button("Continue") { dismiss() }.buttonStyle(PrimaryButton())
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("timbre_paywall_price_term").font(.headline)
                            if let product = commerce.product {
                                Text(product.displayPrice).font(TimbreTheme.number(34))
                                Button { Task { await commerce.purchase() } } label: {
                                    if commerce.loading { ProgressView().frame(maxWidth: .infinity) }
                                    else { Text("Unlock all features · \(product.displayPrice)") }
                                }.buttonStyle(PrimaryButton()).disabled(commerce.loading || commerce.pending)
                            } else if commerce.loading {
                                HStack { ProgressView(); Text("timbre_paywall_price_loading") }
                            } else {
                                Text("timbre_paywall_unavailable").foregroundStyle(TimbreTheme.secondary)
                                Button("Try again") { Task { await commerce.load() } }.buttonStyle(PrimaryButton())
                            }
                            Text("One payment. No subscription. The App Store shows the price before you pay.")
                                .font(.caption).foregroundStyle(TimbreTheme.secondary)
                        }
                    }
                    if commerce.pending {
                        Panel {
                            Label("timbre_payment_pending", systemImage: "clock").font(.headline)
                            Text("The App Store is processing your payment. Features unlock when payment is confirmed. Please do not purchase again.")
                                .font(.subheadline).foregroundStyle(TimbreTheme.secondary)
                        }
                    }
                    if let error = commerce.error { Text(error).font(.subheadline).foregroundStyle(TimbreTheme.warning).accessibilityIdentifier("commerceError") }
                    Button("timbre_restore_button") { Task { await commerce.restore() } }
                        .frame(maxWidth: .infinity, minHeight: 44).disabled(commerce.loading)
                    Text("Guitar, four-string bass and ukulele remain available without a purchase.")
                        .font(.caption).foregroundStyle(TimbreTheme.secondary)
                    HStack(spacing: 20) {
                        Link("Privacy policy", destination: URL(string: "https://github.com/azerish25-ux/tuner/blob/main/docs/ios/PRIVACY.md")!)
                        Link("Terms of use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }.font(.caption).frame(maxWidth: .infinity)
                }.padding(24)
            }.background(TimbreTheme.canvas).foregroundStyle(TimbreTheme.primary)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }.task { await commerce.load() }
    }
    private func benefit(_ icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(TimbreTheme.action).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(TimbreTheme.secondary)
            }
        }.padding(.vertical, 4)
    }
}
