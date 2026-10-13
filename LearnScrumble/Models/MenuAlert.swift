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
//   -> read title, message and confirmTitle -> show them in .alert.

enum MenuAlert {
  case settings                      // leaving a round to open Settings
  case reviewStruggle                // starting a struggle review
  case subscriptionRequired          // review locked
  case settingsLocked                // NEW — settings locked
  case dailyLimitReached             // NEW — free user answered today's free words
  
  
  var title: LocalizedStringKey {    // bold headline of the alert
    switch self {
    case .settings: return "Open Settings?"
    case .reviewStruggle: return "Review Problematic Words"
    case .subscriptionRequired, .settingsLocked: return "Premium feature"
    case .dailyLimitReached: return "Today's free words are done"
    }
  }

  var message: LocalizedStringKey {  // explanation under the title
    switch self {
    case .settings: return "This round will end. Your answers so far are saved."
    case .reviewStruggle: return "Practice the words you got wrong."
    case .subscriptionRequired: return "Reviewing the words you got wrong is part of the subscription. Would you like to see the plans?"
    case .settingsLocked: return "Choosing a different voice is part of the subscription. Would you like to see the plans?"
    case .dailyLimitReached:                                                          // NEW — number comes from FreeAllowance
      return "You've answered your \(FreeAllowance.dailyWordLimit) free words for today. Come back tomorrow, or unlock unlimited words."
    }
  }

  var confirmTitle: LocalizedStringKey {          // NEW — text of the alert's main button
    switch self {
    case .subscriptionRequired, .settingsLocked, .dailyLimitReached: return "See plans"   // paywall cases lead to the plans
    default: return "OK"
    }
  }
}
