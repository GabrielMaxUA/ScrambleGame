//
//  Track.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-16.
//

import FirebaseAnalytics

// MARK: - Flow of this file
// Every Firebase Analytics event the app sends, in one place, so the names can't be mistyped.
// Each call -> Analytics.logEvent(name, parameters) + a debug line in the console ("📊 round_completed ...").
// Nothing leaves the phone unless the user ticked "Share usage statistics" (AnalyticsConsent):
// with collection off, Firebase simply drops the events.
//
// Who calls what:
//   RootView          -> onboardingCompleted (first "Start Learning"), reminderEnabled(.onboarding) if allowed
//   OnboardingView    -> tutorialFinished(skipped:) ("Let's go!" or Skip)
//   AppManager        -> roundCompleted, dailyLimitReached, reviewStarted
//   SettingsView      -> reminderEnabled(.settings) when the toggle is turned on and allowed
//   RequestModel      -> generationFailed (next to the Crashlytics non-fatal in reportFailure)
//   Later, with the paywall (checklist §4.3): paywall_shown, trial_started.
//
// Privacy: parameters are languages, counts and error names only. Never the typed profession or any user text.
// To watch events arrive: run with -FIRDebugEnabled (Edit Scheme -> Run -> Arguments) and open
// Firebase console -> scrumblegame-dev -> Analytics -> DebugView.

enum Track {
  enum Mode: String { case game, review }                         // which kind of session a round belonged to
  enum Source: String { case onboarding, settings }               // where the reminder was turned on

  static func onboardingCompleted(origin: Languages, target: Languages) {
    send("onboarding_completed", ["origin": origin.rawValue, "target": target.rawValue])
  }

  static func tutorialFinished(skipped: Bool) {
    send(skipped ? "tutorial_skipped" : "tutorial_completed")
  }

  static func roundCompleted(mode: Mode) {
    send("round_completed", ["mode": mode.rawValue])
  }

  static func dailyLimitReached() {
    send("daily_limit_reached", ["limit": FreeAllowance.dailyWordLimit])
  }

  static func reviewStarted(words: Int) {
    send("review_started", ["words": words])
  }

  static func reminderEnabled(source: Source) {
    send("reminder_enabled", ["source": source.rawValue])
  }

  static func generationFailed(_ error: GenerationError, during step: String) {
    send("generation_failed", ["error": "\(error)", "step": step])   // the case name only, e.g. "serverBusy"
  }

  // MARK: - send
  private static func send(_ name: String, _ parameters: [String: Any]? = nil) {
    Analytics.logEvent(name, parameters: parameters)
    Log.debug("📊 \(name) \(parameters ?? [:])", .analytics)
  }
}
