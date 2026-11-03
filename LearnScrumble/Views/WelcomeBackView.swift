//
//  WelcomeBackView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI

// MARK: - Flow of this file
// The returning user's start screen (phase .welcomeBack): the user's "cabinet".
//   Header: "Welcome back!", the streak (🔥 days in a row) and the owl (celebrates at 80% or more in the current language).
//   Top level (CabinetVM.section nil, only when a card can take a test — CabinetVM.hasSpeechTest / hasListeningTest):
//     the section cards, each with a ring of its score (all languages together):
//       My vocabulary      -> section .vocabulary — ring: right answers out of all answers in the game
//       Pronunciation test -> section .speech     — ring: words said right on the first try out of all tests
//                             (only when a card's language can be recognised)
//       Listening test     -> section .listening  — ring: right pictures out of all tests
//                             (only when a card has at least 4 words with a picture)
//   A section (or no top level at all: straight to the vocabulary stack, as before):
//     the cards — one per profession + language (CabinetCardView), stacked like a wallet: oldest at the top, each
//     newer card overlapping the one above so only its top strip shows. One card is open (pulled out, full height, with
//     its score and buttons); the current one when the screen appears. The speech section shows only languages that
//     can be tested, with the speech numbers; the listening section only cards with 4+ pictures, with its numbers.
//     -> tap a card's strip -> it opens (the open one closes) -> onOpen -> CabinetVM.select: the current job + language
//     -> its buttons -> RootView: Continue learning -> a game; My words -> MyWordsView; Unlock -> PaywallView;
//        Practise pronunciation -> MyWordsView in .speech; Practise listening -> MyWordsView in .listening
//     -> back arrow (top left, instead of the gear) -> the top level
//   -> gear (top, top level / no sections) -> onSettings -> AppManager.openSettings()
//   Folded iPhone Duo (topButtonsPadding.isFolded): the outer screen keeps its camera, clock and Wi-Fi ring in a column
//   on the right, which iOS reserves as safe area. The screen uses the full width anyway (the column only takes the
//   top, and the cards start below it), and the gear / back arrow sits in that column, under the Wi-Fi ring.
//   No card yet (no job picked) -> a note pointing to Settings.

struct WelcomeBackView: View {
  @Environment(\.topButtonsPadding) private var topButtons          // iPhone Duo: where the gear sits (RootView)
  @Environment(\.layoutDirection) private var layoutDirection     // kept for everything but the folded Duo's gear
  let cabinet: CabinetVM                         // the cards, the open section and what a tap does
  let targetLanguage: String                     // current language being learned — the owl's mood
  var onOpen: (CabinetVM.Card) -> Void           // a card was opened (RootView -> CabinetVM.select)
  var onContinue: (CabinetVM.Card) -> Void       // its "Continue learning"
  var onWordList: (CabinetVM.Card) -> Void       // its "My words"
  var onUnlock: (CabinetVM.Card) -> Void         // its "Unlock"
  var onSpeech: (CabinetVM.Card) -> Void = { _ in }   // its "Practise pronunciation"
  var onListening: (CabinetVM.Card) -> Void = { _ in }   // its "Practise listening"
  @State private var openID: String?             // the open card; nil = the current one (or the newest)

  private static let overlap: CGFloat = 22       // how much of a card's bottom the next card covers
  var onSettings: () -> Void                     // opens SettingsView (free for everyone)

  private var isCelebrating: Bool {              // the owl: 80% or more right in the current language
    let stat = PersistenceController.shared.overallAccuracy(targetLanguage: targetLanguage)
    return stat.total > 0 && Double(stat.correct) / Double(stat.total) >= 0.8
  }

