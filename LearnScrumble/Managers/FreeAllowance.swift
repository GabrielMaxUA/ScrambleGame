//
//  FreeAllowance.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import Foundation
import Security
import Observation

/// Counts words answered per day for free users.
/// Stored in the Keychain (survives deleting the app) and dated with internet time (changing the phone's date doesn't help).
@Observable
final class FreeAllowance {
  static let shared = FreeAllowance()
  static let dailyWordLimit = 20                                   // 2 rounds of 10 — change here only
  
  private(set) var wordsUsedToday = 0
  var isLimitReached: Bool { wordsUsedToday >= Self.dailyWordLimit }
  
  private struct Stored: Codable {
    var day: String                                                // e.g. "2026-10-8" — the day the count belongs to
    var count: Int                                                 // words answered that day
    var latestDate: Date                                           // latest date ever seen: the day can never go backwards
  }
  
  @ObservationIgnored private var reference: (date: Date, ticks: UInt64)?   // internet time + internal clock reading when it was fetched
  
  private init() { refresh() }
  
  // MARK: - Public
  
  /// Asks a web server for the real current time. Call before starting a game.
  func syncClock() async {
    var request = URLRequest(url: URL(string: "https://www.apple.com")!)
    request.httpMethod = "HEAD"                                    // only the reply headers are needed, not the page
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
  
  /// Called once for every answered word.
  func recordAnsweredWord() {
    var stored = currentStored()
    stored.count += 1
    Self.save(stored)
    wordsUsedToday = stored.count
    print("🧮 FreeAllowance — \(wordsUsedToday)/\(Self.dailyWordLimit) words today")
  }
  
  /// Re-reads the count, starting a new day if midnight has passed.
  func refresh() {
    let stored = currentStored()
    Self.save(stored)
    wordsUsedToday = stored.count
  }
  
  // MARK: - Time
  
  private func trustedNow() -> Date {
    guard let reference else { return Date() }                     // no internet time yet: phone's clock
    let elapsed = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC) - reference.ticks) / 1_000_000_000
    return reference.date.addingTimeInterval(elapsed)              // internal clock: not affected by changing the date in Settings
  }
  
  private func dayKey(_ date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
  }
  
  private func currentStored() -> Stored {
    let now = trustedNow()
    var stored = Self.load() ?? Stored(day: dayKey(now), count: 0, latestDate: now)
    let effective = max(now, stored.latestDate)                    // date set back: stay on the latest day seen
    if dayKey(effective) != stored.day {
      stored = Stored(day: dayKey(effective), count: 0, latestDate: effective)   // new day: fresh allowance
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
  
  private static let service = Bundle.main.bundleIdentifier ?? "LearnScrumble"
  private static let account = "freeAllowance"
  
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
  
  private static func save(_ stored: Stored) {
    guard let data = try? JSONEncoder().encode(stored) else { return }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let update: [String: Any] = [kSecValueData as String: data]
    if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {   // first time: create the entry
      var add = query
      add[kSecValueData as String] = data
      add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
      SecItemAdd(add as CFDictionary, nil)
    }
  }
}
