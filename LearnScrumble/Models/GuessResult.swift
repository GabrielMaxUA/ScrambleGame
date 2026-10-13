//
//  GuessResult.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import Foundation

// MARK: - Flow of this file
// The outcome of one answered word.
//   WordVM sets guessResult once every letter slot is filled
//   -> AnswerResultView shows the happy or sad screen from it.

enum GuessResult {
  case correct                     // the guessed letters spell the target word
  case incorrect                   // at least one letter is wrong
}
