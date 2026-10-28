//
//  Streak.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import Foundation
import Observation

// MARK: - Flow of this file
// Days in a row with at least one answered word ("🔥 5 days in a row").
// Saved in UserDefaults on this phone: the last day played + the count. Uses the phone's clock — it's only a
// motivation number, nothing is unlocked by it.
//   WordVM.checkAnswer -> recordPlay(): first answer of a new day -> +1 (yesterday played) or back to 1 (a day missed)
//   WelcomeBackView / ResultView read current: shown only from 1 day up; a missed day shows 0 until the next answer
//   DailyReminder reads playedToday to skip today's reminder once the user has played
@Observable
final class Streak {
  static let shared = Streak()                                     // one streak for the whole app

  private static let dayKey = "streakLastDay"                      // UserDefaults: "2026-10-28" — the last day with an answer
  private static let countKey = "streakCount"                      // UserDefaults: days in a row up to that day

  private(set) var lastDay = UserDefaults.standard.string(forKey: dayKey) ?? ""
  private(set) var count = UserDefaults.standard.integer(forKey: countKey)

  private init() {}

  var playedToday: Bool { lastDay == Self.key(for: .now) }         // at least one answer today

  var current: Int {                                               // the streak as of now: still alive if played today or yesterday
    lastDay == Self.key(for: .now) || lastDay == Self.key(for: Self.yesterday) ? count : 0
  }

  // MARK: - recordPlay
  // Called for every real answer (not the tutorial). Only the first answer of a day changes anything:
  // played yesterday -> count +1, otherwise the streak starts again at 1. Saved straight away.
  func recordPlay() {
    let today = Self.key(for: .now)
    guard lastDay != today else { return }
    count = lastDay == Self.key(for: Self.yesterday) ? count + 1 : 1
    lastDay = today
    UserDefaults.standard.set(lastDay, forKey: Self.dayKey)
    UserDefaults.standard.set(count, forKey: Self.countKey)
    Log.info("🔥 Streak — \(count) day(s) in a row", .game)
  }

  private static var yesterday: Date { Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now }

  // MARK: - key(for:)
  // A date -> "year-month-day" in the phone's calendar. Two dates on the same day give the same key.
  private static func key(for date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
  }
}
