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
  
  var title: LocalizedStringKey {
    switch self {
    case .settings: return "Back to Settings"
    case .reviewStruggle: return "Review Problematic Words"
    }
  }
  
  var message: LocalizedStringKey {
    switch self {
    case .settings: return "Your progress is saved, and new words will be generated."
    case .reviewStruggle: return "Practice the words you got wrong."
    }
  }
}