  var body: some View {
    let all = cabinet.cards                      // read once per redraw (SwiftData fetches)
    let hasSections = cabinet.hasSpeechTest(in: all) || cabinet.hasListeningTest(in: all)
    let section: CabinetVM.Section? = hasSections ? cabinet.section : .vocabulary
    let cards = switch section {
    case .speech: all.filter(\.canTestSpeech)
    case .listening: all.filter(\.canTestListening)
    default: all
    }
    let streak = Streak.shared.current

    VStack(spacing: 16) {
      VStack(spacing: 8) {
        LineOwl(isCelebrating: isCelebrating)
        Text("Welcome back!")
          .font(.largeTitle.bold())
          .foregroundStyle(.white)
        Text(subtitle(section, hasSections: hasSections))
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
        if streak > 0 {
          Label { Text(streak, format: .number) } icon: { Image(systemName: "flame.fill") }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.orange.opacity(0.15), in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Days in a row: \(streak)"))
        }
      }
      .multilineTextAlignment(.center)
      .padding(.top, isFolded ? 16 : 48)         // below the gear (folded Duo: the gear is in the side column)

      if all.isEmpty {
        Spacer()
        Text("Pick your profession in Settings to start learning.")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
        Spacer()
      } else if let section {
        VStack(spacing: 16) { stack(cards, section: section) }
          .id(section)                          // a fresh stack (and scroll position) per section
          .transition(.opacity)
      } else {
        sections(all)
          .transition(.opacity)
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea(.container, edges: isFolded ? .horizontal : [])   // folded Duo: under the side column too
    .overlay { topButton(inSection: hasSections && section != nil) }
    .background(Color.black.opacity(0.92))
  }

  // MARK: - subtitle(_:hasSections:)
  private func subtitle(_ section: CabinetVM.Section?, hasSections: Bool) -> LocalizedStringKey {
    guard hasSections else { return "Ready for more words?" }
    switch section {
    case nil: return "What would you like to practise?"
    case .vocabulary: return "My vocabulary"
    case .speech: return "Pronunciation test"
    case .listening: return "Listening test"
    }
  }

  // MARK: - sections(_:)
  // The top level: the section cards (a test only when a card can take it), then room below.
  private func sections(_ cards: [CabinetVM.Card]) -> some View {
    VStack(spacing: 14) {
      SectionCard(title: "My vocabulary", detail: "Your words, by profession and language.",
                  icon: "text.book.closed.fill", tint: .blue,
                  score: cabinet.vocabularyScore, scoreLabel: "Right answers") {
        open(.vocabulary)
      }
      if cabinet.hasSpeechTest(in: cards) {
        SectionCard(title: "Pronunciation test", detail: "Say your words out loud and check them.",
                    icon: "mic.fill", tint: .teal,
                    score: cabinet.speechScore(in: cards), scoreLabel: "Right on the first try") {
          open(.speech)
        }
      }
      if cabinet.hasListeningTest(in: cards) {
        SectionCard(title: "Listening test", detail: "Hear a word and tap its picture.",
                    icon: "headphones", tint: .purple,
                    score: cabinet.listeningScore, scoreLabel: "Right answers") {
          open(.listening)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.top, 8)
  }

  private func open(_ section: CabinetVM.Section?) {
    openID = nil
    withAnimation(.easeInOut(duration: 0.25)) { cabinet.section = section }
  }

  // MARK: - stack(_:section:)
  // One section's cards, stacked like a wallet (see the flow above).
  @ViewBuilder
  private func stack(_ cards: [CabinetVM.Card], section: CabinetVM.Section) -> some View {
    let open = openID.flatMap { id in cards.first { $0.id == id }?.id } ?? (cards.first(where: \.isCurrent) ?? cards.last)?.id
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 0) {                     // later cards are drawn on top: newer overlaps older
          ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
            let isOpen = card.id == open
            let isLast = index == cards.count - 1
            CabinetCardView(card: card, isOpen: isOpen, freeWordsLeft: cabinet.freeWordsLeft,
                            onOpen: {
                              withAnimation(.spring(duration: 0.35)) { openID = card.id }
                              onOpen(card)
                            },
                            onContinue: { onContinue(card) },
                            onWordList: { onWordList(card) },
                            onUnlock: { onUnlock(card) },
                            mode: section,
                            onSpeech: { onSpeech(card) },
                            onListening: { onListening(card) })
              .padding(.bottom, isLast ? 0 : (isOpen ? 14 : -Self.overlap))   // open: the next card waits below it
              .zIndex(Double(index))
              .id(card.id)
          }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
      }
      .scrollIndicators(.hidden)
      .onAppear { if let open { proxy.scrollTo(open, anchor: .top) } }
      .onChange(of: openID) { _, id in                // after the open animation, so the whole card is in view
        guard let id else { return }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(350))
          withAnimation { proxy.scrollTo(id, anchor: .top) }
        }
      }
    }

