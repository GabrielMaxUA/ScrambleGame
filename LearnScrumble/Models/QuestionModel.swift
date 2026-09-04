//
//  GuestionModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import Foundation

struct QuestionModel: Identifiable  {
  let id: String
  let word: WordModel
  var imageData: Data?
  
  static let mockQuestions = [
    QuestionModel(id: "1", word: WordModel(toolName: "hammer", originWord: "молоток", targetWord: "hammer"), imageData: nil)
  ]
}
