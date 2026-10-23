import StoreKit
import SwiftUI
import TimbreCore
import UserNotifications

struct PaywallView: View {
    enum Context { case onboarding, standard }
    var context: Context = .standard
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = TimbreProduct.annual
    @State private var appeared = false

    private var selected: Product? { commerce.products.first { $0.id == selectedID } }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            StageBackground()
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    VStack(spacing: 8) {
                        Eyebrow("Timbre Pro")
                        Text("Every instrument.\nEvery practice tool.").font(Typeface.display(40)).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                    }
                    benefits
                    plans
                    if selectedID == TimbreProduct.annual, commerce.trialLabel != nil, let annual = commerce.annual { timeline(annual) }
                    cta
                    finePrint
                }
                .padding(.horizontal, 22).padding(.top, 36).padding(.bottom, 30)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.body.weight(.bold)).foregroundStyle(Palette.inkSoft).frame(width: 40, height: 40).glassCapsule()
            }
            .padding(.trailing, 18).padding(.top, 10)
            .accessibilityLabel("Close").accessibilityIdentifier("paywall.close")
        }
        .task { await commerce.load() }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { appeared = true } }
        .onChange(of: commerce.isPro) { _, pro in if pro { dismiss() } }
    }

    private var heroImage: String {
        if let model = store.modelID, ModelLibrary.hasCard(model) { return ModelLibrary.cardImageName(model) }
        return ModelLibrary.cardImageName("guitar_acoustic")
    }

    private var hero: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Palette.ember.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 170)).frame(width: 340, height: 340)
            Image(heroImage).resizable().scaledToFit().frame(height: 230)
                .rotationEffect(.degrees(appeared ? -8 : -14))
                .offset(y: appeared ? 0 : 16)
                .shadow(color: .black.opacity(0.6), radius: 28, y: 18)
        }
        .frame(height: 240)
        .accessibilityHidden(true)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("cube.transparent.fill", "All sixty instruments in 3D", "Live pegs, slides and strings for every tuning mechanism")
            benefit("dot.radiowaves.left.and.right", "Strobe precision", "Temperaments, custom tunings and written pitch")
            benefit("calendar.badge.clock", "A daily practice set", "Ear training, chords, scales, drone and voice coaching")
            benefit("chart.xyaxis.line", "See yourself improve", "Accuracy trends and milestones, measured on device")
        }
        .stillCard()
    }

    private func benefit(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Palette.brass).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var plans: some View {
        if commerce.products.isEmpty {
            if commerce.loading { ProgressView().tint(Palette.brass).frame(height: 120) }
            else {
                VStack(spacing: 10) {
                    Text(commerce.error ?? String(localized: "Plans are loading.")).font(.subheadline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    Button("Try again") { Task { await commerce.load() } }.buttonStyle(BrassButtonStyle(prominent: false))
                }
            }
        } else {
            VStack(spacing: 10) {
                if let annual = commerce.annual { plan(annual, title: "Yearly", detail: perMonth(annual), badge: commerce.trialLabel ?? String(localized: "Best value")) }
                if let monthly = commerce.monthly { plan(monthly, title: "Monthly", detail: String(localized: "Cancel anytime"), badge: nil) }
                if let lifetime = commerce.lifetime { plan(lifetime, title: "Lifetime", detail: String(localized: "Pay once, keep forever"), badge: nil) }
            }
        }
    }

    private func perMonth(_ product: Product) -> String {
        let monthly = product.price / 12
        return String(localized: "\(monthly.formatted(product.priceFormatStyle)) per month, billed yearly")
    }

    private func plan(_ product: Product, title: LocalizedStringKey, detail: String, badge: String?) -> some View {
        let isSelected = selectedID == product.id
        return Button { selectedID = product.id; Haptics.shared.selection() } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle").font(.title3).foregroundStyle(isSelected ? Palette.brass : Palette.inkFaint)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline).foregroundStyle(Palette.ink)
                        if let badge {
                            Text(badge).font(.caption2.weight(.bold)).padding(.horizontal, 8).padding(.vertical, 3)
                                .foregroundStyle(Color(hex: 0x1A1206)).background(Capsule().fill(Palette.brass))
                        }
                    }
                    Text(detail).font(.caption).foregroundStyle(Palette.inkSoft)
                }
                Spacer()
                Text(product.displayPrice).font(Typeface.number(16)).foregroundStyle(Palette.ink)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(isSelected ? Palette.brass.opacity(0.14) : Palette.stageRaised.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(isSelected ? Palette.brass : Palette.line, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    private func timeline(_ annual: Product) -> some View {
        let days = trialDays(annual)
        return VStack(alignment: .leading, spacing: 12) {
            row("lock.open.fill", "Today", "Full access to everything in Timbre Pro.", Palette.brass)
            row("bell.fill", "Day \(max(1, days - 2))", "We remind you before the trial ends.", Palette.flat)
            row("star.fill", "Day \(days)", "\(annual.displayPrice) per year starts, unless you cancel.", Palette.ember)
        }
        .stillCard()
    }

    private func trialDays(_ product: Product) -> Int {
        guard let period = product.subscription?.introductoryOffer?.period else { return 14 }
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        default: return 14
        }
    }

    private func row(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 26, height: 26).background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.caption).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private var ctaTitle: String {
        guard let selected else { return String(localized: "Continue") }
        if selected.id == TimbreProduct.annual, let trial = commerce.trialLabel { return String(localized: "Start \(trial)") }
        if selected.id == TimbreProduct.lifetime { return String(localized: "Unlock for \(selected.displayPrice)") }
        return String(localized: "Subscribe for \(selected.displayPrice)")
    }

    private var cta: some View {
        VStack(spacing: 10) {
            Button {
                guard let selected else { return }
                Task {
                    let wasTrial = selected.id == TimbreProduct.annual && commerce.trialLabel != nil
                    let days = trialDays(selected)
                    if await commerce.purchase(selected) {
                        Analytics.log("purchase", ["product": selected.id])
                        if wasTrial { await TrialReminder.schedule(afterDays: days) }
                    }
                }
            } label: {
                if commerce.purchasing != nil { ProgressView().tint(Color(hex: 0x1A1206)) } else { Text(ctaTitle) }
            }
            .buttonStyle(BrassButtonStyle())
            .disabled(selected == nil || commerce.purchasing != nil || commerce.pending)
            .accessibilityIdentifier("paywall.purchase")
            if commerce.pending { Text("Waiting for approval. Access unlocks when the App Store confirms.").font(.caption).foregroundStyle(Palette.inkSoft) }
            if let error = commerce.error, !commerce.products.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.danger).accessibilityIdentifier("commerceError") }
            if context == .onboarding {
                Button("Continue with the free tuner") { dismiss() }.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 4)
                    .accessibilityIdentifier("paywall.free")
            }
        }
    }

    private var finePrint: some View {
        VStack(spacing: 10) {
            Text("Subscriptions renew automatically until cancelled in Settings › Apple Account › Subscriptions. Cancel at least a day before renewal to avoid the next charge. The free tuner for guitar, bass and ukulele stays free.")
                .font(.caption2).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Restore purchases") { Task { await commerce.restore() } }
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy", destination: URL(string: "https://azerish25-ux.github.io/tuner/privacy.html")!)
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSoft)
        }
    }
}

/// Local reminder two days before a free trial converts.
enum TrialReminder {
    static func schedule(afterDays days: Int) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Timbre Pro trial ends soon")
        content.body = String(localized: "It renews in two days. Keep tuning, or cancel anytime in Settings.")
        let seconds = max(3600, TimeInterval(days - 2) * 86400)
        let request = UNNotificationRequest(identifier: "timbre.trial.reminder", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        try? await center.add(request)
    }
}
