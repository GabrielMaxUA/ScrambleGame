//
//  MyWordsView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import SwiftUI

// MARK: - Flow of this file
// "My words" (phase .wordList, unlocked jobs only): every word played for the current job in this language,
// weakest first, with its picture and how often it was answered right and wrong.
//   Reads PersistenceController.jobWords — everything is on the phone, so it works offline and opens instantly.
//   -> tap a row -> SpeechManager reads the word aloud
//   -> "Continue learning" -> onContinue -> AppManager.startGame(): new words for this job and language
//   -> "Repeat all" -> onRepeat -> AppManager.startReview(): the same list as a game, in rounds of 10
//   -> back (top) -> onBack -> AppManager.exitToWelcome()
// Opened from a card on WelcomeBackView (CabinetVM) or from ResultView; the title shows the job and the language.

struct MyWordsView: View {
  @Environment(\.locale) private var locale              // the app's language, for the language's name
  let job: Occupation?                                   // the job whose words are listed
  let targetLanguage: String                             // the language being learned (Languages.rawValue)
  var onContinue: () -> Void                             // new words for this job and language
  var onRepeat: () -> Void                               // start the review
  var onBack: () -> Void                                 // back to WelcomeBackView
  @State private var speechManager = SpeechManager()     // reads a word when its row is tapped

  private var words: [SwiftDataWordModel] {              // weakest first
    PersistenceController.shared.jobWords(profession: job?.rawValue ?? "", targetLanguage: targetLanguage)
  }

  var body: some View {
    let words = words                                    // read once per redraw (it's a SwiftData fetch)

    VStack(spacing: 16) {
      VStack(spacing: 4) {
        Text("My words")
          .font(.largeTitle.bold())
          .foregroundStyle(.white)
        if let job {
          Text(job.displayName)
            .font(.title3)
            .foregroundStyle(.white.opacity(0.7))
        }
        if let language = Languages(rawValue: targetLanguage) {
          Text(verbatim: language.name(in: locale))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
        }
      }
      .multilineTextAlignment(.center)
      .padding(.top, 8)

      if words.isEmpty {
        Spacer()
        Text("Words you play for this profession will appear here.")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
        Spacer()
        continueButton
      } else {
        Text("Hardest words first. Tap a word to hear it.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)

        ScrollView {
          LazyVStack(spacing: 10) {
            ForEach(words) { word in
              Button {
                speechManager.speak(word.targetWord, language: targetLanguage)
              } label: {
                row(word)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)

        continueButton

        Button(action: onRepeat) {
          Label("Repeat all (\(words.count))", systemImage: "arrow.counterclockwise")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .glassCompat(in: .capsule, interactive: true)
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
    .padding(.top, 52)                                   // room for the back button
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .topLeading) {                   // same place as the gear on the welcome screen
      Button(action: onBack) {
        Image(systemName: "chevron.backward")
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: 44, height: 44)
      }
      .glassCompat(in: .circle, interactive: true)
      .accessibilityLabel(Text("Back"))
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
    .background(Color.black.opacity(0.92))
  }

  // MARK: - continueButton
  // "Continue learning": new words for this job and language (a normal game).
  private var continueButton: some View {
    Button(action: onContinue) {
      Label("Continue learning", systemImage: "arrow.right")
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
    .glassCompat(in: .capsule, interactive: true)
  }

  // MARK: - row(_:)
  // One word: picture, the word being learned and its hint, a star once learned, then the right / wrong counts.
  private func row(_ word: SwiftDataWordModel) -> some View {
    HStack(spacing: 12) {
      Group {
        if let image = word.image {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
        } else {
          Image(systemName: "photo")
            .foregroundStyle(.white.opacity(0.4))
        }
      }
      .frame(width: 52, height: 52)
      .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(verbatim: word.targetWord)
            .font(.headline)
            .foregroundStyle(.white)
          if word.isLearned {
            Image(systemName: "star.fill")
              .font(.caption)
              .foregroundStyle(.yellow)
              .accessibilityLabel(Text("Learned"))
          }
        }
        Text(verbatim: word.originWord)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.6))
      }
      .lineLimit(1)

      Spacer(minLength: 8)

      HStack(spacing: 10) {
        count(word.correct, icon: "checkmark.circle.fill", tint: .green, label: "Right")
        count(word.incorrect, icon: "xmark.circle.fill", tint: .red, label: "Wrong")
      }
    }
    .padding(10)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    .accessibilityElement(children: .combine)
  }

  // MARK: - count(_:icon:tint:label:)
  // A small coloured icon with a number, e.g. ✓ 3. VoiceOver: "Right, 3".
  private func count(_ value: Int, icon: String, tint: Color, label: LocalizedStringKey) -> some View {
    HStack(spacing: 3) {
      Image(systemName: icon)
        .foregroundStyle(tint)
        .accessibilityLabel(Text(label))
      Text(value, format: .number)
        .foregroundStyle(.white)
        .monospacedDigit()
    }
    .font(.subheadline.weight(.semibold))
  }
}

#Preview {
  MyWordsView(job: .plumber, targetLanguage: "uk-UA", onContinue: {}, onRepeat: {}, onBack: {})
}
