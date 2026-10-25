import SwiftUI
import TimbreCore

// The social layer's pieces on screen (Services/GameCenter.swift does the talking to GameKit):
// - "Challenge a friend" (`ChallengeFriendButton`): Game Center's own challenge on iOS 26 when App Store Connect has one
//   for the board, else a "Beat my score" card with its link for the share sheet. On Pitch Sniper's end screen
//   (`SniperFriendChallenge`) and on a song's results (Learn/LessonResults.swift, with `SongChallengeCard`).
// - The friend streak on Progress's week card and its poster (`FriendStreakLine`, `WeekFriendsRow`).
// Signed out, before iOS 26, or with nothing set up in App Store Connect, the links and the share sheet are all that show.

// MARK: - Challenge a friend

/// "Challenge a friend" as a pill in `tint`: Game Center's challenge for `board` where it can, else `card` (rendered
/// once `armed`, after the screen's entrance) and `message` for the share sheet.
struct ChallengeFriendButton<Card: View>: View {
    let board: String?
    /// Where it was tapped, for the analytics event.
    let screen: String
    let tint: Color
    let message: String
    let armed: Bool
    let card: Card
    @ObservedObject private var center = GameCenter.shared
    @State private var image: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    init(board: String?, screen: String, tint: Color = Palette.mint, message: String, armed: Bool = true,
         @ViewBuilder card: () -> Card) {
        self.board = board
        self.screen = screen
        self.tint = tint
        self.message = message
        self.armed = armed
        self.card = card()
    }

    /// The board Game Center can run a challenge on now, if any.
    private var gameCenterBoard: String? {
        guard let board, center.canChallenge(on: board) else { return nil }
        return board
    }

    var body: some View {
        Group {
            if let board = gameCenterBoard {
                Button {
                    Haptics.shared.selection()
                    center.challengeFriends(on: board, from: screen)
                } label: {
                    face(symbol: "flag.2.crossed.fill")
                }
                .buttonStyle(PressScaleStyle())
            } else if let image {
                ShareLink(item: image, subject: Text("Beat my score"), message: Text(verbatim: message),
                          preview: SharePreview("Beat my score", image: image)) {
                    face(symbol: "paperplane.fill")
                }
                .buttonStyle(PressScaleStyle())
            } else {
                face(symbol: "paperplane.fill").opacity(0.55)
            }
        }
        .accessibilityLabel(Text("Challenge a friend"))
        .animation(Motion.fade, value: image == nil)
        .task(id: armed) {
            guard armed, image == nil else { return }
            try? await Task.sleep(for: ShareCardRenderer.entrance)
            guard !Task.isCancelled, image == nil else { return }
            image = ShareCardRenderer.image(card, scale: displayScale, locale: locale, direction: layoutDirection)
        }
    }

    private func face(symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold)).accessibilityHidden(true)
            Text("Challenge a friend")
        }
        .font(Typeface.label(14))
        .foregroundStyle(tint)
        .lineLimit(1)
        .padding(.horizontal, 16)
        .frame(minHeight: Metrics.minTarget)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1))
        .fixedSize()
        .contentShape(Capsule())
    }
}

/// Pitch Sniper's end screen: "Challenge a friend" with this game's score and, while a Game Center challenge is on,
/// "Live challenge", which opens it. Hidden after a game that beat a friend's link: "Send it back"
/// (`SniperChallengeResult`) already answers that one.
struct SniperFriendChallenge: View {
    let score: Int
    @ObservedObject private var center = GameCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var replying: Bool {
        guard let challenge = center.challenge else { return false }
        return score > challenge.target
    }

    var body: some View {
        if score > 0 && !replying {
            let board = center.challengeBoard(for: .sniper)
            let live = board.map { center.hasLiveChallenge(on: $0) } ?? false
            VStack(spacing: 4) {
                ChallengeFriendButton(board: board, screen: "sniper", message: SniperChallenge.message(score: score)) {
                    SniperChallengeCard(score: score)
                }
                .accessibilityIdentifier("sniper.challenge.friend")
                if live { liveButton }
            }
            .animation(reduceMotion ? nil : Motion.settle, value: live)
            .task { center.refreshChallenges() }
        }
    }

    private var liveButton: some View {
        Button {
            Haptics.shared.selection()
            center.showChallenges()
        } label: {
            Label("Live challenge", systemImage: "flag.checkered")
                .font(Typeface.label(13, relativeTo: .footnote))
                .foregroundStyle(Palette.amber)
                .lineLimit(1)
                .frame(minHeight: Metrics.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .transition(.adaptive(.opacity.combined(with: .scale(scale: 0.9)), reduceMotion: reduceMotion))
        .accessibilityHint(Text("Opens your Game Center challenges"))
        .accessibilityIdentifier("sniper.challenge.live")
    }
}

/// "Beat my score" for a song: its sleeve, the points of the take in gold, and the song's name. Only the score, never
/// a name of the player's.
struct SongChallengeCard: View {
    let title: String
    let art: CoverArt
    let points: Int
    let accent: Color

    var body: some View {
        ShareCardFrame(glow: accent, signature: true) {
            Label("Perform", systemImage: "music.mic").font(Typeface.label(12)).foregroundStyle(accent)
        } content: {
            SongCover(art: art, corner: 14)
                .frame(width: 200, height: 200)
                .shadow(color: art.primary.opacity(0.45), radius: 26, y: 14)
                .padding(.top, 4)
            VStack(spacing: 2) {
                Text("Beat my score").font(Typeface.display(34)).tracking(-0.8).foregroundStyle(Palette.ink)
                Text(points, format: .number).font(Typeface.number(64)).foregroundStyle(Palette.amber)
                    .shadow(color: Palette.amber.opacity(0.35), radius: 16)
            }
            Text(verbatim: title).font(.headline).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center).lineLimit(2)
        }
    }
}

// MARK: - Friend streak

/// "Streak #2 of 5 among friends" with the friends glyph, in the streak's flame colours.
struct FriendStreakLine: View {
    let standing: FriendStreak
    var size: CGFloat = 13

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill").font(.system(size: size - 1, weight: .bold)).foregroundStyle(Palette.flame)
                .accessibilityHidden(true)
            Text("Streak #\(standing.rank) of \(standing.total) among friends")
                .font(Typeface.label(size, relativeTo: .footnote))
                .foregroundStyle(Palette.flameInk)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(.horizontal, size)
        .frame(minHeight: size * 2.4)
        .background(Capsule().fill(Palette.flame.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }
}

/// Under the week card's figures: where the streak stands among friends once Game Center has them, or, while GameKit
/// may still ask, "Compare streaks with friends" (its own prompt, once). Nothing otherwise.
struct WeekFriendsRow: View {
    let standing: FriendStreak?
    @ObservedObject private var center = GameCenter.shared

    var body: some View {
        if let standing {
            FriendStreakLine(standing: standing)
                .transition(.opacity)
        } else if center.friendsAccess == .ask {
            Button {
                Haptics.shared.selection()
                center.askFriends()
            } label: {
                Label("Compare streaks with friends", systemImage: "person.2.fill")
                    .font(Typeface.label(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.mint)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(minHeight: Metrics.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("journey.week.friends")
        }
    }
}
