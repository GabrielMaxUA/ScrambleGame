//
//  DailyReminder.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-12.
//

import Foundation
import SwiftUI
import UserNotifications

// MARK: - Flow of this file
// DailyReminder books LOCAL notifications (no server, no push) that say
// "LearnScrumble got your words ready and waiting for you!" once a day at the user's chosen time
// (9:00 unless changed), but only on days the user hasn't played yet.
//
// The user's choice is saved in UserDefaults, shared with the views through @AppStorage:
//   enabledKey ("reminderEnabled")  — on/off, on by default    <- SettingsView toggle
//   timeKey    ("reminderMinutes")  — minutes after midnight   <- EntryView card + SettingsView
//   timeBinding() turns those minutes into the Date a DatePicker needs, and back.
//
// iOS can't run our code at 9am to check "did they play?", so instead:
//   - we book one separate notification per day, for the next 7 days
//   - each one has its own id, e.g. "dailyReminder-2026-10-12"
//   - when the user answers a word, we delete TODAY's id -> no reminder today
//
// Who calls what:
//   RootView (EntryView's "Let's go")  -> requestPermission()
//        shows the iOS Allow / Don't Allow popup (only ever once), then -> reschedule()
//   SettingsView (toggle turned on, never asked yet) -> requestPermission()
//   SettingsView (toggle or time changed) -> reschedule(); authorizationStatus() for the "notifications are off" note
//   LearnScrumbleApp (app becomes active) -> reschedule()
//        deletes the booked reminders and books 7 fresh days from today
//        reads FreeAllowance.shared.wordsUsedToday to skip today if already played
//   AppManager.startGame -> WordVM.onWordAnswered -> cancelToday()
//        deletes today's booked reminder after every answered word
//
// Opening the app moves the 7-day window forward ("auto-renewal").
// App not opened for 7 days -> the booked days run out and reminders stop on their own.

/// "Your words are ready" local notification at the chosen time, skipped on days the user has already played.
/// iOS can't check the allowance at that time itself, so one reminder per day is scheduled ahead
/// and today's is removed as soon as a word is answered.
enum DailyReminder {
  static let enabledKey = "reminderEnabled"                       // UserDefaults key: reminders on/off (missing = on)
  static let timeKey = "reminderMinutes"                          // UserDefaults key: reminder time as minutes after midnight
  static let defaultMinutes = 9 * 60                              // 9:00 — used until the user picks a time
  static var isEnabled: Bool { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }   // the Settings toggle
  private static var minutes: Int { UserDefaults.standard.object(forKey: timeKey) as? Int ?? defaultMinutes }   // chosen time, e.g. 510 = 8:30
  private static let daysAhead = 7                                 // app not opened for a week: reminders stop instead of nagging
  nonisolated private static let idPrefix = "dailyReminder-"       // start of every reminder id — used to find our own reminders to delete
  private static var center: UNUserNotificationCenter { .current() }   // iOS's notification system: we hand it reminders, it shows them on time

  // MARK: - Public

  // MARK: - requestPermission
  // Shows the system permission prompt once (later calls just return the saved answer), then schedules.
  // Called from: RootView -> EntryView onSubmit ("Let's go" at the end of onboarding)
  // 1. iOS popup — waits here until the user taps; true = Allow (an error counts as not allowed).
  // 2. reschedule(): allowed -> books the next 7 days now; denied -> reschedule() stops at its guard.
  // Returns the answer (true = Allow), so the caller can send the reminder_enabled event (Track).
  @discardableResult
  static func requestPermission() async -> Bool {
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    Log.info("🔔 DailyReminder — permission \(granted ? "granted" : "denied")", .reminder)
    await reschedule()
    return granted
  }