    Group {
      switch section {
      case .speech: Text("A word counts as right when you say it right on the first try. You get 3 tries.")
      case .listening: Text("Listen to the word and tap its picture. Your first tap counts.")
      case .vocabulary: Text("A word is learned once you get it right at least twice, and 3 times out of 4.")
      }
    }
      .font(.footnote)
      .foregroundStyle(.white.opacity(0.6))
      .multilineTextAlignment(.center)
  }

  // MARK: - topButton(inSection:)
  // Top left: the gear (top level, or no sections), or the back arrow to the top level inside a section.
  private var isFolded: Bool { topButtons?.isFolded == true }

  private func topButton(inSection: Bool) -> some View {
    let size: CGFloat = topButtons?.isFolded == true ? 40 : 44     // folded Duo: smaller
    return Button {
      if inSection { open(nil) } else { onSettings() }
    } label: {
      Image(systemName: inSection ? "chevron.backward" : "gear")
        .font(.title3)
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .contentTransition(.symbolEffect(.replace))
    }
    .glassCompat(in: .circle, interactive: true)
    .accessibilityLabel(Text(inSection ? "Back" : "Settings"))
    .padding(.horizontal, isFolded ? Self.foldedColumnInset : (topButtons?.horizontal ?? 20))   // iPhone Duo: like the in-game button
    .padding(.top, isFolded ? Self.foldedColumnTop : (topButtons?.top ?? 8))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isFolded ? .topTrailing : .topLeading)
    .ignoresSafeArea(.container, edges: isFolded ? .all : [])
    .environment(\.layoutDirection, isFolded ? .leftToRight : layoutDirection)   // the column is on the physical right
  }

  // Folded Duo: the gear sits in the side column, centred under the camera and the Wi-Fi ring (whose bottom is about
  // 150 pt down; the column's centre is about 48 pt in from the right edge, so 48 − 40 / 2).
  private static let foldedColumnInset: CGFloat = 28
  private static let foldedColumnTop: CGFloat = 162
}

// MARK: - SectionCard
// One card on the cabinet's top level: icon, title, a line about it, and a ring with its score (— before any score)
// with what it counts written under it.
private struct SectionCard: View {
  let title: LocalizedStringKey
  let detail: LocalizedStringKey
  let icon: String
  let tint: Color
  let score: Double?                                     // 0...1; nil = nothing yet
  let scoreLabel: LocalizedStringKey                     // what the ring counts
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Label { Text(title) } icon: { Image(systemName: icon) }
            .font(.title3.bold())
            .foregroundStyle(.white)
            .singleLine()
          Text(detail)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        VStack(spacing: 6) {                             // the ring and, under it, what it counts
          ScoreRing(score: score, tint: tint)
          Text(scoreLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 92)
        Image(systemName: "chevron.forward")
          .font(.footnote.weight(.bold))
          .foregroundStyle(.white.opacity(0.5))
      }
      .padding(18)
      .background(LinearGradient(colors: [tint.mix(with: .black, by: 0.45), tint.mix(with: .black, by: 0.72)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                  in: RoundedRectangle(cornerRadius: 20))
      .overlay { RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2), lineWidth: 1) }
      .contentShape(RoundedRectangle(cornerRadius: 20))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
  }
}

// MARK: - ScoreRing
// A ring filled to the score with the percentage inside; "—" before any score. Fills in once when it appears.
private struct ScoreRing: View {
  let score: Double?
  let tint: Color
  @State private var shown: Double = 0                   // animates from 0 to the score

  var body: some View {
    ZStack {
      Circle().stroke(.white.opacity(0.15), lineWidth: 7)
      Circle()
        .trim(from: 0, to: shown)
        .stroke(tint.mix(with: .white, by: 0.25), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Group {
        if let score {
          Text(score, format: .percent.precision(.fractionLength(0)))
        } else {
          Text(verbatim: "—")
        }
      }
      .font(.subheadline.weight(.bold))
      .foregroundStyle(.white)
      .monospacedDigit()
      .minimumScaleFactor(0.7)
    }
    .frame(width: 62, height: 62)
    .onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.15)) { shown = score ?? 0 } }
    .onChange(of: score) { _, new in withAnimation(.easeOut(duration: 0.5)) { shown = new ?? 0 } }
  }
}

#Preview {
  WelcomeBackView(cabinet: CabinetVM(requestModel: RequestModel()), targetLanguage: "en-US",
                  onOpen: { _ in }, onContinue: { _ in }, onWordList: { _ in }, onUnlock: { _ in }, onSettings: {})
}
