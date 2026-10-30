//
//  CabinetCardView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-30.
//

import SwiftUI

// MARK: - Flow of this file
// One card on WelcomeBackView (CabinetVM.Card): the language being learned as the title, the profession under it,
// and the learned words in the trailing corner.
//   bought      -> learned words
//   not bought  -> learned words + "N free words left", or a lock once the free words are used up
//   current     -> a brighter border, so the user sees which one "Continue" continues
// The whole card is one button; WelcomeBackView passes the tap to CabinetVM.select through RootView.

struct CabinetCardView: View {
  @Environment(\.locale) private var locale              // the app's language, for the language's name
  let card: CabinetVM.Card
  let freeWordsLeft: Int                                 // shown on cards that aren't bought
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(verbatim: card.language.name(in: locale))   // title: the language being learned
            .font(.headline)
            .foregroundStyle(.white)
            .singleLine()
          Label { Text(card.job.displayName) } icon: { Image(systemName: "briefcase") }   // the profession
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .singleLine()
          if !card.isOwned && !card.isLocked {
            Text("\(freeWordsLeft) free words left")
              .font(.caption)
              .foregroundStyle(.green.opacity(0.9))
          }
        }

        Spacer(minLength: 8)

        if card.isLocked {                               // trailing corner: the lock, or the learned words
          Image(systemName: "lock.fill")
            .font(.title2)
            .foregroundStyle(.white.opacity(0.8))
            .accessibilityLabel(Text("Locked"))
        } else {
          VStack(spacing: 2) {
            HStack(spacing: 4) {
              Image(systemName: "star.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
              Text(card.learned, format: .number)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            }
            Text("Learned")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white.opacity(0.6))
              .singleLine()
          }
          .accessibilityElement(children: .combine)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.white.opacity(card.isCurrent ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 14))
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(.white.opacity(card.isCurrent ? 0.5 : 0.2), lineWidth: card.isCurrent ? 1.5 : 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  VStack(spacing: 12) {
    CabinetCardView(card: .init(job: .cook, language: .englishUS, learned: 23, played: 40,
                                isOwned: true, isCurrent: true, isLocked: false), freeWordsLeft: 0, onTap: {})
    CabinetCardView(card: .init(job: .plumber, language: .englishUS, learned: 2, played: 6,
                                isOwned: false, isCurrent: false, isLocked: false), freeWordsLeft: 4, onTap: {})
    CabinetCardView(card: .init(job: .baker, language: .englishUS, learned: 3, played: 10,
                                isOwned: false, isCurrent: false, isLocked: true), freeWordsLeft: 0, onTap: {})
  }
  .padding()
  .frame(maxHeight: .infinity)
  .background(.black)
}
