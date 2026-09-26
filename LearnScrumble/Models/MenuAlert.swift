//
//  MenuAlert.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import Foundation
enum MenuAlert {
  case settings
  case reviewStruggle
  
  var title: String {
    switch self {
    case .settings: return "Back to Settings"
    case .reviewStruggle: return "Review Problematic Words"
    }
  }
  
  var message: String {
    switch self {
    case .settings: return "Your progress saved and new words would be generated."
    case .reviewStruggle: return "Practice the words you got wrong."
    }
  }
}
