//
//  WordModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import Foundation

// MARK: - Flow of this file
// One vocabulary word in a question.
//   RequestModel.buildQuestions() makes one from each word the server returns (getWords; My words reads the saved words on the phone instead)
//   and wraps it in a QuestionModel. The words come from the word bank, or from GPT on the server.

struct WordModel: Codable {
  let toolName: String        // canonical English/internal name, used for the image prompt
  let originWord: String      // word in language of origin (helper)
  let targetWord: String      // word in the language being learned — the one the user spells
  let imagePrompt: String     // GPT's unambiguous description; sent back to getPicture when the word needs a new picture
}

