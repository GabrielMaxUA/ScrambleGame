//
//  GamePhase.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import Foundation

// MARK: - Flow of this file
// The app's single screen state.
//   AppManager sets `phase` -> RootView switches on it and shows the matching view.
//   .playing / .result carry the WordVM that owns the running session.

enum GamePhase{
  case onboarding                 // EntryView — first launch setup (languages + profession)
  case welcomeBack                // WelcomeBackView — returning user's start screen
  case generating                 // LoadingView — words and images are being built
  case playing(WordVM)            // MainView — the game itself
  case failed(GenerationError)  // ErrorView — the error decides the message AND the button (retry / change profession / back)
  case offline                // no internet connection — OfflineView, retries by itself once the connection is back
  case result(WordVM)             // ResultView — checkpoint summary after a round
  case settings                   // SettingsView
}
