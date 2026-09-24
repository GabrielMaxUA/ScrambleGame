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
  private(set) var isAtCheckpoint = false
  private let checkpointInterval = 5
  private var hasRequestedMore = false
  private let fetchMore: (([String]) async -> [QuestionModel])?
  private let onCheckpoint: (() -> Void)?
  private let onResume: (() -> Void)?
  private let modelContext: ModelContext
  private let targetLanguage: String   // Languages.rawValue for this session
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

  init(questions: [QuestionModel],
       targetLanguage: String,
       fetchMore: (([String]) async -> [QuestionModel])? = nil,
       onCheckpoint: (() -> Void)? = nil,
       onResume: (() -> Void)? = nil) {
    self.modelContext = PersistenceController.shared.context
    self.questions = questions
    self.targetLanguage = targetLanguage
    self.fetchMore = fetchMore
    self.onCheckpoint = onCheckpoint
    self.onResume = onResume
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
    }

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
    recordGuess(for: word.toolName, result: guessResult!)
  }

  func nextWord() {
    guessResult = nil
    let nextIndex = currentIndex + 1

    if nextIndex % checkpointInterval == 0 {
      isAtCheckpoint = true
      onCheckpoint?()
      return
    }

    advance(to: nextIndex)
  }

  func continueFromCheckpoint() {
    isAtCheckpoint = false
    advance(to: currentIndex + 1)
    onResume?()
  }

  private func advance(to index: Int) {
    guard index < questions.count else {
      if isLoadingMore {
        pendingAdvance = true
      } else if fetchMore != nil {
        pendingAdvance = true
        requestMoreNow()
      } else {
        isFinished = true
      }
      return
    }
    currentIndex = index
    setupCurrentWord()
    requestMoreIfNeeded()
    overlayShown = false
  }

  private func requestMoreIfNeeded() {
    guard !hasRequestedMore,
          currentIndex == questions.count - 2,
          fetchMore != nil else { return }
    requestMoreNow()
  }

  private func requestMoreNow() {
    guard let fetchMore, !isLoadingMore else { return }
    hasRequestedMore = true
    isLoadingMore = true
    let existingToolNames = questions.map { $0.word.toolName }   // ← was targetWord

    Task {
      let newQuestions = await fetchMore(existingToolNames)
      questions.append(contentsOf: newQuestions)
      isLoadingMore = false
      hasRequestedMore = false

      if pendingAdvance {
        pendingAdvance = false
        advance(to: currentIndex + 1)
        onResume?()
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

  // MARK: - SwiftData stats (scoped to this session's target language)

  private func accuracy(for records: [SwiftDataWordModel]) -> (correct: Int, total: Int) {
    let correct = records.reduce(0) { $0 + $1.correct }
    let incorrect = records.reduce(0) { $0 + $1.incorrect }
    return (correct, correct + incorrect)
  }

  func batchAccuracy() -> (correct: Int, total: Int) {
    guard questions.indices.contains(currentIndex) else { return (0, 0) }
    let start = max(currentIndex - checkpointInterval + 1, 0)
    let concepts = Set(questions[start...currentIndex].map { $0.word.toolName })
    guard !concepts.isEmpty else { return (0, 0) }
    let lang = targetLanguage
    let descriptor = FetchDescriptor<SwiftDataWordModel>(
      predicate: #Predicate { concepts.contains($0.concept) && $0.targetLanguage == lang }
    )
    return accuracy(for: (try? modelContext.fetch(descriptor)) ?? [])
  }

  func overallAccuracy() -> (correct: Int, total: Int) {
    let lang = targetLanguage
    let descriptor = FetchDescriptor<SwiftDataWordModel>(
      predicate: #Predicate { $0.targetLanguage == lang }
    )
    return accuracy(for: (try? modelContext.fetch(descriptor)) ?? [])
  }

  private func recordGuess(for toolName: String, result: GuessResult) {
    let lang = targetLanguage
    let predicate = #Predicate<SwiftDataWordModel> { $0.concept == toolName && $0.targetLanguage == lang }
    let descriptor = FetchDescriptor<SwiftDataWordModel>(predicate: predicate)

    let record = (try? modelContext.fetch(descriptor))?.first ?? {
      let new = SwiftDataWordModel(concept: toolName, targetLanguage: lang)
      modelContext.insert(new)
      return new
    }()

    switch result {
    case .correct: record.correct += 1
    case .incorrect: record.incorrect += 1
    }
    record.lastSeen = .now

    try? modelContext.save()
  }
}
