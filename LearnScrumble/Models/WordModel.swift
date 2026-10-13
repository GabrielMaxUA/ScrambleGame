//
//  WordModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import Foundation

// MARK: - Flow of this file
// One vocabulary word, as GPT returns it (decoded straight from its JSON).
//   RequestModel.generateWordList() -> [WordModel] -> buildQuestions() wraps each in a QuestionModel
//   generateStruggleReview() builds them from Firebase translations instead of GPT.

struct WordModel: Codable {
  let toolName: String        // canonical English/internal name, used for the image prompt
  let originWord: String      // word in language of origin (helper)
  let targetWord: String      // word in the language being learned — the one the user spells
  let imagePrompt: String     // GPT's unambiguous description, sent to the image model
}

