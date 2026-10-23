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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selected: Product? { commerce.products.first { $0.id == selectedID } }

    /// Works both as a presented sheet (dismiss) and as the root overlay (the store flag).
    private func close() {
        if context == .standard { store.showPaywall = false }
        dismiss()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.18), startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    Text("TIMBRE PRO").font(Typeface.label(13)).tracking(2.2).foregroundStyle(Color(hex: 0x1B1206))
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(Capsule().fill(Palette.proGold))
                    Text("Every instrument.\nEvery practice tool.").font(Typeface.display(32)).tracking(-0.8)
                        .multilineTextAlignment(.center).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    benefits
                    plans.padding(.top, 8)
                    if selectedID == TimbreProduct.annual, commerce.trialLabel != nil, let annual = commerce.annual { trialTimeline(annual) }
                    cta
                    finePrint
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 30)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            Button { close() } label: {
                Image(systemName: "xmark").font(.body.weight(.bold)).foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44).background(Circle().fill(Palette.surface))
            }
            .padding(.trailing, 18).padding(.top, 8)
            .accessibilityLabel("Close").accessibilityIdentifier("paywall.close")
        }
        .preferredColorScheme(.dark)
        .task { await commerce.load() }
        .onAppear { appeared = true }
        .onChange(of: commerce.isPro) { _, pro in if pro { close() } }
    }

    /// Three instruments in a spotlight, each floating on its own slow cycle.
    private var hero: some View {
        let picks: [(asset: String, angle: Double, height: CGFloat, x: CGFloat)] = [
            ("17_bowed_strings_violin", -14, 190, -112), ("19_bowed_strings_cello", 12, 210, 112), ("01_guitar_acoustic_guitar", 0, 250, 0),
        ]
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Ellipse().fill(.black.opacity(0.55)).frame(width: 300, height: 26).blur(radius: 14).offset(y: 128)
                ForEach(Array(picks.enumerated()), id: \.offset) { index, pick in
                    let bob = reduceMotion ? 0 : sin(t * 0.9 + Double(index) * 2.1)
                    Image(card(pick.asset)).resizable().interpolation(.high).scaledToFit()
                        .frame(height: pick.height)
                        .rotationEffect(.degrees(pick.angle + bob * 1.6))
                        .offset(x: pick.x, y: CGFloat(bob) * 5 + (index == 2 ? 0 : 8))
                        .shadow(color: .black.opacity(0.6), radius: 18, y: 14)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appeared)
                }
            }
        }
        .frame(height: 270)
        .accessibilityHidden(true)
    }

    /// Studio render when the instrument has one, otherwise its photograph.
    private func card(_ asset: String) -> String {
        if let model = ModelLibrary.modelID(forPhoto: asset), ModelLibrary.hasCard(model) { return ModelLibrary.cardImageName(model) }
        return store.catalog.photos.first { $0.asset == asset }?.thumbnail ?? asset
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("\(store.catalog.instruments.count) instruments, each on its own live stage")
            benefit("All ear games and double XP quests")
            benefit("Chords, scales, intonation and drone")
            benefit("Unlimited custom tunings and string health")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private func benefit(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Palette.mint)
                .frame(width: 22, height: 22).background(Circle().fill(Palette.mint.opacity(0.16)))
            Text(title).font(.body).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var plans: some View {
        if commerce.products.isEmpty {
            if commerce.loading { ProgressView().tint(Palette.mint).frame(height: 96) }
            else {
                VStack(spacing: 10) {
                    Text(commerce.error ?? String(localized: "Plans are loading.")).font(.subheadline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    Button("Try again") { Task { await commerce.load() } }.buttonStyle(BrassButtonStyle(prominent: false))
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                if let annual = commerce.annual {
                    plan(annual, title: "Yearly", detail: perMonth(annual), tag: commerce.trialLabel != nil ? String(localized: "\(trialDays(annual)) days free") : String(localized: "Best value"))
                }
                if let monthly = commerce.monthly { plan(monthly, title: "Monthly", detail: String(localized: "cancel anytime"), tag: nil) }
            }
            .padding(.top, 10)
        }
    }

    private func perMonth(_ product: Product) -> String {
        String(localized: "\((product.price / 12).formatted(product.priceFormatStyle)) a month")
    }

    private func plan(_ product: Product, title: LocalizedStringKey, detail: String, tag: String?) -> some View {
        let isSelected = selectedID == product.id
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Button { withAnimation(Motion.quick) { selectedID = product.id }; Haptics.shared.selection() } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).foregroundStyle(Palette.inkSoft)
                Text(product.displayPrice).font(Typeface.number(22)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(detail).font(.footnote).foregroundStyle(isSelected ? Palette.mint : Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 16)
            .background(shape.fill(isSelected ? Palette.mint.opacity(0.07) : Palette.stageRaised))
            .overlay(shape.strokeBorder(isSelected ? Palette.mint : Palette.line, lineWidth: isSelected ? 2 : 1))
            .overlay(alignment: .topLeading) {
                if let tag {
                    Text(tag.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.6).foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Capsule().fill(Palette.mint))
                        .offset(x: 14, y: -11)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    /// No surprises: what happens on which day of the free trial.
    private func trialTimeline(_ annual: Product) -> some View {
        let days = trialDays(annual)
        let items: [(String, Text, Text)] = [
            ("lock.open.fill", Text("Today"), Text("Everything unlocked")),
            ("bell.fill", Text("Day \(max(1, days - 2))"), Text("We remind you")),
            ("creditcard.fill", Text("Day \(days)"), Text("\(annual.displayPrice)/year")),
        ]
        return HStack(alignment: .top, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Rectangle().fill(Palette.mint.opacity(0.3)).frame(width: 18, height: 2).padding(.top, 14) }
                VStack(spacing: 6) {
                    Image(systemName: item.0).font(.system(size: 13, weight: .bold)).foregroundStyle(index == 0 ? Palette.onAccent : Palette.mint)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(index == 0 ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Palette.mint.opacity(0.14))))
                    item.1.font(Typeface.label(13)).foregroundStyle(Palette.ink)
                    item.2.font(.caption).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 4)
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

    private var ctaTitle: String {
        guard let selected else { return String(localized: "Continue") }
        if selected.id == TimbreProduct.annual, let trial = commerce.trialLabel { return String(localized: "Start \(trial)") }
        if selected.id == TimbreProduct.lifetime { return String(localized: "Unlock for \(selected.displayPrice)") }
        return String(localized: "Subscribe for \(selected.displayPrice)")
    }

    /// What happens after the purchase, stated next to the button.
    private var terms: String? {
        guard let selected else { return nil }
        switch selected.id {
        case TimbreProduct.annual where commerce.trialLabel != nil:
            return String(localized: "Free for \(trialDays(selected)) days, then \(selected.displayPrice) a year. We remind you two days before it ends.")
        case TimbreProduct.annual: return String(localized: "\(selected.displayPrice) a year, renews automatically.")
        case TimbreProduct.monthly: return String(localized: "\(selected.displayPrice) a month, renews automatically.")
        default: return String(localized: "One payment. Yours to keep, no subscription.")
        }
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
                if commerce.purchasing != nil { ProgressView().tint(Palette.onAccent) } else { Text(ctaTitle).font(Typeface.label(18)) }
            }
            .buttonStyle(BrassButtonStyle())
            .disabled(selected == nil || commerce.purchasing != nil || commerce.pending)
            .accessibilityIdentifier("paywall.purchase")
            if let terms { Text(terms).font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true) }
            if commerce.pending { Text("Waiting for approval. Access unlocks when the App Store confirms.").font(.caption).foregroundStyle(Palette.inkSoft) }
            if let error = commerce.error, !commerce.products.isEmpty { Text(error).font(.caption).foregroundStyle(Palette.danger).accessibilityIdentifier("commerceError") }
            if context == .onboarding {
                Button("Continue with the free tuner") { close() }.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft).padding(.top, 4)
                    .accessibilityIdentifier("paywall.free")
            }
        }
    }

    private var finePrint: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                if let lifetime = commerce.lifetime {
                    Button("Lifetime \(lifetime.displayPrice)") { withAnimation(Motion.quick) { selectedID = lifetime.id }; Haptics.shared.selection() }
                        .foregroundStyle(selectedID == lifetime.id ? Palette.mint : Palette.inkSoft)
                        .accessibilityAddTraits(selectedID == lifetime.id ? .isSelected : [])
                        .accessibilityIdentifier("paywall.plan.\(lifetime.id)")
                }
                Button("Restore") { Task { await commerce.restore() } }
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy", destination: URL(string: "https://azerish25-ux.github.io/tuner/privacy.html")!)
            }
            .font(.footnote.weight(.semibold)).underline().foregroundStyle(Palette.inkSoft)
            .buttonStyle(.plain)
            Text("Subscriptions renew automatically until cancelled in Settings › Apple Account › Subscriptions. Cancel at least a day before renewal to avoid the next charge. The tuner for guitar, bass and ukulele stays free.")
                .font(.caption2).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
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
