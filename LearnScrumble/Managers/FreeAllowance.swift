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
// Counts words answered per day for free users.
// Stored in the Keychain (survives deleting the app) and dated with internet time (changing the phone's date doesn't help).
//   AppManager.startGame -> syncClock(): fetch real time from apple.com -> refresh()
//   WordVM.onWordAnswered -> recordAnsweredWord(): +1 for today, saved to the Keychain
//   AppManager.canPlay / canFetchMore read isLimitReached / wordsUsedToday (no downloads the user can't play)
//   LearnScrumbleApp (app becomes active) -> refresh(): a new day resets the count to 0
//   DailyReminder reads wordsUsedToday to skip today's 9am reminder once the user has played
//   MenuAlert reads dailyWordLimit for the "free words are done" text
@Observable
final class FreeAllowance {
  static let shared = FreeAllowance()                              // one counter for the whole app
  static let dailyWordLimit = 20                                   // 2 rounds of 10 — change here only
  
  private(set) var wordsUsedToday = 0                              // today's answered words; views update when it changes
  var isLimitReached: Bool { wordsUsedToday >= Self.dailyWordLimit }   // free user is done for today
  
  private struct Stored: Codable {                                 // what's saved in the Keychain, as JSON
    var day: String                                                // e.g. "2026-10-8" — the day the count belongs to
    var count: Int                                                 // words answered that day
    var latestDate: Date                                           // latest date ever seen: the day can never go backwards
  }
  
  @ObservationIgnored private var reference: (date: Date, ticks: UInt64)?   // internet time + internal clock reading when it was fetched
  
  // MARK: - init
  // Private: only `shared` exists. Loads today's count right away (phone's clock until syncClock runs).
  private init() { refresh() }
  
  // MARK: - Public
  
  // MARK: - syncClock
  // Asks a web server for the real current time. Call before starting a game.
  // 1. HEAD request to apple.com — only the reply headers are needed, not the page; gives up after 5s.
  // 2. Reads the "Date" header -> real time; stores it with the phone's internal clock reading at that moment,
  //    so trustedNow() can count forward from it.
  // 3. No internet / no header -> keeps using the phone's clock (logged).
  // 4. refresh() — today's count with the corrected time.
  func syncClock() async {
    var request = URLRequest(url: URL(string: "https://www.apple.com")!)
    request.httpMethod = "HEAD"
    request.timeoutInterval = 5
    if let (_, response) = try? await URLSession.shared.data(for: request),
       let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Date"),
       let date = Self.httpDateFormatter.date(from: header) {
      reference = (date, clock_gettime_nsec_np(CLOCK_MONOTONIC))
      print("🕒 FreeAllowance — internet time \(date)")
    } else {
      print("🕒 FreeAllowance — no internet time, using the phone's clock")
    }
    refresh()
  }
  
  // MARK: - recordAnsweredWord
  // Called once for every answered word (WordVM.onWordAnswered, set up in AppManager.startGame).
  // Today's stored count (new day = starts at 0) +1 -> saved to the Keychain -> wordsUsedToday updated.
  func recordAnsweredWord() {
    var stored = currentStored()
    stored.count += 1
    Self.save(stored)
    wordsUsedToday = stored.count
    print("🧮 FreeAllowance — \(wordsUsedToday)/\(Self.dailyWordLimit) words today")
  }
  
  // MARK: - refresh
  // Re-reads the count, starting a new day if midnight has passed, saves it back and publishes it.
  func refresh() {
    let stored = currentStored()
    Self.save(stored)
    wordsUsedToday = stored.count
  }
  
  // MARK: - Time
  
  // MARK: - trustedNow
  // The current time we trust. No internet time yet: the phone's clock.
  // Otherwise: internet time + how long the internal clock has run since then (nanoseconds -> seconds).
  // The internal clock isn't affected by changing the date in Settings.
  private func trustedNow() -> Date {
    guard let reference else { return Date() }
    let elapsed = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC) - reference.ticks) / 1_000_000_000
    return reference.date.addingTimeInterval(elapsed)
  }
  
  // MARK: - dayKey
  // A date -> "year-month-day" text in the phone's calendar, e.g. "2026-10-8". Two dates on the same day give the same key.
  private func dayKey(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
  }
  
  // MARK: - currentStored
  // Today's record, ready to use:
  // 1. Loads the saved record (none yet -> a fresh one for today).
  // 2. Uses the later of "now" and the latest date ever seen — if the date was set back, stay on the latest day seen.
  // 3. That date is on a different day than the record -> new day: fresh allowance (count 0).
  //    Same day -> just remember the latest date.
  private func currentStored() -> Stored {
    let now = trustedNow()
    var stored = Self.load() ?? Stored(day: dayKey(now), count: 0, latestDate: now)
    let effective = max(now, stored.latestDate)
    if dayKey(effective) != stored.day {
      stored = Stored(day: dayKey(effective), count: 0, latestDate: effective)
    } else {
      stored.latestDate = effective
    }
    return stored
  }
  
  private static let httpDateFormatter: DateFormatter = {          // web servers send e.g. "Thu, 08 Oct 2026 14:05:00 GMT"
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    return formatter
  }()
  
  // MARK: - Keychain
  
  private static let service = Bundle.main.bundleIdentifier ?? "LearnScrumble"   // Keychain entry is looked up by service + account
  private static let account = "freeAllowance"
  
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
