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
  case failed(String)
  case result(WordVM)
  case settings
}
