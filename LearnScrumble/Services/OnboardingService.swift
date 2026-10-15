//
//  OnboardingService.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-14.
//

import SwiftUI
import Observation

// MARK: - Flow of this file
// The logic behind the "How to play" tutorial (OnboardingView). It runs the REAL game screen (MainView)
// with ONE practice word — "cat" in the language being learned — in a practice WordVM, so the tutorial looks and
// behaves exactly like the game, but the answer is never saved to the user's progress (WordVM isPractice).
// It's created with the languages picked on the setup screen (RequestModel), so the instructions are in the
// user's own language (the app's locale) and the hint ("cat") too.
//
// One session, one small task at a time, so every button of the game screen gets used once:
// `instruction` says what to do (OnboardingView shows it in a tooltip next to the pointer),
// `pointerTarget` says where the pointer goes, and both change as soon as the task is done.
//   1. tap the first letter                             (pointer on that tile)
//   2. tap the LAST letter — it lands in the wrong slot on purpose
//   3. tap that wrong letter in the answer to send it back to the tray
//   4. tap ↻ to clear the whole answer
//   5. tap the lightbulb (hint)  6. tap the speaker  7. tap the settings gear
//   8. spell the whole word, letter by letter
//   9. "Correct!" -> "Let's go!" -> the tutorial is done (`completed`)
// The practice picture is the cat photo in the app bundle (ViewComponents/NewSVG/cat.png).
// A letter the user puts in the wrong slot at any time -> "send it back" first (pointer on that slot).
//
//   OnboardingView: answer changed -> answerChanged(), hint opened/closed -> hintToggled(_:), ↻ -> resetTapped(),
//                   speaker -> speakWord(), gear -> settingsTapped(), Skip / completed -> finish()
//   finish() saves seenKey ("hasSeenTutorial") -> RootView doesn't show the tutorial again
//   (Settings' "How to play" can still replay it).
//   Tiles, slots, ↻, the lightbulb and Next report where they are on screen through TutorialAnchorKey,
//   so OnboardingView can put the pointer on them (the real game ignores these).

/// Things on screen the tutorial's pointer can point at.
nonisolated enum TutorialTarget: Hashable {
  case tile(Int)                                   // a scrambled letter tile, by LetterModel id
  case slot(Int)                                   // an answer slot, by position
  case reset                                       // ↻ next to the answer: clears every placed letter
  case hint                                        // the lightbulb on the picture
  case next                                        // Next on the right/wrong screen
  case speaker                                     // the tutorial's speaker button (top right, like the game)
  case settings                                    // the tutorial's settings gear (top left, like the game)
}

/// Collects where each TutorialTarget is on screen (MainView, GuessedLettersRow, ResultWordRow, ImageComponent,
/// AnswerResultView and OnboardingView report theirs); OnboardingView reads them to place the pointer.
nonisolated struct TutorialAnchorKey: PreferenceKey {
  static var defaultValue: [TutorialTarget: Anchor<CGRect>] { [:] }
  static func reduce(value: inout [TutorialTarget: Anchor<CGRect>], nextValue: () -> [TutorialTarget: Anchor<CGRect>]) {
    value.merge(nextValue()) { $1 }
  }
}

@Observable
final class OnboardingService {
  enum Instruction: Equatable {                     // the current task; OnboardingView turns it into tooltip text
    case startWith(String)                          // the word's first letter
    case wrongOnPurpose(String)                     // tap this letter: it goes in the wrong slot on purpose
    case sendBack                                   // tap the wrong letter in the answer to send it back
    case reset                                      // tap ↻ to clear the answer
    case hint                                       // tap the lightbulb
    case speaker                                    // tap the speaker
    case settings                                   // tap the settings gear
    case spellWord(String)                          // spell the whole word now, starting with this letter
    case now(String)                                // the next letter
    case finish                                     // "Correct!" screen: tap "Let's go!" to start playing
  }

  static let seenKey = "hasSeenTutorial"            // UserDefaults key: true once the tutorial was finished or skipped

