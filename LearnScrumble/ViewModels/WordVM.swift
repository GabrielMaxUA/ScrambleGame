// WordVM.swift
import SwiftUI

enum GuessResult { case correct, incorrect }
@Observable
class WordVM {
  var questions: [QuestionModel]
  var currentIndex: Int = 0
  var guessResult: GuessResult?
  var scrumbledWord: [LetterModel] = []
  var guessedWord: [LetterModel?] = []
  var isFinished: Bool = false
  private var hasRequestedMore = false
  private let fetchMore: (([String]) async -> [QuestionModel])?
  
  init(questions: [QuestionModel], fetchMore: (([String]) async -> [QuestionModel])? = nil) {
    self.questions = questions
    self.fetchMore = fetchMore
    setupCurrentWord()
  }
  
  var word: WordModel? { questions.indices.contains(currentIndex) ? questions[currentIndex].word : nil }
  var hintWord: String { word?.originWord ?? "" }
  
  var image: UIImage? {
    guard questions.indices.contains(currentIndex),
          let data = questions[currentIndex].imageData else { return nil }
    return UIImage(data: data)
  }
  
  var resultWord: String {
    guard !guessedWord.isEmpty else { return "" }
    return guessedWord.map { $0?.letter ?? "*" }.joined().uppercased()
  }
  
  var isComplete: Bool { !guessedWord.contains(where: { $0 == nil }) }
  
  func setupCurrentWord() {
    guard let word else {
      guessedWord = []
      scrumbledWord = []
      return
    }
    let totalLetters = word.targetWord.filter { $0 != " " }.count
    guessedWord = Array(repeating: nil, count: totalLetters)
    scrumbledWord = word.targetWord
      .filter { $0 != " " }
      .map { String($0).uppercased() }
      .enumerated()
      .map { LetterModel(id: $0.offset, letter: $0.element, isUsed: false) }
      .shuffled()
  }
  
  func selectLetter(_ tile: LetterModel) {
    guard let emptySlot = guessedWord.firstIndex(where: { $0 == nil }) else { return }
    guard let index = scrumbledWord.firstIndex(where: { $0.id == tile.id }) else { return }
    scrumbledWord[index].isUsed = true
    guessedWord[emptySlot] = tile
  }
  
  func deselectLetter(_ tile: LetterModel) {
    guard let slotIndex = guessedWord.firstIndex(where: { $0?.id == tile.id }) else { return }
    guard let index = scrumbledWord.firstIndex(where: { $0.id == tile.id }) else { return }
    scrumbledWord[index].isUsed = false
    guessedWord[slotIndex] = nil
  }
  
  func checkAnswer() {
    guard isComplete, let word else { return }
    let isCorrect = resultWord == word.targetWord.filter({ $0 != " " }).uppercased()
    guessResult = isCorrect ? .correct : .incorrect
  }
  
  func nextWord() {
    guessResult = nil
    print("nextWord called — currentIndex: \(currentIndex), total: \(questions.count), isFinished: \(isFinished)")
    guard !isFinished else { return }
    currentIndex += 1
    setupCurrentWord()
    requestMoreIfNeeded()
  }
  
//  private func requestMoreIfNeeded() {
//    guard !hasRequestedMore, currentIndex == 1, let fetchMore else { return }
//    hasRequestedMore = true
//    let existingWords = questions.map { $0.word.targetWord }
//    Task {
//      let newQuestions = await fetchMore(existingWords)
//      questions.append(contentsOf: newQuestions)
//    }
//  }
  private func requestMoreIfNeeded() {
    print("index:", currentIndex,
          "requested:", hasRequestedMore,
          "fetchMore:", fetchMore != nil)
    
    guard !hasRequestedMore,
          currentIndex == questions.count - 7,
          let fetchMore else { return }
    
    print("🔥 FETCH MORE TRIGGERED")
    
    hasRequestedMore = true
    
    let existingWords = questions.map { $0.word.targetWord }
    
    Task {
      let newQuestions = await fetchMore(existingWords)
      questions.append(contentsOf: newQuestions)
      print("🔥 MORE QUESTIONS ADDED:", newQuestions.count)
    }
  }
  
  private func resetGuess() {
    for tile in guessedWord.compactMap({ $0 }) {
      if let idx = scrumbledWord.firstIndex(where: { $0.id == tile.id }) {
        scrumbledWord[idx].isUsed = false
      }
    }
    guessedWord = Array(repeating: nil, count: guessedWord.count)
  }
}
