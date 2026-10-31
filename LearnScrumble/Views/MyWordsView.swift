//
//  MyWordsView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import SwiftUI
import SwiftData

// MARK: - Flow of this file
// "My words" (phase .wordList, unlocked jobs only): every word played for the current job in this language,
// weakest first, with its picture and how often it was answered right and wrong.
//   Reads PersistenceController.jobWords — everything is on the phone, so it works offline and opens instantly.
//   -> tap a row -> the row's picture grows into WordCardOverlay: big picture, word, hint, speaker, report flag,
//      swipe for the next word; the speaker reads it; ✕ / tap outside shrinks it back into the
//      row of the word on the front card (the list scrolls to it first)
// The list is read once when the screen opens (not on every redraw: opening and swiping redraw it), and the pictures
// are decoded once (WordImages, shared with the cards).
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
  var onReport: (SwiftDataWordModel) async -> RequestModel.ReportResult = { _ in .failed }   // the card's flag
  var onBack: () -> Void                                 // back to WelcomeBackView
  @State private var speechManager = SpeechManager()     // reads the word on the card
  @State private var openIndex: Int?                     // the word shown on WordCardOverlay; nil = closed
  @State private var heroID: PersistentIdentifier?       // the word whose picture is on the card (its row shows a gap)
  @State private var scrolledID: PersistentIdentifier?   // scrolls the list to the front word before the card closes
  @State private var words: [SwiftDataWordModel]         // weakest first; read once, when the screen opens
  @State private var images = WordImages()               // decoded pictures, shared with the cards
  @Namespace private var pictures                        // a row's picture <-> the card's picture

  init(job: Occupation?, targetLanguage: String, onContinue: @escaping () -> Void, onRepeat: @escaping () -> Void,
       onReport: @escaping (SwiftDataWordModel) async -> RequestModel.ReportResult = { _ in .failed },
       onBack: @escaping () -> Void) {
    self.job = job
    self.targetLanguage = targetLanguage
    self.onContinue = onContinue
    self.onRepeat = onRepeat
    self.onReport = onReport
    self.onBack = onBack
    _words = State(initialValue: PersistenceController.shared.jobWords(profession: job?.rawValue ?? "",
                                                                       targetLanguage: targetLanguage))
  }

  var body: some View {
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
        Text("Hardest words first. Tap a word to see it big.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)

        ScrollView {
          LazyVStack(spacing: 10) {
            ForEach(Array(words.enumerated()), id: \.element.persistentModelID) { index, word in
              Button {
                heroID = word.persistentModelID
                withAnimation(.spring(duration: 0.35)) { openIndex = index }
              } label: {
                row(word, isOpen: openIndex != nil && heroID == word.persistentModelID)
              }
              .buttonStyle(.plain)
            }
          }
          .scrollTargetLayout()
          .padding(.bottom, 8)
        }
        .scrollPosition(id: $scrolledID, anchor: .center)
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
    .overlay {                                           // the open word, over everything (also the back button)
      if let index = openIndex, words.indices.contains(index) {
        WordCardOverlay(words: words,
                        index: Binding(get: { openIndex ?? index }, set: { openIndex = $0 }),
                        heroID: heroID,
                        namespace: pictures,
                        images: images,
                        speak: { speechManager.speak($0, language: targetLanguage) },
                        onReport: onReport,
                        onClose: closeCard)
      }
    }
  }

  // MARK: - closeCard
  // The front word becomes the hero and the list scrolls to its row, without animation (both are behind the dark
  // overlay); a moment later the card closes and its picture flies back into that row.
  private func closeCard() {
    if let index = openIndex, words.indices.contains(index) {
      var instant = Transaction()
      instant.disablesAnimations = true
      withTransaction(instant) {
        heroID = words[index].persistentModelID
        scrolledID = words[index].persistentModelID
      }
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(40))      // let the new hero and the scroll land first
      withAnimation(.spring(duration: 0.35)) { openIndex = nil }
    }
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

  // MARK: - row(_:isOpen:)
  // One word: picture, the word being learned and its hint, a star once learned, then the right / wrong counts.
  // While its picture is on the card (the hero, same matchedGeometryEffect id) the row keeps an empty spot.
  private func row(_ word: SwiftDataWordModel, isOpen: Bool) -> some View {
    HStack(spacing: 12) {
      ZStack {
        if !isOpen {
          Group {
            if let image = images.image(for: word) {
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
          .matchedGeometryEffect(id: word.persistentModelID, in: pictures)
        }
      }
      .frame(width: 52, height: 52)
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