  private(set) var vm: WordVM                       // the practice game MainView shows
  private(set) var completed = false                // Next tapped on "Correct!": OnboardingView finishes the tutorial
  private(set) var mistakeMade = false              // task 2 done: a letter went into a wrong slot
  private(set) var sentBack = false                 // task 3 done: the wrong letter was sent back
  private(set) var resetUsed = false                // task 4 done: ↻ was tapped
  private(set) var hintSeen = false                 // task 5 done: the hint was opened
  private(set) var hintOpen = false                 // the hint popover is on screen: no pointer meanwhile
  private(set) var wordHeard = false                // task 6 done: the speaker was tapped
  private(set) var settingsSeen = false             // task 7 done: the gear was tapped
  @ObservationIgnored private let word: String      // the practice word, e.g. "kot"
  @ObservationIgnored private let wordLanguage: String   // its language code, for the speaker voice
  @ObservationIgnored private let answer: [String]  // the word's letters, lowercased like WordVM's
  @ObservationIgnored private let speech = SpeechManager()   // reads the word for the speaker task

  var wrongSlot: Int? {                                                // first placed letter in the wrong slot
    vm.guessedWord.indices.first { vm.guessedWord[$0] != nil && vm.guessedWord[$0]?.letter != answer[$0] }
  }

  private var nextSlot: Int? { vm.guessedWord.firstIndex { $0 == nil } }   // first empty slot

  var instruction: Instruction {                                       // the current task, shown in the tooltip
    if vm.guessResult != nil { return .finish }                       // "Correct!" screen: last tap
    if wrongSlot != nil { return .sendBack }                          // any wrong letter: send it back first
    if !mistakeMade {                                                  // tasks 1–2: first letter, then the wrong one
      return nextSlot == 0 ? .startWith(answer[0]) : .wrongOnPurpose(answer[answer.count - 1])
    }
    if !resetUsed { return .reset }
    if !hintSeen { return .hint }
    if !wordHeard { return .speaker }
    if !settingsSeen { return .settings }
    guard let slot = nextSlot else { return .now(answer.last ?? "") }  // task 8: spell it
    return slot == 0 ? .spellWord(answer[0]) : .now(answer[slot])
  }

  var pointerTarget: TutorialTarget? {                                 // where the pointer goes for that task
    if hintOpen { return nil }                                        // the hint bubble is open: nothing to point at
    switch instruction {
    case .finish:   return .next
    case .sendBack: return wrongSlot.map { .slot($0) }
    case .reset:    return .reset
    case .hint:     return .hint
    case .speaker:  return .speaker
    case .settings: return .settings
    case .startWith(let letter), .wrongOnPurpose(let letter), .spellWord(let letter), .now(let letter):
      return vm.scrumbledWord.first { !$0.isUsed && $0.letter == letter }.map { .tile($0.id) }   // that letter's tile
    }
  }

  // MARK: - init
  // Takes the languages from the setup screen: the practice word comes in the language being learned
  // (English "cat" when that language's word doesn't make 3 usable tiles), the hint in the user's own language.
  // The WordVM needs `self` for its checkpoint callback, so an empty placeholder is set first.
  // The game: the word with the cat drawing, one checkpoint after it (.endOfSession), nothing saved (isPractice).
  init(native: Languages, target: Languages) {
    let practice = Self.practiceWord(for: target)
    word = practice.word
    wordLanguage = practice.language
    answer = practice.word.lowercased().map { String($0) }
    let hint = String(localized: LocalizedStringResource("cat", locale: native.locale))
    vm = WordVM(questions: [], targetLanguage: target.rawValue, isPractice: true)
    vm = WordVM(
      questions: [QuestionModel(id: "practice-cat",
                                word: WordModel(toolName: "cat", originWord: hint, targetWord: practice.word, imagePrompt: ""),
                                imageData: Self.catImage())],
      targetLanguage: target.rawValue,
      checkpointMode: .endOfSession,
      onCheckpoint: { [weak self] in self?.completed = true },
      isPractice: true
    )
  }

  // MARK: - answerChanged
  // Called by OnboardingView whenever the answer changes (a letter placed or taken back).
  // A letter in a wrong slot -> task 2 is done; that wrong slot fixed afterwards -> task 3 is done.
  func answerChanged() {
    if wrongSlot != nil {
      mistakeMade = true
    } else if mistakeMade {
      sentBack = true
    }
  }

