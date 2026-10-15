//
//  GuestionModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import Foundation

// MARK: - Flow of this file
// One playable question: a word plus its image bytes.
//   RequestModel.buildQuestions() creates them and fills imageData
//   -> WordVM.questions holds them -> MainView shows the current one.
//   mockQuestions is only for MainView's preview.

struct QuestionModel: Identifiable, Equatable  {
  // MARK: - ==
  // Two questions are the same when their ids match — the image bytes are not compared (fast, and enough).
  static func == (lhs: borrowing QuestionModel, rhs: borrowing QuestionModel) -> Bool {
    lhs.id == rhs.id
  }
  
  let id: String                  // UUID string, made in buildQuestions
  let word: WordModel             // the word to spell and its hint
  var imageData: Data?            // PNG/WebP bytes; nil = no image yet (filtered out before play)
  
  static let mockQuestions = [    // preview data for MainView
    QuestionModel(id: "1", word: WordModel(toolName: "hammer", originWord: "молоток", targetWord: "hummer", imagePrompt: ""), imageData: nil)
  ]
}
