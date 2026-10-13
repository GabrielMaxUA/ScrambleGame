//
//  DailyReminder.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-12.
//

import Foundation
import UserNotifications

/// "Your words are ready" local notification at 9am, skipped on days the user has already played.
/// iOS can't check the allowance at 9am itself, so one reminder per day is scheduled ahead
/// and today's is removed as soon as a word is answered.
enum DailyReminder {
  static let hour = 9                                              // local time on the phone — change here only
  private static let daysAhead = 7                                 // app not opened for a week: reminders stop instead of nagging
  private static let idPrefix = "dailyReminder-"
  private static var center: UNUserNotificationCenter { .current() }

  // MARK: - Public

  /// Shows the system permission prompt once (later calls just return the saved answer), then schedules.
  static func requestPermission() async {
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    print("🔔 DailyReminder — permission \(granted ? "granted" : "denied")")
    await reschedule()
  }

  /// Rebuilds the next days of reminders. Call when the app becomes active.
  static func reschedule() async {
    guard await center.notificationSettings().authorizationStatus == .authorized else { return }
    center.removePendingNotificationRequests(withIdentifiers: allIds())

    let calendar = Calendar.current
    let now = Date()
    let playedToday = FreeAllowance.shared.wordsUsedToday > 0
    for offset in 0..<daysAhead {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now),
            let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
            fireDate > now else { continue }                       // today's 9am already passed
      if offset == 0 && playedToday { continue }                   // already played before 9am

      var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
      parts.second = 0
      let request = UNNotificationRequest(
        identifier: id(for: fireDate),
        content: content(),
        trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
      try? await center.add(request)
    }
    print("🔔 DailyReminder — scheduled next \(daysAhead) days at \(hour):00 (today skipped: \(playedToday))")
  }

  /// The user played today: today's reminder isn't needed anymore.
  static func cancelToday() {
    center.removePendingNotificationRequests(withIdentifiers: [id(for: Date())])
  }

  // MARK: - Private

  private static func content() -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = "LearnScrumble"
    content.body = String(localized: "LearnScrumble got your words ready and waiting for you!")
    content.sound = .default
    return content
  }

  private static func id(for date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(idPrefix)\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
  }

  private static func allIds() -> [String] {
    (0..<daysAhead).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }.map(id(for:))
  }
}