  // MARK: - resetTapped
  // ↻ next to the answer was tapped (ResultWordRow -> MainView -> OnboardingView; MainView already cleared the answer).
  // Only counts after the mistake was made and sent back, so the tasks stay in order.
  func resetTapped() {
    if sentBack { resetUsed = true }
  }

  // MARK: - hintToggled(_:)
  // The hint popover opened or closed (ImageComponent -> MainView -> OnboardingView).
  // While it's open the pointer hides; once opened (after ↻), the next task is the speaker,
  // shown after the user closes the hint by tapping anywhere.
  func hintToggled(_ open: Bool) {
    hintOpen = open
    if open && resetUsed { hintSeen = true }
  }

  // MARK: - speakWord
  // The speaker: reads the practice word with the learning language's voice. After the hint -> next task: the gear.
  func speakWord() {
    speech.speak(word, language: wordLanguage)
    if hintSeen { wordHeard = true }
  }

  // MARK: - settingsTapped
  // The tutorial's gear: it only explains Settings (it doesn't leave the tutorial). After the speaker -> spell the word.
  func settingsTapped() {
    if wordHeard { settingsSeen = true }
  }

  // MARK: - finish
  // Next on "Correct!" or Skip: remembers the tutorial as seen, so RootView doesn't show it again.
  func finish() {
    UserDefaults.standard.set(true, forKey: Self.seenKey)
  }

  // MARK: - practiceWord(for:)
  // "Cat" in the language being learned, with its language code for the speaker.
  // Falls back to English "cat" when the word has fewer than 3 tiles (scripts that join letters, like Hindi or Tamil),
  // or when its last letter equals its 2nd (task 2's letter would then be right, not wrong).
  private static func practiceWord(for language: Languages) -> (word: String, language: String) {
    let code = language.rawValue
    let key = code.hasPrefix("zh-TW") ? "zh-TW" : String(code.split(separator: "-").first ?? "en")
    guard let word = catWords[key] else { return ("cat", "en-US") }
    let letters = word.lowercased().map { String($0) }
    guard letters.count >= 3, letters[letters.count - 1] != letters[1] else { return ("cat", "en-US") }
    return (word, code)
  }

  private static let catWords: [String: String] = [              // "cat" per language code
    "sq": "mace", "ar": "قطة", "as": "মেকুৰী", "eu": "katu", "ca": "gat", "gl": "gato",
    "bn": "বিড়াল", "gu": "બિલાડી", "hi": "बिल्ली", "kn": "ಬೆಕ್ಕು", "ml": "പൂച്ച", "mr": "मांजर",
    "ne": "बिरालो", "or": "ବିରାଡି", "pa": "ਬਿੱਲੀ", "ta": "பூனை", "te": "పిల్లి", "bg": "котка",
    "zh": "小猫咪", "zh-TW": "小貓咪", "yue": "小貓咪", "wuu": "小猫咪", "hr": "mačka", "cs": "kočka",
    "da": "kat", "nl": "kat", "en": "cat", "fa": "گربه", "fi": "kissa", "fr": "chat", "de": "Katze",
    "el": "γάτα", "he": "חתול", "hu": "macska", "id": "kucing", "it": "gatto", "ja": "こねこ", "kk": "мысық",
    "ko": "고양이", "lt": "katė", "ms": "kucing", "nb": "katt", "pl": "kot", "pt": "gato", "ro": "pisică",
    "ru": "кошка", "sk": "mačka", "sl": "mačka", "es": "gato", "sv": "katt", "th": "แมว", "tr": "kedi",
    "uk": "кіт", "vi": "mèo"
  ]

  // MARK: - catImage
  // The practice picture: cat.png from the app bundle (added in ViewComponents/NewSVG), as raw PNG bytes —
  // the same kind of data a real word's picture is. Missing file -> nil (the picture card shows its placeholder).
  private static func catImage() -> Data? {
    Bundle.main.url(forResource: "cat", withExtension: "png").flatMap { try? Data(contentsOf: $0) }
  }
}
