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
// Pronunciation test (mode .speech, phase .speechList, from a Pronunciation test card): the same list, struggles
// first (PersistenceController.speechWords), with each word's speech numbers (✓ right on the first try, ↻ struggles);
// a tapped word opens WordCardOverlay in .speech (picture, word, Tap to speak). No Continue / Repeat buttons.
// Listening test (mode .listening, phase .listeningList, from a Listening test card): the job's words with a picture,
// misses first (PersistenceController.listeningWords), with each word's listening numbers (✓ right, ✗ wrong); a tapped
// word opens WordCardOverlay in .listening (4 pictures, the speaker). Its picture doesn't fly into the card: that
// would show which of the 4 it is.
// Both tests: "Test all (N)" at the bottom -> WordCardOverlay from the first word with testAll: it runs through every
// word by itself and ends with a summary.

struct MyWordsView: View {
  @Environment(\.locale) private var locale              // the app's language, for the language's name
  let job: Occupation?                                   // the job whose words are listed
  let targetLanguage: String                             // the language being learned (Languages.rawValue)
  let mode: CabinetVM.Section                            // .vocabulary: My words; .speech / .listening: the tests
  var onContinue: () -> Void                             // new words for this job and language
  var onRepeat: () -> Void                               // start the review
  var onReport: (SwiftDataWordModel) async -> RequestModel.ReportResult = { _ in .failed }   // the card's flag
  var onBack: () -> Void                                 // back to WelcomeBackView
  @State private var speechManager = SpeechManager()     // reads the word on the card
  @State private var openIndex: Int?                     // the word shown on WordCardOverlay; nil = closed
  @State private var testingAll = false                  // the card was opened with "Test all"
  @State private var heroID: PersistentIdentifier?       // the word whose picture is on the card (its row shows a gap)
  @State private var scrolledID: PersistentIdentifier?   // scrolls the list to the front word before the card closes
  @State private var words: [SwiftDataWordModel]         // weakest first; read once, when the screen opens
  @State private var images = WordImages()               // decoded pictures, shared with the cards
  @Namespace private var pictures                        // a row's picture <-> the card's picture

  init(job: Occupation?, targetLanguage: String, mode: CabinetVM.Section = .vocabulary,
       onContinue: @escaping () -> Void, onRepeat: @escaping () -> Void,
       onReport: @escaping (SwiftDataWordModel) async -> RequestModel.ReportResult = { _ in .failed },
       onBack: @escaping () -> Void) {
    self.job = job
    self.targetLanguage = targetLanguage
    self.mode = mode
    self.onContinue = onContinue
    self.onRepeat = onRepeat
    self.onReport = onReport
    self.onBack = onBack
    let store = PersistenceController.shared
    let profession = job?.rawValue ?? ""
    let list: [SwiftDataWordModel] = switch mode {
    case .speech: store.speechWords(profession: profession, targetLanguage: targetLanguage)
    case .listening: store.listeningWords(profession: profession, targetLanguage: targetLanguage)
    case .vocabulary: store.jobWords(profession: profession, targetLanguage: targetLanguage)
    }
    _words = State(initialValue: list)
  }

  var body: some View {
    VStack(spacing: 16) {
      VStack(spacing: 4) {
        Text(title)
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
        Text(mode == .vocabulary ? "Words you play for this profession will appear here."
                                 : "Play a few words first, then come back to say them.")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
        Spacer()
        if mode == .vocabulary { continueButton }
      } else {
        Text(note)
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)

        ScrollView {
          LazyVStack(spacing: 10) {
            ForEach(Array(words.enumerated()), id: \.element.persistentModelID) { index, word in
              Button {
                open(at: index, testAll: false)
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

        if mode == .vocabulary {
          continueButton

          Button(action: onRepeat) {
            Label("Repeat all (\(words.count))", systemImage: "arrow.counterclockwise")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
          }
          .glassCompat(in: .capsule, interactive: true)
        } else {
          Button { open(at: 0, testAll: true) } label: {
            Label("Test all (\(words.count))", systemImage: "play.fill")
              .font(.headline)
              .foregroundStyle(.black)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(.white, in: Capsule())
          }
          .buttonStyle(.plain)
          .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        }
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
                        mode: mode,
                        language: Languages(rawValue: targetLanguage),
                        testAll: testingAll,
                        speak: { speechManager.speak($0, language: targetLanguage) },
                        onReport: onReport,
                        onClose: closeCard)
      }
    }
  }

  // MARK: - title / note
  private var title: LocalizedStringKey {
    switch mode {
    case .vocabulary: "My words"
    case .speech: "Pronunciation"
    case .listening: "Listening"
    }
  }

  private var note: LocalizedStringKey {
    switch mode {
    case .vocabulary: "Hardest words first. Tap a word to see it big."
    case .speech: "Hardest to say first. Tap a word, then say it out loud."
    case .listening: "Hardest to hear first. Tap a word, or test them all."
    }
  }

  // MARK: - open(at:testAll:)
  // A tapped row (one word) or "Test all" (from the first word). Listening: no hero, the picture stays in its row.
  private func open(at index: Int, testAll: Bool) {
    guard words.indices.contains(index) else { return }
    testingAll = testAll
    heroID = mode == .listening ? nil : words[index].persistentModelID
    withAnimation(.spring(duration: 0.35)) { openIndex = index }
  }

  // MARK: - closeCard
  // The front word becomes the hero and the list scrolls to its row, without animation (both are behind the dark
  // overlay); a moment later the card closes and its picture flies back into that row.
  private func closeCard() {
    if let index = openIndex, words.indices.contains(index), mode != .listening {
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
  // One word: picture, the word being learned and its hint, a star once learned, then the right / wrong counts
  // (.speech: no star; right on the first try / struggles).
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
          if mode == .vocabulary && word.isLearned {
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
        if mode == .speech {                             // the pronunciation test's numbers
          count(word.speechFirstTry, icon: "checkmark.circle.fill", tint: .green, label: "First try")
          count(word.speechStruggled, icon: "arrow.counterclockwise.circle.fill", tint: .orange, label: "Struggled")
        } else if mode == .listening {                   // the listening test's numbers
          count(word.listenRight, icon: "checkmark.circle.fill", tint: .green, label: "Right")
          count(word.listenWrong, icon: "xmark.circle.fill", tint: .red, label: "Wrong")
        } else {
          count(word.correct, icon: "checkmark.circle.fill", tint: .green, label: "Right")
          count(word.incorrect, icon: "xmark.circle.fill", tint: .red, label: "Wrong")
        }
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
