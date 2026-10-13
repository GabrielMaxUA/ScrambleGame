//
//  LetterModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import Foundation

// MARK: - Flow of this file
// One letter tile of the scrambled word.
//   WordVM.setupCurrentWord() builds the tiles from the target word
//   -> MainView / LetterBoxView show them, GuessedLettersRow / GuessedLetterView show the placed ones
//   -> tapping a tile flips isUsed, so it can't be placed twice.

struct LetterModel: Identifiable {
  let id: Int                      // position in the scrambled row — tells two equal letters apart
  let letter: String               // the character shown on the tile
  var isUsed: Bool                 // true while the tile sits in a guess slot
}
