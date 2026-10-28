//
//  Log.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-16.
//

import Foundation
import OSLog
import FirebaseCore
import FirebaseCrashlytics

// MARK: - Flow of this file
// The app's one way to log, instead of print(). Every line goes to Apple's logger (os.Logger):
//   Log.debug(...)   -> console only. For the noisy step-by-step lines (every tap, every lookup).
//   Log.info(...)    -> console + a Crashlytics breadcrumb: a crash report shows the last steps before the crash.
//   Log.error(...)   -> the same as info, at error level (marked in Xcode's console, easy to filter).
//   Log.report(...)  -> records a GenerationError in Crashlytics as a non-fatal issue: no crash, but counted,
//                       one issue per error case (serverBusy, badResponse, ...). RequestModel calls it once per failed load.
//
// Where to read the logs:
//   - Xcode's console while running from Xcode, the same place print() went. Filter by category or level there.
//   - Console.app on the Mac, when Xcode isn't attached (app opened from the simulator icon, TestFlight on the iPhone):
//     pick the Mac (simulator) or the iPhone, Start streaming, search subsystem:com.MaxGabriel.LearnScrumble.
//     Debug lines only show there with Action -> Include Debug Messages.
//
// Privacy:
//   - `message` is public: it can show in device logs and goes to Crashlytics. Never put what the user typed in it.
//   - `private:` is for the user's own text (the typed profession). Xcode shows it; outside Xcode it shows as
//     <private>, and it never goes to Crashlytics.
//
// Crashlytics only exists after FirebaseApp.configure() (AppDelegate). Lines logged before that
// (RequestModel.init, PersistenceController.init) only go to the console.
// nonisolated: SoundManager logs from its background queue; Logger and Crashlytics are both thread-safe.

nonisolated enum Log {
  nonisolated enum Category: String {                              // shown next to each line in Xcode; filter by it
    case app                                                       // AppManager, screens, paywall
    case game                                                      // WordVM: rounds, answers, checkpoints
    case words                                                     // RequestModel: words and pictures from the Cloud Functions
    case firebase                                                  // Firestore word documents
    case auth                                                      // AnonymousAuth: silent anonymous sign-in
    case storage                                                   // SwiftData progress on the phone
    case allowance                                                 // daily free words
    case reminder                                                  // daily notification
    case sound                                                     // sound effects
    case analytics                                                 // Track: Firebase Analytics events
  }

  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.MaxGabriel.LearnScrumble"

  static func debug(_ message: String, _ category: Category, private detail: String? = nil) {
    write(.debug, message, category, detail, breadcrumb: false)
  }

  static func info(_ message: String, _ category: Category, private detail: String? = nil) {
    write(.info, message, category, detail, breadcrumb: true)
  }

  static func error(_ message: String, _ category: Category, private detail: String? = nil) {
    write(.error, message, category, detail, breadcrumb: true)
  }

  // MARK: - report(_:during:info:)
  // Non-fatal issue in Crashlytics. Domain "GenerationError" + the case's fixed code, so each case is its own issue.
  // `step` = which entry point failed; `info` = extra keys shown on the event (languages, the original error).
  // MainActor: GenerationError is main-actor (the project default), and every caller is a @MainActor entry point.
  @MainActor
  static func report(_ error: GenerationError, during step: String, info: [String: String] = [:]) {
    guard let crashlytics else { return }
    var userInfo: [String: Any] = info
    userInfo["step"] = step
    userInfo[NSLocalizedDescriptionKey] = "\(error)"
    crashlytics.record(error: NSError(domain: "GenerationError", code: error.reportCode, userInfo: userInfo))
  }

  // MARK: - write
  // One Logger per category. The message is public; the private detail is redacted outside Xcode.
  // Breadcrumbs carry only the public message.
  private static func write(_ level: OSLogType, _ message: String, _ category: Category, _ detail: String?, breadcrumb: Bool) {
    let logger = Logger(subsystem: subsystem, category: category.rawValue)
    if let detail {
      logger.log(level: level, "\(message, privacy: .public) \(detail, privacy: .private)")
    } else {
      logger.log(level: level, "\(message, privacy: .public)")
    }
    if breadcrumb {
      crashlytics?.log("[\(category.rawValue)] \(message)")
    }
  }

  private static var crashlytics: Crashlytics? {                   // nil until AppDelegate has configured Firebase
    FirebaseApp.app() == nil ? nil : Crashlytics.crashlytics()
  }
}
