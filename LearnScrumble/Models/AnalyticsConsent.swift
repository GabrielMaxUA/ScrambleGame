//
//  AnalyticsConsent.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-15.
//

import Foundation
import FirebaseAnalytics

// MARK: - Flow of this file
// The user's optional "Share usage statistics" choice for Firebase Analytics (EU consent).
// Off until the user turns it on:
//   - LearnScrumble-Info.plist sets FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO, so nothing is collected
//     on first launch before the user has seen the choice.
//   - The choice is saved in UserDefaults (key "analyticsConsent", false by default) and shared with the
//     views through @AppStorage(AnalyticsConsent.key).
//
// Who calls what:
//   AppDelegate   -> after FirebaseApp.configure(): apply(saved choice), so Analytics matches it every launch
//   EntryView     -> "Your data" card checkbox -> apply(new value)
//   SettingsView  -> "Legal and support" toggle -> apply(new value)
// Crashlytics isn't affected: crash reports stay on (they're in the privacy policy).

enum AnalyticsConsent {
  static let key = "analyticsConsent"                               // true = the user agreed to share usage statistics

  // MARK: - apply(_:)
  // Turns Firebase Analytics collection on or off. Firebase remembers it too, but we call it every launch anyway.
  static func apply(_ enabled: Bool) {
    Analytics.setAnalyticsCollectionEnabled(enabled)
  }
}
