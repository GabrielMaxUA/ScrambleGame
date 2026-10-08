//
//  MenuAlert.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//
import SwiftUI

enum MenuAlert {
  case settings
  case reviewStruggle
  case subscriptionRequired          // review locked
  case settingsLocked                // NEW — settings locked

  var title: LocalizedStringKey {
    switch self {
    case .settings: return "Back to Settings"
    case .reviewStruggle: return "Review Problematic Words"
    case .subscriptionRequired, .settingsLocked: return "Premium feature"
    }
  }

  var message: LocalizedStringKey {
    switch self {
    case .settings: return "Your progress is saved, and new words will be generated."
    case .reviewStruggle: return "Practice the words you got wrong."
    case .subscriptionRequired: return "Reviewing the words you got wrong is part of the subscription. Would you like to see the plans?"
    case .settingsLocked: return "Changing your languages and profession is part of the subscription. Would you like to see the plans?"
    }
  }

  var confirmTitle: LocalizedStringKey {          // NEW — text of the alert's main button
    switch self {
    case .subscriptionRequired, .settingsLocked: return "See plans"
    default: return "OK"
    }
  }
}
