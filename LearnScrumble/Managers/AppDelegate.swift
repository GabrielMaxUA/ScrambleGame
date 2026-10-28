//
//  AppDelegate.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//
import UIKit
import FirebaseCore

// MARK: - Flow of this file
// UIKit's app-launch hook, plugged into SwiftUI by LearnScrumbleApp (@UIApplicationDelegateAdaptor).
//   App starts -> didFinishLaunching -> AppCheckSetup.install() (must come first) -> FirebaseApp.configure()
//   -> Cloud Functions, Firestore and Storage are ready to use, each call carrying an App Check token.
//   -> AnalyticsConsent.apply(saved choice): Analytics only collects if the user agreed (off by default).
//   -> AnonymousAuth.ensureSignedIn() in the background: silent anonymous sign-in (random ID, no screen).

final class AppDelegate: NSObject, UIApplicationDelegate {
  // MARK: - didFinishLaunchingWithOptions
  // Runs once when the app launches. Sets up Firebase, only if it isn't set up yet
  // (configuring twice would crash). Returning true lets the launch continue.
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if FirebaseApp.app() == nil {
      AppCheckSetup.install()                                       // before configure(), or Firebase ignores it
      FirebaseApp.configure()
    }
    AnalyticsConsent.apply(UserDefaults.standard.bool(forKey: AnalyticsConsent.key))
    Task { await AnonymousAuth.ensureSignedIn() }                   // doesn't hold up the launch
    return true
  }
}
