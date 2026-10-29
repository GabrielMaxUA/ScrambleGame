//
//  FreeAllowance.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import Foundation
import Security
import Observation

// MARK: - Flow of this file
// Counts the free words: the first 10 answered words, once for the whole app (since 28 Oct 2026; before, 10 a day).
// They're a taste of the app — after them, a job has to be unlocked (Purchases) to keep playing.
// Stored in the Keychain, so deleting and reinstalling the app doesn't give the 10 words again.
//   WordVM.onWordAnswered -> recordAnsweredWord(): +1, saved to the Keychain
//   AppManager.canPlay / canFetchMore read isLimitReached / wordsUsed (no downloads the user can't play)
//   MenuAlert / OnboardingView read freeWordLimit for their texts
//   Debug builds only: SettingsView's "Reset free words" -> resetForTesting(): the count back to 0
@Observable
final class FreeAllowance {
  static let shared = FreeAllowance()                              // one counter for the whole app
  static let freeWordLimit = 10                                    // free words, once — change here only

  private(set) var wordsUsed = 0                                   // free words answered so far; views update when it changes
  var isLimitReached: Bool { wordsUsed >= Self.freeWordLimit }     // the free words are used up

  private struct Stored: Codable {                                 // what's saved in the Keychain, as JSON
    var count: Int                                                 // words answered, ever
  }

  // MARK: - init
  // Private: only `shared` exists. Loads the count right away.
  private init() { refresh() }

  // MARK: - recordAnsweredWord
  // Called once for every answered word in a normal game (WordVM.onWordAnswered, set up in AppManager.startGame).
  // Stops counting at the limit — the number is only needed up to there.
  func recordAnsweredWord() {
    guard !isLimitReached else { return }
    let stored = Stored(count: wordsUsed + 1)
    Self.save(stored)
    wordsUsed = stored.count
    Log.debug("🧮 FreeAllowance — \(wordsUsed)/\(Self.freeWordLimit) free words used", .allowance)
  }

  // MARK: - refresh
  // Re-reads the count from the Keychain and publishes it.
  func refresh() {
    wordsUsed = Self.load()?.count ?? 0
  }

  #if DEBUG
  // MARK: - resetForTesting
  // Debug builds only (Settings -> Debug -> Reset free words), so testers get the 10 words again without Terminal.
  // Doesn't exist in Release (App Store / TestFlight) builds.
  func resetForTesting() {
    Self.save(Stored(count: 0))
    wordsUsed = 0
    Log.info("🧪 FreeAllowance — reset to 0 (debug build)", .allowance)
  }
  #endif

  // MARK: - Keychain

  private static let service = Bundle.main.bundleIdentifier ?? "LearnScrumble"   // Keychain entry is looked up by service + account
  private static let account = "freeWordsTotal"                    // new entry: the old per-day "freeAllowance" one isn't read any more

  // MARK: - load
  // Reads the one Keychain entry (service + account) and decodes its JSON into Stored.
  // Nothing saved yet or unreadable -> nil.
  private static func load() -> Stored? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data else { return nil }
    return try? JSONDecoder().decode(Stored.self, from: data)
  }

  // MARK: - save
  // Stored -> JSON -> Keychain. Updates the existing entry; if there is none yet (first time),
  // creates it, readable after the phone's first unlock (so it works in the background too).
  private static func save(_ stored: Stored) {
    guard let data = try? JSONEncoder().encode(stored) else { return }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let update: [String: Any] = [kSecValueData as String: data]
    if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
      var add = query
      add[kSecValueData as String] = data
      add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
      SecItemAdd(add as CFDictionary, nil)
    }
  }
}
