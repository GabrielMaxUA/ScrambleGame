//
//  CabinetVM.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-30.
//

import Foundation
import Observation

// MARK: - Flow of this file
// The user's "cabinet" on WelcomeBackView: one card per profession + language being learned.
// All the card logic lives here; WelcomeBackView only draws `cards` and reports taps, RootView carries out the action.
//
// Which cards (cards):
//   1. Every job + language with saved words (PersistenceController.playedJobLanguages).
//   2. The current job + language from Settings, even before its first word (so a new pick shows up at once).
//   3. Every bought job that has no card yet, in the current language (bought, never played).
//   Typed jobs ("Not listed?", hidden for now) and unknown languages are left out.
//   Each card: learned words (PersistenceController.jobProgress), bought or not (Purchases), current or not.
//   Order: the current card first, then bought jobs, then the rest, each by job name.
//
// Tapping a card (select):
//   1. The card becomes the current job + language — the same as picking them in Settings
//      (RequestModel + UserDefaults "pickedProffession" / "pickedLanguage").
//   2. Returns what RootView does next:
//      bought                         -> .wordList: MyWordsView ("Continue learning" / "Repeat all")
//      not bought, free words left    -> .play: a normal game, up to the 10 free words
//      not bought, free words used up -> .paywall: PaywallView for that job (the card shows a lock)
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
    let isOwned: Bool                         // the job is bought (or the Debug unlock is on)
    let isCurrent: Bool                       // the job + language picked right now (Settings)
    let isLocked: Bool                        // not bought and the free words are used up -> lock, tap opens the paywall
    var id: String { "\(job.rawValue)|\(language.rawValue)" }
  }

  // MARK: - Action
  enum Action { case wordList, play, paywall }   // what RootView does after a tap (see select)

  private let requestModel: RequestModel       // the current job + language live here

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
    var pairs: [(job: Occupation, language: Languages)] = []
    func add(_ job: Occupation, _ language: Languages) {
      if !pairs.contains(where: { $0.job == job && $0.language == language }) { pairs.append((job, language)) }
    }

    for pair in PersistenceController.shared.playedJobLanguages() {                     // 1. played
      if let job = Occupation.listed(pair.profession), let language = Languages(rawValue: pair.targetLanguage) {
        add(job, language)
      }
    }
    if let currentJob { add(currentJob, currentLanguage) }                              // 2. current
    for job in Occupation.allCases where job != .notListed && Purchases.shared.isUnlocked(job)
      && !pairs.contains(where: { $0.job == job }) {                                    // 3. bought, never played
      add(job, currentLanguage)
    }

    let freeUsedUp = FreeAllowance.shared.isLimitReached
    let built = pairs.map { pair -> Card in
      let progress = PersistenceController.shared.jobProgress(profession: pair.job.rawValue,
                                                             targetLanguage: pair.language.rawValue)
      let owned = Purchases.shared.isUnlocked(pair.job)
      return Card(job: pair.job, language: pair.language,
                  learned: progress.learned, played: progress.played,
                  isOwned: owned,
                  isCurrent: pair.job == currentJob && pair.language == currentLanguage,
                  isLocked: !owned && freeUsedUp)
    }
    return built.sorted { a, b in
      if a.isCurrent != b.isCurrent { return a.isCurrent }
      if a.isOwned != b.isOwned { return a.isOwned }
      let an = a.job.rawValue, bn = b.job.rawValue
      return an == bn ? a.language.rawValue < b.language.rawValue : an < bn
    }
  }

  // MARK: - select(_:)
  // A card was tapped: make it the current job + language (as Settings would), then say what comes next.
  func select(_ card: Card) -> Action {
    if requestModel.proffession != card.job.rawValue {
      requestModel.proffession = card.job.rawValue
      UserDefaults.standard.set(card.job.rawValue, forKey: "pickedProffession")   // same key as Settings / EntryView
    }
    if requestModel.selectedLanguage != card.language {
      requestModel.selectedLanguage = card.language
      UserDefaults.standard.set(card.language.rawValue, forKey: "pickedLanguage")
    }
    let action: Action = card.isOwned ? .wordList : (card.isLocked ? .paywall : .play)
    Log.info("🗂️ CabinetVM.select — \(card.job.rawValue) / \(card.language.rawValue) -> \(action)", .app)
    return action
  }
}
