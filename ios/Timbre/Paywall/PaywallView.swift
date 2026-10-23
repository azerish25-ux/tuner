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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedID = TimbreProduct.annual
    @State private var appeared = false
    /// Visible height of the scroll area above the pinned bar. The hero gives way so the plans stay in view.
    @State private var viewport: CGFloat = 615
    /// Notifications are off for Timbre: no reminder can arrive, so none is promised.
    @State private var remindersBlocked = false

    /// The yearly plan unless the storefront left it out.
    private var selected: Product? { commerce.products.first { $0.id == selectedID } ?? commerce.products.first }

    /// What the pill, headline, benefits and three plan rows need below the hero at the default text size.
    private static let contentBelowHero: CGFloat = 448
    private var heroHeight: CGFloat { min(150, max(108, viewport - Self.contentBelowHero)) }

    /// Works both as a presented sheet (dismiss) and as the root overlay (the store flag).
    private func close() {
        if context == .standard { store.showPaywall = false }
        dismiss()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.12), startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
            ScrollView {
                content
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            // The bar below joins the safe area, so this is the height left for content above it.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
            } action: { height in
                viewport = height
            }
            // Pinned and opaque: the plans scroll under a short fade, never through the button.
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            closeButton
        }
        .preferredColorScheme(.dark)
        .task { await commerce.load() }
        .task { remindersBlocked = await TrialReminder.isBlocked() }
        .onAppear { appeared = true }
        .onChange(of: scenePhase) { _, phase in
            // The person may have switched notifications on or off in Settings meanwhile.
            guard phase == .active else { return }
            Task { remindersBlocked = await TrialReminder.isBlocked() }
        }
        .onChange(of: commerce.isPro) { _, pro in if pro { close() } }
    }

    private var content: some View {
        VStack(spacing: 0) {
            hero.padding(.top, 6)
            proPill.padding(.top, 2)
            headline.padding(.top, 10)
            benefits.padding(.top, 14)
            plans.padding(.top, 16).animation(Motion.settle, value: commerce.products.isEmpty)
            trustRow.padding(.top, 14)
            if showsTrialTimeline, let annual = commerce.annual {
                trialTimeline(annual).padding(.top, 28).transition(.opacity)
            }
            finePrint.padding(.top, 24)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private var closeButton: some View {
        Button { close() } label: {
            Image(systemName: "xmark").font(.body.weight(.bold)).foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44).background(Circle().fill(Palette.surface))
        }
        .padding(.trailing, 18).padding(.top, 8)
        .accessibilityLabel("Close").accessibilityIdentifier("paywall.close")
    }

    // MARK: Hero

    /// Three instruments in a spotlight, each floating on its own slow cycle.
    private var hero: some View {
        let height = heroHeight
        let scale = height / 270
        let picks: [(asset: String, angle: Double, height: CGFloat, x: CGFloat)] = [
            ("17_bowed_strings_violin", -14, 190 * scale, -128 * scale),
            ("19_bowed_strings_cello", 12, 210 * scale, 128 * scale),
            ("01_guitar_acoustic_guitar", 0, 250 * scale, 0),
        ]
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Ellipse().fill(.black.opacity(0.55)).frame(width: 300 * scale, height: max(12, 26 * scale)).blur(radius: 12).offset(y: 124 * scale)
                ForEach(Array(picks.enumerated()), id: \.offset) { index, pick in
                    let bob = reduceMotion ? 0 : sin(t * 0.9 + Double(index) * 2.1)
                    Image(card(pick.asset)).resizable().interpolation(.high).scaledToFit()
                        .frame(height: pick.height)
                        .rotationEffect(.degrees(pick.angle + bob * 1.6))
                        .offset(x: pick.x, y: CGFloat(bob) * 4 * scale + (index == 2 ? 0 : 8 * scale))
                        .shadow(color: .black.opacity(0.6), radius: 14, y: 10)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 18)
                        .animation(.spring(response: 0.9, dampingFraction: 0.8).delay(Double(index) * 0.08), value: appeared)
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// Studio render when the instrument has one, otherwise its photograph.
    private func card(_ asset: String) -> String {
        if let model = ModelLibrary.modelID(forPhoto: asset), ModelLibrary.hasCard(model) { return ModelLibrary.cardImageName(model) }
        return store.catalog.photos.first { $0.asset == asset }?.thumbnail ?? asset
    }

    private var proPill: some View {
        Text("TIMBRE PRO").font(Typeface.label(12)).tracking(2.2).foregroundStyle(Color(hex: 0x1B1206))
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(Capsule().fill(Palette.proGold))
            .shadow(color: Color(hex: 0xE39A3B).opacity(0.35), radius: 10, y: 3)
    }

    private var headline: some View {
        Text("Every lesson.\nEvery instrument.").font(Typeface.display(28)).tracking(-0.7)
            .multilineTextAlignment(.center).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 8) {
            benefit("graduationcap.fill", "\(store.curriculum.lessonCount) lessons across \(store.curriculum.courses.count) courses")
            benefit("guitars.fill", "\(store.catalog.instruments.count) instruments, each on its own live stage")
            benefit("ear.fill", "Every ear game and practice tool")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    private func benefit(_ symbol: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.mint)
                .frame(width: 22, height: 22).background(Circle().fill(Palette.mint.opacity(0.14)))
                .accessibilityHidden(true)
            // One line in English; longer translations wrap rather than truncate.
            Text(title).font(.subheadline).foregroundStyle(Palette.ink)
                .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Plans

    @ViewBuilder private var plans: some View {
        if commerce.products.isEmpty {
            if commerce.loading {
                planSkeleton
            } else {
                VStack(spacing: 10) {
                    Text(commerce.error ?? String(localized: "Plans are loading.")).font(.subheadline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    Button("Try again") { Task { await commerce.load() } }.buttonStyle(BrassButtonStyle(prominent: false))
                }
                .padding(.top, 10)
            }
        } else {
            VStack(spacing: 8) {
                if let annual = commerce.annual {
                    planRow(annual, title: "Yearly", detail: perMonth(annual), tag: annualTag(annual), saving: annualSaving)
                }
                if let monthly = commerce.monthly {
                    planRow(monthly, title: "Monthly", detail: String(localized: "cancel anytime"), tag: nil, saving: nil)
                }
                if let lifetime = commerce.lifetime {
                    planRow(lifetime, title: "Lifetime", detail: String(localized: "pay once"), tag: nil, saving: nil)
                }
            }
            .padding(.top, 10)
            .transition(.opacity)
        }
    }

    /// Holds the plans' place while StoreKit answers, so nothing jumps when they arrive.
    private var planSkeleton: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised).frame(height: 62)
            }
        }
        .overlay { ProgressView().tint(Palette.mint) }
        .padding(.top, 10)
    }

    private func perMonth(_ product: Product) -> String {
        String(localized: "\((product.price / 12).formatted(product.priceFormatStyle)) a month")
    }

    private func annualTag(_ annual: Product) -> String {
        commerce.trialLabel != nil ? String(localized: "\(trialDays(annual)) days free") : String(localized: "Best value")
    }

    /// Whole percent the yearly plan saves against twelve monthly payments, rounded down.
    /// Nil without a monthly plan or when the saving is under 10%.
    private var annualSaving: Int? {
        guard let annual = commerce.annual, let monthly = commerce.monthly, monthly.price > 0 else { return nil }
        let twelveMonths = monthly.price * 12
        var percent = (twelveMonths - annual.price) / twelveMonths * 100
        var whole = Decimal()
        NSDecimalRound(&whole, &percent, 0, .down)
        let value = NSDecimalNumber(decimal: whole).intValue
        return value >= 10 ? value : nil
    }

    private func select(_ product: Product) {
        guard selected?.id != product.id else { return }
        withAnimation(Motion.quick) { selectedID = product.id }
        Haptics.shared.selection()
    }

    private func planRow(_ product: Product, title: LocalizedStringKey, detail: String, tag: String?, saving: Int?) -> some View {
        let isSelected = selected?.id == product.id
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button { select(product) } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Palette.mint : Palette.inkFaint)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline).foregroundStyle(Palette.ink)
                        if let saving { saveChip(saving) }
                    }
                    Text(detail).font(.footnote).foregroundStyle(isSelected ? Palette.mint : Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                Text(product.displayPrice).font(Typeface.number(19)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(shape.fill(isSelected ? Palette.mint.opacity(0.08) : Palette.stageRaised))
            .overlay(shape.strokeBorder(isSelected ? Palette.mint : Palette.line, lineWidth: isSelected ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if let tag { planTag(tag) }
            }
            .shadow(color: Palette.mint.opacity(isSelected ? 0.16 : 0), radius: 14, y: 4)
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    private func planTag(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.6).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Palette.mint))
            .offset(x: -14, y: -11)
    }

    private func saveChip(_ percent: Int) -> some View {
        Text(String(localized: "Save \(percent)%").uppercased())
            .font(.system(size: 10, weight: .heavy)).tracking(0.5).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(Palette.proGold))
            .lineLimit(1).fixedSize()
    }

    private var trustRow: some View {
        let promise: LocalizedStringKey = selected?.id == TimbreProduct.lifetime ? "Pay once, keep forever" : "Cancel anytime"
        return HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill").foregroundStyle(Palette.mint).accessibilityHidden(true)
            Text("No ads")
            separator
            Text("No account")
            separator
            Text(promise)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Palette.inkSoft)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var separator: some View {
        Text(verbatim: "·").foregroundStyle(Palette.inkFaint).accessibilityHidden(true)
    }

    // MARK: Trial

    private var showsTrialTimeline: Bool { selected?.id == TimbreProduct.annual && commerce.trialLabel != nil }

    /// No surprises: what happens on which day of the free trial. The reminder step only
    /// appears when notifications can reach the person; otherwise the timeline says how to cancel.
    private func trialTimeline(_ annual: Product) -> some View {
        let days = trialDays(annual)
        var steps: [(symbol: String, title: Text, detail: Text)] = [("lock.open.fill", Text("Today"), Text("Everything unlocked"))]
        if !remindersBlocked { steps.append(("bell.fill", Text("Day \(max(1, days - 2))"), Text("We remind you"))) }
        steps.append(("creditcard.fill", Text("Day \(days)"), Text("\(annual.displayPrice)/year")))
        return VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    if index > 0 { Rectangle().fill(Palette.mint.opacity(0.3)).frame(width: 18, height: 2).padding(.top, 14) }
                    VStack(spacing: 6) {
                        Image(systemName: step.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(index == 0 ? Palette.onAccent : Palette.mint)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(index == 0 ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Palette.mint.opacity(0.14))))
                        step.title.font(Typeface.label(13)).foregroundStyle(Palette.ink)
                        step.detail.font(.caption).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if remindersBlocked {
                Text("Cancel anytime in Settings before day \(days).")
                    .font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
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

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.stage.opacity(0), Palette.stage], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            cta
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 4)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .background(Palette.stage, ignoresSafeAreaEdges: .bottom)
        }
        // The pinned bar must leave room to scroll the plans at the largest text sizes.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var ctaTitle: String {
        guard let selected else { return String(localized: "Continue") }
        if selected.id == TimbreProduct.annual, let trial = commerce.trialLabel { return String(localized: "Start \(trial)") }
        if selected.id == TimbreProduct.lifetime { return String(localized: "Unlock for \(selected.displayPrice)") }
        return String(localized: "Subscribe for \(selected.displayPrice)")
    }

    /// What happens after the purchase, in one line next to the button.
    private var terms: String? {
        guard let selected else { return nil }
        switch selected.id {
        case TimbreProduct.annual where commerce.trialLabel != nil:
            return String(localized: "Free for \(trialDays(selected)) days, then \(selected.displayPrice) a year.")
        case TimbreProduct.annual: return String(localized: "\(selected.displayPrice) a year, renews automatically.")
        case TimbreProduct.monthly: return String(localized: "\(selected.displayPrice) a month, renews automatically.")
        default: return String(localized: "One payment. Yours to keep, no subscription.")
        }
    }

    private var cta: some View {
        VStack(spacing: 0) {
            purchaseButton
            if commerce.pending {
                Text("Waiting for approval. Access unlocks when the App Store confirms.").font(.caption).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center).padding(.top, 8)
            }
            if let error = commerce.error, !commerce.products.isEmpty {
                Text(error).font(.caption).foregroundStyle(Palette.danger).multilineTextAlignment(.center).padding(.top, 8)
                    .accessibilityIdentifier("commerceError")
            }
            if let terms {
                Text(terms).font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .padding(.top, 8)
            }
            if context == .onboarding {
                Button { close() } label: {
                    Text("Continue with the free tuner").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 12).padding(.vertical, 6).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityIdentifier("paywall.free")
            }
            links.padding(.top, 2)
        }
    }

    private var purchaseButton: some View {
        Button { purchase() } label: {
            if commerce.purchasing != nil {
                ProgressView().tint(Palette.onAccent)
            } else {
                Text(ctaTitle).font(Typeface.label(18)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(BrassButtonStyle())
        .disabled(selected == nil || commerce.purchasing != nil || commerce.pending)
        .accessibilityIdentifier("paywall.purchase")
    }

    private func purchase() {
        guard let selected else { return }
        let wasTrial = selected.id == TimbreProduct.annual && commerce.trialLabel != nil
        let days = trialDays(selected)
        Task {
            if await commerce.purchase(selected) {
                Analytics.log("purchase", ["product": selected.id])
                // Notification permission is asked here, after the trial has started, never before.
                if wasTrial { await TrialReminder.schedule(afterDays: days) }
            }
        }
    }

    private var links: some View {
        HStack(spacing: 0) {
            Button { Task { await commerce.restore() } } label: { linkLabel("Restore") }
                .buttonStyle(.plain)
                .disabled(commerce.loading)
            separator
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) { linkLabel("Terms") }
            separator
            Link(destination: URL(string: "https://azerish25-ux.github.io/tuner/privacy.html")!) { linkLabel("Privacy") }
        }
        .font(.footnote.weight(.semibold))
    }

    private func linkLabel(_ title: LocalizedStringKey) -> some View {
        Text(title).foregroundStyle(Palette.inkSoft)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .contentShape(Rectangle())
    }

    private var finePrint: some View {
        Text("Subscriptions renew automatically until cancelled in Settings › Apple Account › Subscriptions. Cancel at least a day before renewal to avoid the next charge. The tuner for guitar, bass and ukulele stays free.")
            .font(.caption2).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Local reminder two days before a free trial converts. The paywall promises it only when it can arrive.
enum TrialReminder {
    /// True when notifications are turned off for Timbre, so a reminder would never be shown.
    static func isBlocked() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    /// Called right after a successful trial purchase. A first-time user is asked for permission here.
    static func schedule(afterDays days: Int) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .denied:
            return
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        default:
            break
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Timbre Pro trial ends soon")
        content.body = String(localized: "It renews in two days. Keep tuning, or cancel anytime in Settings.")
        let seconds = max(3600, TimeInterval(days - 2) * 86400)
        let request = UNNotificationRequest(identifier: "timbre.trial.reminder", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        try? await center.add(request)
    }
}
