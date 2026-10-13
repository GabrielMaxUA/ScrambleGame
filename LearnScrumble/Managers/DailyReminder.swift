//
//  DailyReminder.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-12.
//

import Foundation
import UserNotifications

// MARK: - Flow of this file
// DailyReminder books LOCAL notifications (no server, no push) that say
// "LearnScrumble got your words ready and waiting for you!" at 9:00 every day,
// but only on days the user hasn't played yet.
//
// iOS can't run our code at 9am to check "did they play?", so instead:
//   - we book one separate notification per day, for the next 7 days
//   - each one has its own id, e.g. "dailyReminder-2026-10-12"
//   - when the user answers a word, we delete TODAY's id -> no reminder today
//
// Who calls what:
//   RootView (EntryView's "Let's go")  -> requestPermission()
//        shows the iOS Allow / Don't Allow popup (only ever once), then -> reschedule()
//   LearnScrumbleApp (app becomes active) -> reschedule()
//        deletes the booked reminders and books 7 fresh days from today
//        reads FreeAllowance.shared.wordsUsedToday to skip today if already played
//   AppManager.startGame -> WordVM.onWordAnswered -> cancelToday()
//        deletes today's booked reminder after every answered word
//
// Opening the app moves the 7-day window forward ("auto-renewal").
// App not opened for 7 days -> the booked days run out and reminders stop on their own.

/// "Your words are ready" local notification at 9am, skipped on days the user has already played.
/// iOS can't check the allowance at 9am itself, so one reminder per day is scheduled ahead
/// and today's is removed as soon as a word is answered.
enum DailyReminder {
  static let hour = 9                                              // local time on the phone — change here only
  private static let daysAhead = 7                                 // app not opened for a week: reminders stop instead of nagging
  nonisolated private static let idPrefix = "dailyReminder-"       // start of every reminder id — used to find our own reminders to delete
  private static var center: UNUserNotificationCenter { .current() }   // iOS's notification system: we hand it reminders, it shows them on time

  // MARK: - Public

  // MARK: - requestPermission
  // Shows the system permission prompt once (later calls just return the saved answer), then schedules.
  // Called from: RootView -> EntryView onSubmit ("Let's go" at the end of onboarding)
  // 1. iOS popup — waits here until the user taps; true = Allow (an error counts as not allowed).
  // 2. reschedule(): allowed -> books the next 7 days now; denied -> reschedule() stops at its guard.
  static func requestPermission() async {
    let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    print("🔔 DailyReminder — permission \(granted ? "granted" : "denied")")
    await reschedule()
  }

  // MARK: - reschedule
  // Rebuilds the next days of reminders. Call when the app becomes active.
  // Called from: requestPermission() above, and LearnScrumbleApp .onChange(of: scenePhase) every time the app opens
  // 1. User said Don't Allow (or turned it off in iOS Settings) -> book nothing.
  // 2. Deletes what's booked from earlier opens, so no day gets two reminders.
  // 3. playedToday: FreeAllowance counts answered words per day — 0 means the user hasn't played today.
  // 4. For each day, offset 0 = today, 1 = tomorrow … 6:
  //    - that date at 9:00:00 in the phone's calendar + time zone (= the user's local 9am)
  //    - skipped if that 9am already passed, or if it's today and the user already played
  //    - otherwise one reminder: id "dailyReminder-2026-10-12" (lets cancelToday() find it later)
  //      + content() (title, text, sound) + a trigger that fires once, on that exact date at 9:00
  //    - handed to iOS, which shows it even if the app is closed
  static func reschedule() async {
    guard await center.notificationSettings().authorizationStatus == .authorized else { return }
    center.removePendingNotificationRequests(withIdentifiers: allIds())

    let calendar = Calendar.current
    let now = Date()
    let playedToday = FreeAllowance.shared.wordsUsedToday > 0
    for offset in 0..<daysAhead {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now),
            let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
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
    print("🔔 DailyReminder — scheduled next \(daysAhead) days at \(hour):00 (today skipped: \(playedToday))")
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
