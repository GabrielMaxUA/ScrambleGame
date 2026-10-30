//
//  CabinetVM.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-30.
//

import Foundation
import Observation

// MARK: - Flow of this file
// The user's "cabinet" on WelcomeBackView: one card per profession + language being learned, stacked like a wallet.
// All the card logic lives here; WelcomeBackView draws `cards` and reports taps, RootView carries out the action.
//
// Which cards (cards):
//   1. Every job + language with saved words (PersistenceController.playedJobLanguages).
//   2. The current job + language from Settings, even before its first word (so a new pick shows up at once).
//   3. Every bought job that has no card yet, in the current language (bought, never played).
//   4. Every card added before (UserDefaults "cabinetAdded"): once a card is in the cabinet it stays, even when it was
//      only picked and never played and another card is current now.
//   Typed jobs ("Not listed?", hidden for now) and unknown languages are left out.
//   Each card: its score (PersistenceController.jobProgress), bought or not (Purchases), current or not, date added.
//   Order: by the date the card was added, oldest first — on screen the newest card sits at the bottom of the stack,
//   overlapping the older ones.
//
// Date added (addedDate): kept on the phone in UserDefaults "cabinetAdded" (card id -> time). The first time a card
// is seen it gets one: for a played pair the time of its earliest saved answer, otherwise "now" (picked in Settings,
// or bought). After that it never changes, so the order stays put.
//
// Tapping:
//   select(_:)  -> a card was opened: it becomes the current job + language — the same as picking them in Settings
//                  (RequestModel + UserDefaults "pickedProffession" / "pickedLanguage").
//   The open card's buttons (WelcomeBackView -> RootView): Continue learning -> a game; My words (bought) ->
//   MyWordsView; Unlock (locked: not bought, free words used up) -> PaywallView. Each selects the card first.
//
// Reads Purchases.shared and FreeAllowance.shared (both @Observable), so the cards redraw by themselves after a
// purchase or when the free words run out.

@Observable
final class CabinetVM {
  // MARK: - Card
  struct Card: Identifiable, Equatable {
    let job: Occupation                       // the profession
    let language: Languages                   // the language being learned
    let learned: Int                          // words learned for this job in this language (SwiftDataWordModel.isLearned)
    let played: Int                           // words played — "My words" length
    let correct: Int                          // all right answers for those words
    let incorrect: Int                        // all wrong answers for those words
    let isOwned: Bool                         // the job is bought (or the Debug unlock is on)
    let isCurrent: Bool                       // the job + language picked right now (Settings)
    let isLocked: Bool                        // not bought and the free words are used up -> lock, Unlock button
    let added: Date                           // when the card first appeared (see addedDate) — the stack order
    var colorIndex = 0                        // its place in the stack: neighbouring cards get different colors
    var id: String { "\(job.rawValue)|\(language.rawValue)" }
  }

  private let requestModel: RequestModel       // the current job + language live here
  private static let addedKey = "cabinetAdded" // UserDefaults: card id -> time added (seconds since 1970)

  init(requestModel: RequestModel) {
    self.requestModel = requestModel
  }

  var freeWordsLeft: Int {                      // shown on cards that aren't bought
    max(0, FreeAllowance.freeWordLimit - FreeAllowance.shared.wordsUsed)
  }

  // MARK: - cards
  // See the flow above. A computed list: a few small SwiftData reads, only while WelcomeBackView is on screen.
  var cards: [Card] {
    let currentJob = Occupation.listed(requestModel.proffession)
    let currentLanguage = requestModel.selectedLanguage
    var pairs: [(job: Occupation, language: Languages, since: Date)] = []
    func add(_ job: Occupation, _ language: Languages, since: Date) {
      if !pairs.contains(where: { $0.job == job && $0.language == language }) { pairs.append((job, language, since)) }
    }

    for pair in PersistenceController.shared.playedJobLanguages() {                     // 1. played
      if let job = Occupation.listed(pair.profession), let language = Languages(rawValue: pair.targetLanguage) {
        add(job, language, since: pair.since)
      }
    }
    if let currentJob { add(currentJob, currentLanguage, since: .now) }                 // 2. current
    for job in Occupation.allCases where job != .notListed && Purchases.shared.isUnlocked(job)
      && !pairs.contains(where: { $0.job == job }) {                                    // 3. bought, never played
      add(job, currentLanguage, since: .now)
    }
    var added = Self.loadAdded()
    for (id, time) in added {                                                           // 4. added before
      let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
      if parts.count == 2, let job = Occupation.listed(parts[0]), let language = Languages(rawValue: parts[1]) {
        add(job, language, since: Date(timeIntervalSince1970: time))
      }
    }

    let freeUsedUp = FreeAllowance.shared.isLimitReached
    var changed = false
    let built = pairs.map { pair -> Card in
      let id = "\(pair.job.rawValue)|\(pair.language.rawValue)"
      if added[id] == nil {                                                             // first time seen: remember it
        added[id] = pair.since.timeIntervalSince1970
        changed = true
      }
      let progress = PersistenceController.shared.jobProgress(profession: pair.job.rawValue,
                                                             targetLanguage: pair.language.rawValue)
      let owned = Purchases.shared.isUnlocked(pair.job)
      return Card(job: pair.job, language: pair.language,
                  learned: progress.learned, played: progress.played,
                  correct: progress.correct, incorrect: progress.incorrect,
                  isOwned: owned,
                  isCurrent: pair.job == currentJob && pair.language == currentLanguage,
                  isLocked: !owned && freeUsedUp,
                  added: Date(timeIntervalSince1970: added[id] ?? pair.since.timeIntervalSince1970))
    }
    if changed { UserDefaults.standard.set(added, forKey: Self.addedKey) }
    return built
      .sorted { ($0.added, $0.id) < ($1.added, $1.id) }                                 // oldest first; ties stay stable
      .enumerated().map { index, card in var card = card; card.colorIndex = index; return card }
  }

  // MARK: - select(_:)
  // A card was opened: make it the current job + language (as Settings would).
  func select(_ card: Card) {
    if requestModel.proffession != card.job.rawValue {
      requestModel.proffession = card.job.rawValue
      UserDefaults.standard.set(card.job.rawValue, forKey: "pickedProffession")   // same key as Settings / EntryView
    }
    if requestModel.selectedLanguage != card.language {
      requestModel.selectedLanguage = card.language
      UserDefaults.standard.set(card.language.rawValue, forKey: "pickedLanguage")
    }
    Log.info("🗂️ CabinetVM.select — \(card.job.rawValue) / \(card.language.rawValue)", .app)
  }

  // MARK: - loadAdded
  // The saved "added" times, card id -> seconds since 1970 (empty the first time).
  private static func loadAdded() -> [String: Double] {
    UserDefaults.standard.dictionary(forKey: addedKey) as? [String: Double] ?? [:]
  }
}
