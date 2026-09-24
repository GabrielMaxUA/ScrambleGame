// WordVM.swift
import SwiftUI
import SwiftData

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
  private let modelContext: ModelContext
  var overlayShown: Bool = false
  var isLoadingMore = false
  private var pendingAdvance = false
  var wordSegments: [String] {
    guard let word else { return [] }
    return word.targetWord.split(separator: " ").map(String.init)
  }
  
  var segmentRanges: [Range<Int>] {
    var ranges: [Range<Int>] = []
    var cursor = 0
    for seg in wordSegments {
      ranges.append(cursor..<(cursor + seg.count))
      cursor += seg.count
    }
    return ranges
  }
  
  var resultWord: String {
    guard !guessedWord.isEmpty else { return "" }
    var parts: [String] = []
    for range in segmentRanges {
      let segment = range.map { guessedWord.indices.contains($0) ? (guessedWord[$0]?.letter ?? "*") : "*" }
      parts.append(segment.joined())
    }
    return parts.joined(separator: " ").lowercased()
  }

  init(questions: [QuestionModel], fetchMore: (([String]) async -> [QuestionModel])? = nil) {
    self.modelContext = PersistenceController.shared.context
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
  var isComplete: Bool { !guessedWord.contains(where: { $0 == nil }) }
  
  func setupCurrentWord() {
    guard let word else {
      guessedWord = []
      scrumbledWord = []
      return
    }
    let letters = word.targetWord
      .filter { $0 != " " }
      .map { String($0).lowercased() }
    
    let totalLetters = letters.count
    guessedWord = Array(repeating: nil, count: totalLetters)
    
    var shuffledLetters = letters
    if totalLetters > 1 {
      repeat {
        shuffledLetters = letters.shuffled()
      } while shuffledLetters == letters
    } //making sure here that shuffled word isnt placing letteres same order as a target word
    
    scrumbledWord = shuffledLetters
      .enumerated()
      .map { LetterModel(id: $0.offset, letter: $0.element, isUsed: false) }
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
    let isCorrect = resultWord == word.targetWord.filter({ $0 != " " }).lowercased()
    guessResult = isCorrect ? .correct : .incorrect
    overlayShown = true
    //saving to device
    recordGuess(for: word.targetWord, result: guessResult!)
  }
  
  func nextWord() {
    guessResult = nil
    let nextIndex = currentIndex + 1
    
    if nextIndex >= questions.count {
      if isLoadingMore {
        // Fetch is still in flight — don't advance into a nil word, wait for it
        pendingAdvance = true
        return
      }
      isFinished = true
      return
    }
    
    currentIndex = nextIndex
    setupCurrentWord()
    requestMoreIfNeeded()
    overlayShown = false
  }
  
  private func requestMoreIfNeeded() {
    print("index:", currentIndex,
          "requested:", hasRequestedMore,
          "fetchMore:", fetchMore != nil)
    
    guard !hasRequestedMore,
          currentIndex == questions.count - 2,
          let fetchMore else { return }
    
    print("🔥 FETCH MORE TRIGGERED")
    
    hasRequestedMore = true
    isLoadingMore = true
    let existingWords = questions.map { $0.word.targetWord }
    
    Task {
      let newQuestions = await fetchMore(existingWords)
      questions.append(contentsOf: newQuestions)
      print("🔥 MORE QUESTIONS ADDED:", newQuestions.count)
      isLoadingMore = false
      hasRequestedMore = false
      
      if pendingAdvance {
        pendingAdvance = false
        nextWord()
      }
    }
  }
  
  func resetGuess() {
    for tile in guessedWord.compactMap({ $0 }) {
      if let idx = scrumbledWord.firstIndex(where: { $0.id == tile.id }) {
        scrumbledWord[idx].isUsed = false
      }
    }
    guessedWord = Array(repeating: nil, count: guessedWord.count)
  }
  
  private func recordGuess(for concept: String, result: GuessResult) {
    let predicate = #Predicate<SwiftDataWordModel> { $0.concept == concept }
    let descriptor = FetchDescriptor<SwiftDataWordModel>(predicate: predicate)
    
    let record = (try? modelContext.fetch(descriptor))?.first ?? {
      let new = SwiftDataWordModel(concept: concept)
      modelContext.insert(new)
      return new
    }()
    
    switch result {
    case .correct:
      record.correct += 1
    case .incorrect:
      record.incorrect += 1
    }
    record.lastSeen = .now
    
    try? modelContext.save()
    PersistenceController.shared.debugPrintAllWords()
  }
}
