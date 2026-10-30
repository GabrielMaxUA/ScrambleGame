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
//   Cards: CabinetVM.cards — one per profession + language being learned (CabinetCardView), the current one first.
//   -> tap a card -> onCard -> RootView: CabinetVM.select makes it the current job + language, then
//      bought -> MyWordsView ("Continue learning" / "Repeat all"); free words left -> a game; used up -> PaywallView
//   -> gear (top) -> onSettings -> AppManager.openSettings() (languages and job can still be changed there)
//   No card yet (no job picked) -> a note pointing to Settings.

struct WelcomeBackView: View {
  @Environment(\.topButtonsPadding) private var topButtons          // iPhone Duo: where the gear sits (RootView)
  let cabinet: CabinetVM                         // the cards and what a tap does
  let targetLanguage: String                     // current language being learned — the owl's mood
  var onCard: (CabinetVM.Card) -> Void           // a card was tapped (RootView -> CabinetVM.select)
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
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(cards) { card in
              CabinetCardView(card: card, freeWordsLeft: cabinet.freeWordsLeft) { onCard(card) }
            }
          }
          .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)

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
                  onCard: { _ in }, onSettings: {})
}
