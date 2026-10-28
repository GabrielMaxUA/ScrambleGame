//
//  MenuAlert.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//
import SwiftUI

// MARK: - Flow of this file
// The texts for every confirmation / paywall alert in the app.
//   ButtonsTopRow, SettingsView, ResultView, WelcomeBackView pick a case
//   -> read title, message and confirmTitle -> show them in .alert. "Unlock" opens PaywallView.

enum MenuAlert {
  case settings                      // leaving a round to open Settings
  case wordListLocked                // "My words" before the job is unlocked
  case settingsLocked                // the voice picker before any job is unlocked
  case freeWordsDone                 // the 10 free words are used up
  
  
  var title: LocalizedStringKey {    // bold headline of the alert
    switch self {
    case .settings: return "Open Settings?"
    case .wordListLocked, .settingsLocked: return "Unlock your profession"
    case .freeWordsDone: return "Your free words are done"
    }
  }

  var message: LocalizedStringKey {  // explanation under the title
    switch self {
    case .settings: return "This round will end. Your answers so far are saved."
    case .wordListLocked: return "Your word list, with every word you've played and how often you got it right, comes with your profession. One payment, no subscription."
    case .settingsLocked: return "Choosing a different voice comes with unlocking a profession. One payment, no subscription."
    case .freeWordsDone:                                                              // number comes from FreeAllowance
      return "You've played your \(FreeAllowance.freeWordLimit) free words. Unlock your profession to keep learning. One payment, no subscription."
    }
  }

  var confirmTitle: LocalizedStringKey {          // text of the alert's main button
    switch self {
    case .wordListLocked, .settingsLocked, .freeWordsDone: return "Unlock"   // paywall cases open PaywallView
    default: return "OK"
    }
  }
}
