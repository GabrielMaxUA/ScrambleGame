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
//   Cards: CabinetVM.cards — one per profession + language being learned (CabinetCardView), stacked like a wallet:
//   oldest at the top, each newer card overlapping the one above so only its top strip shows. One card is open
//   (pulled out, full height, with its score and buttons); the current one when the screen appears.
//   -> tap a card's strip -> it opens (the open one closes) -> onOpen -> CabinetVM.select: the current job + language
//   -> its buttons -> RootView: Continue learning -> a game; My words -> MyWordsView; Unlock -> PaywallView
//   -> gear (top) -> onSettings -> AppManager.openSettings() (languages and job can still be changed there)
//   No card yet (no job picked) -> a note pointing to Settings.

struct WelcomeBackView: View {
  @Environment(\.topButtonsPadding) private var topButtons          // iPhone Duo: where the gear sits (RootView)
  let cabinet: CabinetVM                         // the cards and what a tap does
  let targetLanguage: String                     // current language being learned — the owl's mood
  var onOpen: (CabinetVM.Card) -> Void           // a card was opened (RootView -> CabinetVM.select)
  var onContinue: (CabinetVM.Card) -> Void       // its "Continue learning"
  var onWordList: (CabinetVM.Card) -> Void       // its "My words"
  var onUnlock: (CabinetVM.Card) -> Void         // its "Unlock"
  @State private var openID: String?             // the open card; nil = the current one (or the newest)

  private static let overlap: CGFloat = 22       // how much of a card's bottom the next card covers
  var onSettings: () -> Void                     // opens SettingsView (free for everyone)

  private var isCelebrating: Bool {              // the owl: 80% or more right in the current language
    let stat = PersistenceController.shared.overallAccuracy(targetLanguage: targetLanguage)
    return stat.total > 0 && Double(stat.correct) / Double(stat.total) >= 0.8
  }

  var body: some View {
    let cards = cabinet.cards                    // read once per redraw (SwiftData fetches)
    let streak = Streak.shared.current

    VStack(spacing: 16) {
      VStack(spacing: 8) {
        LineOwl(isCelebrating: isCelebrating)
        Text("Welcome back!")
          .font(.largeTitle.bold())
          .foregroundStyle(.white)
        Text("Ready for more words?")
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
      .padding(.top, 48)                         // below the gear

      if cards.isEmpty {
        Spacer()
        Text("Pick your profession in Settings to start learning.")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
        Spacer()
      } else {
        let open = openID ?? (cards.first(where: \.isCurrent) ?? cards.last)?.id
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
                                onUnlock: { onUnlock(card) })
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

        Text("A word is learned once you get it right at least twice, and 3 times out of 4.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {                                        // same place as the in-game gear
      Button(action: onSettings) {
        Image(systemName: "gear")
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: topButtons?.isFolded == true ? 40 : 44, height: topButtons?.isFolded == true ? 40 : 44)   // folded Duo: smaller
      }
      .glassCompat(in: .circle, interactive: true)
      .accessibilityLabel(Text("Settings"))
      .padding(.horizontal, topButtons?.horizontal ?? 20)   // iPhone Duo: like the in-game gear
      .padding(.top, topButtons?.top ?? 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(Color.black.opacity(0.92))
  }
}

#Preview {
  WelcomeBackView(cabinet: CabinetVM(requestModel: RequestModel()), targetLanguage: "en-US",
                  onOpen: { _ in }, onContinue: { _ in }, onWordList: { _ in }, onUnlock: { _ in }, onSettings: {})
}
