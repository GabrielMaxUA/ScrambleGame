//
//  CheckpointMode.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-24.
//

import Foundation

// MARK: - Flow of this file
// Tells WordVM when a session pauses to show ResultView.
//   AppManager.startGame()           -> WordVM(... ) with the default .everyN(10)
//   AppManager.startStruggleReview() -> WordVM(checkpointMode: .endOfSession)
// WordVM reads it after every answered word to decide whether to fire onCheckpoint.

enum CheckpointMode {                                              // NEW — how/when a session pauses for ResultView
  case everyN(Int)     // normal play: pause every N words; more content can be fetched via fetchMore
  case endOfSession     // fixed pool (e.g. struggle review): pause exactly once, after the last word
}
