//
//  GamePhase.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import Foundation

enum GamePhase{
  case onboarding
  case welcomeBack
  case generating
  case playing(WordVM)
  case failed(GenerationError)  // ErrorView — the error decides the message AND the button (retry / change profession / back)
  case offline                // no internet connection — OfflineView, retries by itself once the connection is back
  case result(WordVM)
  case settings
}
