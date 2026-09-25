//
//  CheckpointMode.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-24.
//

import Foundation

enum CheckpointMode {                                              // NEW — how/when a session pauses for ResultView
  case everyN(Int)     // normal play: pause every N words; more content can be fetched via fetchMore
  case endOfSession     // fixed pool (e.g. struggle review): pause exactly once, after the last word
}