  // MARK: - reschedule
  // Rebuilds the next days of reminders. Call when the app becomes active, or when the toggle or time changes.
  // Called from: requestPermission() above, LearnScrumbleApp .onChange(of: scenePhase) every time the app opens,
  //              and SettingsView when the toggle or the time changes
  // 1. Deletes what's booked from earlier opens, so no day gets two reminders (and nothing stays booked when turned off).
  // 2. Reminders switched off in Settings, or the user said Don't Allow (or turned it off in iOS Settings) -> book nothing.
  // 3. playedToday: FreeAllowance counts answered words per day — 0 means the user hasn't played today.
  // 4. For each day, offset 0 = today, 1 = tomorrow … 6:
  //    - that date at the chosen hour:minute in the phone's calendar + time zone (= the user's local time)
  //    - skipped if that time already passed, or if it's today and the user already played
  //    - otherwise one reminder: id "dailyReminder-2026-10-12" (lets cancelToday() find it later)
  //      + content() (title, text, sound) + a trigger that fires once, on that exact date and time
  //    - handed to iOS, which shows it even if the app is closed
  static func reschedule() async {
    center.removePendingNotificationRequests(withIdentifiers: allIds())
    guard isEnabled, await center.notificationSettings().authorizationStatus == .authorized else { return }

    let calendar = Calendar.current
    let now = Date()
    let playedToday = FreeAllowance.shared.wordsUsedToday > 0
    let hour = minutes / 60
    let minute = minutes % 60
    for offset in 0..<daysAhead {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now),
            let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
            fireDate > now else { continue }
      if offset == 0 && playedToday { continue }

      var parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
      parts.second = 0
      let request = UNNotificationRequest(
        identifier: id(for: fireDate),
        content: content(),
        trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
      try? await center.add(request)
    }
    Log.info("🔔 DailyReminder — scheduled next \(daysAhead) days at \(hour):\(String(format: "%02d", minute)) (today skipped: \(playedToday))", .reminder)
  }

  // MARK: - authorizationStatus
  // What the user answered in iOS: .authorized, .denied, or .notDetermined (never asked yet).
  // SettingsView uses it to show the "notifications are off" note, or to ask for permission when the toggle turns on.
  static func authorizationStatus() async -> UNAuthorizationStatus {
    await center.notificationSettings().authorizationStatus
  }

  // MARK: - timeBinding(_:)
  // A DatePicker works with a Date, but the time is saved as minutes after midnight.
  // get: minutes -> today at that hour:minute. set: the picked Date -> its hour * 60 + minute.
  // Used by EntryView's reminder card and SettingsView, both bound to the same @AppStorage(timeKey) value.
  static func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
    Binding(
      get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date() },
      set: {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
        minutes.wrappedValue = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
      }
    )
  }

  // MARK: - cancelToday
  // The user played today: today's reminder isn't needed anymore.
  // Called from: AppManager.startGame -> WordVM's onWordAnswered, after every answered word
  // Deletes today's id; if it already fired or was never booked, nothing happens.
  static func cancelToday() {
    center.removePendingNotificationRequests(withIdentifiers: [id(for: Date())])
  }

  // MARK: - Private

  // MARK: - content
  // What the notification shows. Used by reschedule() for every booked day.
  //   title: "LearnScrumble" — bold first line of the banner
  //   body:  the message, from Localizable.xcstrings (phone's language)
  //   sound: the standard iOS notification sound
  private static func content() -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = "LearnScrumble"
    content.body = String(localized: "LearnScrumble got your words ready and waiting for you!")
    content.sound = .default
    return content
  }

  // MARK: - id(for:)
  // Builds the reminder id for a day, e.g. "dailyReminder-2026-10-12": pulls year, month, day out of the date.
  // Used by reschedule() (to book), cancelToday() (to delete today) and allIds() (to delete all).
  // nonisolated: pure date math, safe from any thread.
  nonisolated private static func id(for date: Date) -> String {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return "\(idPrefix)\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
  }

  // MARK: - allIds
  // Ids for today + the next 6 days — every reminder reschedule() could have booked:
  // days 0...6 from now -> their ids.
  private static func allIds() -> [String] {
    (0..<daysAhead).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }.map(id(for:))
  }
}
