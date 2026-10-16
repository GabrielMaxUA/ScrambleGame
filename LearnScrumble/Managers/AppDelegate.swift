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
//   App starts -> didFinishLaunching -> FirebaseApp.configure()
//   -> Firestore (FirebaseWordStore) and Storage (FirebaseImageStore) are ready to use.
//   -> AnalyticsConsent.apply(saved choice): Analytics only collects if the user agreed (off by default).

final class AppDelegate: NSObject, UIApplicationDelegate {
  // MARK: - didFinishLaunchingWithOptions
  // Runs once when the app launches. Sets up Firebase, only if it isn't set up yet
  // (configuring twice would crash). Returning true lets the launch continue.
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    AnalyticsConsent.apply(UserDefaults.standard.bool(forKey: AnalyticsConsent.key))
    return true
  }
}
