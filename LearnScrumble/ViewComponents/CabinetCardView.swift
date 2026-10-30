//
//  CabinetCardView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-30.
//

import SwiftUI

// MARK: - Flow of this file
// One card in WelcomeBackView's wallet-style stack (CabinetVM.Card).
//   Top strip (always visible, also when the next card overlaps the rest): the language being learned as the title,
//   the profession under it, and the learned words — or a lock — in the trailing corner. Tapping it -> onOpen.
//   Open (isOpen): the score — learned, right, wrong — the words played and, if not bought, the free words left,
//   then the buttons, one under the other:
//     Continue learning -> onContinue (a game) · My words -> onWordList (bought, after the first word)
//     Unlock -> onUnlock (not bought and the free words are used up)
//     My words with a lock -> onUnlock (not bought, but words played: the list exists, the unlock opens it)
// Solid colors (not see-through), by the card's place in the stack, so neighbouring cards always differ and don't
// show through. The stack order never changes (CabinetVM: date added), so a card keeps its color.

struct CabinetCardView: View {
  @Environment(\.locale) private var locale              // the app's language, for the language's name
  let card: CabinetVM.Card
  let isOpen: Bool                                       // pulled out of the stack: shows the score and buttons
  let freeWordsLeft: Int                                 // shown on cards that aren't bought
  var onOpen: () -> Void                                 // the top strip was tapped
  var onContinue: () -> Void                             // "Continue learning"
  var onWordList: () -> Void                             // "My words"
  var onUnlock: () -> Void                               // "Unlock"

  static let stripHeight: CGFloat = 88                   // the strip; the next card covers its lowest 22 pt (WelcomeBackView)

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onOpen) { strip }
        .buttonStyle(.plain)
      if isOpen {
        details
          .padding(.horizontal, 16)
          .padding(.bottom, 16)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(background, in: RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(.white.opacity(card.isCurrent ? 0.55 : 0.18), lineWidth: card.isCurrent ? 1.5 : 1)
    }
    .shadow(color: .black.opacity(0.55), radius: 10, y: -4)   // the edge of the card in front shows on the one behind
  }

  // MARK: - strip
  // Title, profession and the corner (learned words or lock). Fixed height, content at the top: when the next card
  // overlaps the lower part, the text stays readable.
  private var strip: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(verbatim: card.language.name(in: locale))   // title: the language being learned
          .font(.headline)
          .foregroundStyle(.white)
          .singleLine()
        Label { Text(card.job.displayName) } icon: { Image(systemName: "briefcase") }   // the profession
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.8))
          .singleLine()
      }
      Spacer(minLength: 8)
      if card.isLocked {
        Image(systemName: "lock.fill")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.85))
          .accessibilityLabel(Text("Locked"))
      } else {
        HStack(spacing: 4) {
          Image(systemName: "star.fill")
            .font(.caption)
            .foregroundStyle(.yellow)
          Text(card.learned, format: .number)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Learned: \(card.learned)"))
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 14)
    .padding(.bottom, isOpen ? 12 : 0)
    .frame(height: isOpen ? nil : Self.stripHeight, alignment: .top)   // in the stack: room for the next card's overlap
    .contentShape(Rectangle())
  }

  // MARK: - details
  // The open card: score, words played / free words left, buttons.
  private var details: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 0) {
        number(card.learned, title: "Learned", icon: "star.fill", tint: .yellow)
        number(card.correct, title: "Right", icon: "checkmark.circle.fill", tint: .green)
        number(card.incorrect, title: "Wrong", icon: "xmark.circle.fill", tint: .red)
      }
      .padding(.vertical, 10)
      .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))

      HStack {
        Label { Text("My words: \(card.played)") } icon: { Image(systemName: "list.bullet.rectangle") }
          .singleLine()
        Spacer(minLength: 8)
        if !card.isOwned && !card.isLocked {
          Text("\(freeWordsLeft) free words left")
            .foregroundStyle(.green)
            .singleLine()
        }
      }
      .font(.footnote.weight(.semibold))
      .foregroundStyle(.white.opacity(0.8))

      VStack(spacing: 8) {                               // one under the other, full width: the main one on top
        if card.isLocked {
          button("Unlock", icon: "lock.open.fill", prominent: true, action: onUnlock)
        } else {
          button("Continue learning", icon: "arrow.right", prominent: true, action: onContinue)
        }
        if card.played > 0 {                             // the list exists: open it, or show it's part of the unlock
          if card.isOwned {
            button("My words", icon: "list.bullet.rectangle", prominent: false, action: onWordList)
          } else {
            button("My words", icon: "lock.fill", prominent: false, action: onUnlock)
          }
        }
      }
    }
  }

  // MARK: - number(_:title:icon:tint:)
  // One score column: a coloured icon, the number, its title.
  private func number(_ value: Int, title: LocalizedStringKey, icon: String, tint: Color) -> some View {
    VStack(spacing: 3) {
      Image(systemName: icon)
        .foregroundStyle(tint)
      Text(value, format: .number)
        .font(.system(size: 24, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .monospacedDigit()
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))
        .singleLine()
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }

  // MARK: - button(_:icon:prominent:action:)
  // A card button: white (the main one) or see-through.
  private func button(_ title: LocalizedStringKey, icon: String, prominent: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label(title, systemImage: icon)
        .font(.subheadline.weight(.semibold))
        .singleLine()
        .foregroundStyle(prominent ? .black : .white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.15)), in: Capsule())
    }
    .buttonStyle(.plain)
  }

  // MARK: - background
  // A solid dark card tinted with the profession's color.
  private var background: some ShapeStyle {
    LinearGradient(colors: [tint.mix(with: .black, by: 0.45), tint.mix(with: .black, by: 0.7)],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  private var tint: Color {                              // by place in the stack: neighbours always differ
    let palette: [Color] = [.blue, .teal, .indigo, .purple, .pink, .orange, .green, .cyan, .brown, .red, .mint]
    return palette[card.colorIndex % palette.count]
  }
}

#Preview {
  VStack(spacing: -18) {
    CabinetCardView(card: .init(job: .cook, language: .englishUS, learned: 23, played: 40, correct: 70, incorrect: 12,
                                isOwned: true, isCurrent: false, isLocked: false, added: .now),
                    isOpen: false, freeWordsLeft: 0, onOpen: {}, onContinue: {}, onWordList: {}, onUnlock: {})
    CabinetCardView(card: .init(job: .plumber, language: .polish, learned: 2, played: 6, correct: 8, incorrect: 3,
                                isOwned: false, isCurrent: false, isLocked: true, added: .now),
                    isOpen: false, freeWordsLeft: 0, onOpen: {}, onContinue: {}, onWordList: {}, onUnlock: {})
    CabinetCardView(card: .init(job: .baker, language: .ukrainian, learned: 3, played: 10, correct: 15, incorrect: 4,
                                isOwned: true, isCurrent: true, isLocked: false, added: .now),
                    isOpen: true, freeWordsLeft: 4, onOpen: {}, onContinue: {}, onWordList: {}, onUnlock: {})
  }
  .padding()
  .frame(maxHeight: .infinity)
  .background(.black)
}
