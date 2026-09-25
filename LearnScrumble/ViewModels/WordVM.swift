// WordVM.swift
import SwiftUI
import SwiftData


// MARK: - Flow of this file
// WordVM owns one play session: the current word, the scrambled letters, and
// when to pause for a results checkpoint. It's created once by AppManager
// (startGame() or startStruggleReview()) and handed down through GamePhase
// to whichever view needs it.
//
// Called FROM the view layer:
//   - selectLetter / deselectLetter  <- user taps letter tiles
//   - checkAnswer()                  <- user submits a completed guess
//   - nextWord()                     <- user taps "continue" after seeing the result
//   - continueFromCheckpoint()       <- user taps "Play more!" on ResultView
//   - resetGuess()                   <- user taps "clear/retry" on current word
//   - hasStruggleWords               <- checked live by ResultView to decide
//                                        whether to show "Improve previous!"
//
// Called FROM AppManager (via init):
//   - checkpointMode <- .everyN(10) for normal play (pause every 10th word,
//                        more content can be fetched via fetchMore), or
//                        .endOfSession for a fixed review pool (struggle
//                        review) — pause exactly once, after the last word
//   - fetchMore    <- how WordVM asks RequestModel for more words when running
//                      low; nil for a fixed pool (e.g. struggle review)
//   - onCheckpoint <- tells AppManager "show ResultView now"
//   - onResume     <- tells AppManager "return to playing (or show LoadingView
//                      if the next batch/word isn't ready yet)" — fired from a
//                      SINGLE place, advance(), on every outcome (success,
//                      waiting on a fetch, or genuinely finished), so no
//                      caller of advance() needs to fire it separately
//
// Internal chain when the user finishes a word:
//   nextWord() -> checkpointMode decides: .everyN hits its Nth word, or
//                 .endOfSession hits the last word in the pool -> pause +
//                 onCheckpoint(); otherwise -> advance()
//   advance()  -> moves currentIndex forward and fires onResume?(), OR if
//                 we've run past what's loaded: sets pendingAdvance, kicks
//                 off requestMoreNow() if needed (or marks isFinished if
//                 there's no fetchMore at all) — then ALWAYS fires
//                 onResume?() before returning, so AppManager is notified
//                 immediately regardless of which branch was taken
//   requestMoreIfNeeded() -> auto-triggers requestMoreNow() two questions
//                 before the buffer runs out, so fetching happens quietly
//                 in the background before the user ever needs it
//   requestMoreNow() -> calls fetchMore (-> RequestModel), appends results,
//                 and if the user was already waiting (pendingAdvance),
//                 calls advance() again — which fires onResume?() itself
//
// SwiftData (progress tracking) is scoped per (word, targetLanguage) pair:
//   recordGuess()      <- saves correct/incorrect after every answered word
//   batchAccuracy()    <- % correct for the current checkpoint's window —
//                          the last N words for .everyN, or the whole pool
//                          for .endOfSession (see currentBatchWindow)
//   overallAccuracy()  <- % correct across all-time history in this target language
//   hasStruggleWords   <- true if any concept in this target language currently
//                          qualifies as isStruggle (SwiftDataWordModel), re-checked
//                          fresh on every access — never cached

@Observable
class WordVM {
  var questions: [QuestionModel]                                 // all words loaded so far this session (grows as more batches are fetched)
  var currentIndex: Int = 0                                      // index into `questions` of the word currently being played
  var guessResult: GuessResult?                                  // set by checkAnswer(); nil until the current word has been submitted
  var scrumbledWord: [LetterModel] = []                          // shuffled letter tiles the user picks from for the current word
  var guessedWord: [LetterModel?] = []                           // the answer slots being filled in as the user picks letters; nil = empty slot
  var isFinished: Bool = false                                   // true only when there's truly no more content coming (fetchMore is nil)
  private(set) var isAtCheckpoint = false                        // true while ResultView is showing, between finishing word N*10 and tapping Continue
  private let checkpointMode: CheckpointMode                            // how many words make up one batch/checkpoint cycle
  private var hasRequestedMore = false                           // guards against firing requestMoreNow() twice for the same batch boundary
  private let fetchMore: (([String]) async -> [QuestionModel])?  // closure back to RequestModel.generateMore, injected by AppManager
  private let exitToSettings: (() -> Void)?                      //exiting to Entry view/settings view
  private let onCheckpoint: (() -> Void)?                        // closure back to AppManager: "show ResultView now"
  private let onResume: (() -> Void)?                            // closure back to AppManager: "return to playing (or generating if still loading)"
  private let modelContext: ModelContext                         // SwiftData context, shared singleton from PersistenceController
  private let targetLanguage: String                             // Languages.rawValue for this session — scopes all progress queries below
  var overlayShown: Bool = false                                 // controls the correct/incorrect result overlay shown after checkAnswer()
  var isLoadingMore = false                                      // true while requestMoreNow()'s background Task is in flight
  private var pendingAdvance = false                             // true when the user is waiting on advance() but the next batch hasn't landed yet
  
  var wordSegments: [String] {                                   // splits the target word into space-separated segments (for multi-word answers)
    guard let word else { return [] }                             // no current word (e.g. end of questions) -> nothing to segment
    return word.targetWord.split(separator: " ").map(String.init) // e.g. "cutting board" -> ["cutting", "board"]
  }
  
  var segmentRanges: [Range<Int>] {                              // maps each word segment to its slice of letter-index positions
    var ranges: [Range<Int>] = []                                 // accumulates one range per segment
    var cursor = 0                                                // tracks how many letters have been consumed so far
    for seg in wordSegments {                                     // walk each segment in order
      ranges.append(cursor..<(cursor + seg.count))                // this segment occupies [cursor, cursor+length)
      cursor += seg.count                                         // advance past this segment for the next one
    }
    return ranges                                                 // e.g. "cutting board" -> [0..<7, 7..<12]
  }
  
  var resultWord: String {                                       // reconstructs the user's current guess as a displayable string
    guard !guessedWord.isEmpty else { return "" }                  // nothing guessed yet -> empty string
    var parts: [String] = []                                      // one reconstructed segment per word part
    for range in segmentRanges {                                  // rebuild segment-by-segment so spaces land in the right place
      let segment = range.map { guessedWord.indices.contains($0) ? (guessedWord[$0]?.letter ?? "*") : "*" } // "*" marks an unfilled slot
      parts.append(segment.joined())                              // collapse this segment's letters into one string
    }
    return parts.joined(separator: " ").lowercased()               // rejoin segments with spaces, normalize case for comparison
  }
  
  var hasStruggleWords: Bool {                                        // NEW — checked live each time ResultView renders, always fresh off SwiftData
    !PersistenceController.shared.struggleToolNames(targetLanguage: targetLanguage).isEmpty
  }
  
  init(questions: [QuestionModel],                                // initial batch of questions, passed in from RequestModel.generate()
       targetLanguage: String,                                    // which language this whole session is testing (drives SwiftData scoping)
       checkpointMode: CheckpointMode = .everyN(10),                // NEW — normal play keeps today's behavior by default
       fetchMore: (([String]) async -> [QuestionModel])? = nil,   // how to fetch more words when running low; nil = fixed-size session (e.g. struggle review)
       onCheckpoint: (() -> Void)? = nil,                         // callback fired every 10th word — AppManager wires this to show ResultView
       onResume: (() -> Void)? = nil,                             // callback fired when leaving the checkpoint — AppManager wires this to resume play
       exitToSettings: (() -> Void)? = nil
  ) {
    self.modelContext = PersistenceController.shared.context      // grab the shared SwiftData context once, up front
    self.questions = questions                                    // store the starting batch
    self.targetLanguage = targetLanguage                          // lock in the language this session tracks progress against
    self.checkpointMode = checkpointMode
    self.fetchMore = fetchMore                                    // store the injected fetch closure (or nil)
    self.onCheckpoint = onCheckpoint                               // store the injected checkpoint callback (or nil)
    self.onResume = onResume                                        // store the injected resume callback (or nil)
    self.exitToSettings = exitToSettings
    print("🟢 WordVM.init — \(questions.count) starting questions, targetLanguage=\(targetLanguage), fetchMore=\(fetchMore != nil)") // NEW
    setupCurrentWord()                                             // scramble letters for the very first word immediately
  }
  
  var word: WordModel? { questions.indices.contains(currentIndex) ? questions[currentIndex].word : nil }  // the word model currently being played, if any
  var hintWord: String { word?.originWord ?? "" }                                                          // the native-language hint shown to the user
  var image: UIImage? {                                            // the illustration image for the current word, if it's loaded
    guard questions.indices.contains(currentIndex),                 // make sure currentIndex is actually valid right now
          let data = questions[currentIndex].imageData else { return nil } // and that its image bytes have arrived
    return UIImage(data: data)                                     // decode the raw bytes into a displayable image
  }
  var isComplete: Bool { !guessedWord.contains(where: { $0 == nil }) }  // true once every letter slot has been filled in
  
  func setupCurrentWord() {                                        // resets scrambled tiles + empty guess slots for whatever word is now current
    guard let word else {                                           // no word to set up (e.g. ran past the end of questions)
      guessedWord = []                                              // clear guess slots
      scrumbledWord = []                                            // clear letter tiles
      print("⚪️ setupCurrentWord — no word at index \(currentIndex), clearing tiles") // NEW
      return                                                        // nothing else to do
    }
    let letters = word.targetWord                                  // start from the target-language word
      .filter { $0 != " " }                                         // strip spaces — they're not draggable tiles, just layout gaps
      .map { String($0).lowercased() }                              // normalize each character to a lowercase single-char string
    
    let totalLetters = letters.count                                // how many tiles/slots this word needs
    guessedWord = Array(repeating: nil, count: totalLetters)        // start with every slot empty
    
    var shuffledLetters = letters                                  // working copy to shuffle
    if totalLetters > 1 {                                           // only bother shuffling if there's more than one letter
      repeat {
        shuffledLetters = letters.shuffled()                        // reshuffle...
      } while shuffledLetters == letters                            // ...until it's not accidentally identical to the answer order
    } //making sure here that shuffled word isnt placing letteres same order as a target word
    
    scrumbledWord = shuffledLetters                                 // take the shuffled letters
      .enumerated()                                                 // pair each with its position
      .map { LetterModel(id: $0.offset, letter: $0.element, isUsed: false) } // wrap into tappable tile models, all initially unused
    print("🔤 setupCurrentWord — index \(currentIndex): '\(word.targetWord)' (\(totalLetters) letters), hint='\(word.originWord)'") // NEW
  }
  
  func selectLetter(_ tile: LetterModel) {                          // called when the user taps an available letter tile
    guard let emptySlot = guessedWord.firstIndex(where: { $0 == nil }) else { return } // find the next empty answer slot; bail if the answer is already full
    guard let index = scrumbledWord.firstIndex(where: { $0.id == tile.id }) else { return } // find this tile in the tray
    scrumbledWord[index].isUsed = true                              // mark it as placed so it visually disables in the tray
    guessedWord[emptySlot] = tile                                   // drop it into the next empty answer slot
    print("👉 selectLetter — placed '\(tile.letter)' at slot \(emptySlot), current guess='\(resultWord)'") // NEW
  }
  
  func deselectLetter(_ tile: LetterModel) {                        // called when the user taps a tile they'd already placed, to undo it
    guard let slotIndex = guessedWord.firstIndex(where: { $0?.id == tile.id }) else { return } // find where this tile currently sits in the answer
    guard let index = scrumbledWord.firstIndex(where: { $0.id == tile.id }) else { return } // find it back in the tray
    scrumbledWord[index].isUsed = false                             // mark it available again in the tray
    guessedWord[slotIndex] = nil                                    // clear that answer slot
    print("👈 deselectLetter — removed '\(tile.letter)' from slot \(slotIndex), current guess='\(resultWord)'") // NEW
  }
  
  func checkAnswer() {                                              // called when the user submits their completed guess
    guard isComplete, let word else { return }                       // only score once every slot is filled and there's a real word
    let isCorrect = resultWord == word.targetWord.lowercased() // compare guess to the target word, spaces stripped, case-insensitive
    guessResult = isCorrect ? .correct : .incorrect                  // record the verdict for the UI
    overlayShown = true                                              // trigger the result overlay to appear
    print("✅❌ checkAnswer — guessed='\(resultWord)' target='\(word.targetWord)' -> \(isCorrect ? "CORRECT" : "INCORRECT")") // NEW
    recordGuess(for: word.toolName, result: guessResult!)            // persist this attempt to SwiftData, keyed by the canonical concept name
  }
  
  func nextWord() {
    guessResult = nil
    let nextIndex = currentIndex + 1
    
    switch checkpointMode {
    case .everyN(let interval):
      if nextIndex % interval == 0 {
        isAtCheckpoint = true
        print("🏁 nextWord — checkpoint at word #\(nextIndex) (every \(interval)), holding at index \(currentIndex)")
        onCheckpoint?()
        return
      }
    case .endOfSession:
      if nextIndex >= questions.count {
        isAtCheckpoint = true
        isFinished = true                                          // this pool is exhausted — there's genuinely nothing after this checkpoint
        print("🏁 nextWord — final word answered (\(questions.count) total), showing end-of-session result")
        onCheckpoint?()
        return
      }
    }
    
    print("➡️ nextWord — advancing from index \(currentIndex) to \(nextIndex)")
    advance(to: nextIndex)
  }
  
  /// Called from ResultView's Continue action.
  func continueFromCheckpoint() {
    isAtCheckpoint = false
    guard !isFinished else {                                        // .endOfSession already hit its true end — nothing left to advance into
      print("🔚 continueFromCheckpoint — session already finished, nothing to advance, letting AppManager route away")
      onResume?()
      return
    }
    print("▶️ continueFromCheckpoint — leaving checkpoint, attempting advance to index \(currentIndex + 1)")
    advance(to: currentIndex + 1)
    onResume?()// RESTORE — leaving .result needs its own explicit signal
  }

  private func advance(to index: Int) {                              // the single place that actually moves currentIndex forward
    guard index < questions.count else {                              // we've run past what's currently loaded
      if isLoadingMore {                                              // a fetch is already in flight
        pendingAdvance = true                                        // remember to advance automatically once it lands
        print("⏳ advance(\(index)) — out of bounds (\(questions.count) loaded), fetch already in flight, setting pendingAdvance")
      } else if fetchMore != nil {                                    // no fetch in flight, but more content is possible
        pendingAdvance = true                                        // remember to advance once this fetch (below) resolves
        print("🚨 advance(\(index)) — out of bounds, no fetch in flight, triggering safety-net fetch now")
        requestMoreNow()                                              // safety net — fetch wasn't pre-triggered in time, so fetch right now
      } else {                                                        // no fetchMore at all — this is a fixed-size session (e.g. struggle review)
        isFinished = true                                             // genuinely nothing left — signal true end of session
        print("🔚 advance(\(index)) — out of bounds, no fetchMore source, marking session isFinished")
      }
      onResume?()                                                     // NEW — tell AppManager right now: waiting on a fetch means show LoadingView
      return
    }
    currentIndex = index                                              // move to the requested word
    setupCurrentWord()                                                 // scramble its letters / reset guess slots
    requestMoreIfNeeded()                                              // opportunistically kick off a background prefetch if we're getting close to the end
    overlayShown = false                                               // hide any leftover result overlay from the previous word
    print("📍 advance — now at index \(currentIndex) of \(questions.count) loaded questions")
  }
  
  private func requestMoreIfNeeded() {                                // decides whether it's time to quietly start fetching the next batch
    guard !hasRequestedMore,                                           // don't double-fire for the same batch
          currentIndex == questions.count - 2,                         // trigger two words before the buffer runs out, to hide fetch latency
          fetchMore != nil else { return }                             // only makes sense if a fetch source exists
    print("🛰️ requestMoreIfNeeded — index \(currentIndex) is 2 from end of \(questions.count), triggering prefetch") // NEW
    requestMoreNow()                                                   // conditions met — kick off the real fetch
  }
  
  private func requestMoreNow() {                                    // actually performs the background fetch for more questions
    guard let fetchMore, !isLoadingMore else {
      print("⛔️ requestMoreNow — skipped (fetchMore=\(self.fetchMore != nil), isLoadingMore=\(isLoadingMore))") // NEW
      return
    }                 // need a fetch source, and don't stack a second fetch on top of one in flight
    hasRequestedMore = true                                            // mark this batch's prefetch as claimed
    isLoadingMore = true                                               // flag that a fetch is now in progress (drives LoadingView decisions upstream)
    let existingToolNames = questions.map { $0.word.toolName }         // ← was targetWord  // build the exclusion list using the canonical (language-independent) word key
    print("📡 requestMoreNow — fetching more, excluding \(existingToolNames.count) toolNames: \(existingToolNames)") // NEW
    
    Task {                                                             // run the fetch off the main flow so the UI isn't blocked
      let newQuestions = await fetchMore(existingToolNames)             // ask RequestModel for a new batch, excluding what we've already got
      questions.append(contentsOf: newQuestions)                       // grow the session's question list with the new batch
      isLoadingMore = false                                            // fetch is done
      hasRequestedMore = false                                         // allow the next batch's prefetch to fire when its turn comes
      print("📥 requestMoreNow — fetch resolved, appended \(newQuestions.count) new questions, total now \(questions.count)") // NEW
      
      if pendingAdvance {                                              // the user was waiting on this fetch to finish
        pendingAdvance = false                                         // clear the wait flag
        print("🔓 requestMoreNow — pendingAdvance was set, advancing user now that fetch landed") // NEW
        advance(to: currentIndex + 1)                                  // now actually move them into the newly-arrived word
        onResume?()                                   // RESTORE — fetch just resolved, this is the actual unstick signal
      }
    }
  }
  
  func resetGuess() {                                                 // called when the user wants to clear their current attempt and retry
    for tile in guessedWord.compactMap({ $0 }) {                       // walk every letter currently placed in the answer
      if let idx = scrumbledWord.firstIndex(where: { $0.id == tile.id }) { // find it back in the tray
        scrumbledWord[idx].isUsed = false                              // mark it available again
      }
    }
    guessedWord = Array(repeating: nil, count: guessedWord.count)      // empty out every answer slot
    print("♻️ resetGuess — cleared all answer slots for index \(currentIndex)") // NEW
  }
  
  // MARK: - SwiftData stats (scoped to this session's target language)
  
  private func accuracy(for records: [SwiftDataWordModel]) -> (correct: Int, total: Int) { // sums correct/incorrect across a set of SwiftData records
    let correct = records.reduce(0) { $0 + $1.correct }               // total correct answers across all matched records
    let incorrect = records.reduce(0) { $0 + $1.incorrect }           // total incorrect answers across all matched records
    return (correct, correct + incorrect)                             // return correct count alongside the overall attempt count
  }
  
  private var currentBatchWindow: ArraySlice<QuestionModel> {        // NEW — replaces the old fixed 10-word window
    guard questions.indices.contains(currentIndex) else { return [] }
    switch checkpointMode {
    case .everyN(let interval):
      let start = max(currentIndex - interval + 1, 0)
      return questions[start...currentIndex]
    case .endOfSession:
      return questions[0...currentIndex]                            // the whole review pool is "this batch"
    }
  }
  
  func batchAccuracy() -> (correct: Int, total: Int) {
    let concepts = Set(currentBatchWindow.map { $0.word.toolName })
    guard !concepts.isEmpty else { return (0, 0) }
    let lang = targetLanguage
    let descriptor = FetchDescriptor<SwiftDataWordModel>(
      predicate: #Predicate { concepts.contains($0.concept) && $0.targetLanguage == lang }
    )
    let result = accuracy(for: (try? modelContext.fetch(descriptor)) ?? [])
    print("📊 batchAccuracy — \(concepts.count) concepts, lang=\(lang) -> \(result.correct)/\(result.total)")
    return result
  }
  
  func overallAccuracy() -> (correct: Int, total: Int) {               // % correct across all-time history in the current target language
    let lang = targetLanguage                                          // capture for use inside the #Predicate closure
    let descriptor = FetchDescriptor<SwiftDataWordModel>(
      predicate: #Predicate { $0.targetLanguage == lang }               // every concept ever tracked in this language, no batch limit
    )
    let result = accuracy(for: (try? modelContext.fetch(descriptor)) ?? []) // fetch and summarize; empty array on failure
    print("📈 overallAccuracy — lang=\(lang) -> \(result.correct)/\(result.total)") // NEW
    return result
  }
  
  private func recordGuess(for toolName: String, result: GuessResult) { // persists one answered word's outcome to SwiftData
    let lang = targetLanguage                                          // capture for use inside the #Predicate closure
    let predicate = #Predicate<SwiftDataWordModel> { $0.concept == toolName && $0.targetLanguage == lang } // find this exact (word, language) row
    let descriptor = FetchDescriptor<SwiftDataWordModel>(predicate: predicate) // wrap the predicate into a fetch request
    
    let existing = (try? modelContext.fetch(descriptor))?.first        // NEW — split out so we can log whether it's new vs existing
    let record = existing ?? {                                          // reuse the existing row if one exists...
      let new = SwiftDataWordModel(concept: toolName, targetLanguage: lang) // ...otherwise create a fresh one for this (word, language) pair
      modelContext.insert(new)                                          // register it with SwiftData
      return new                                                        // hand it back for updating below
    }()
    print("💾 recordGuess — concept='\(toolName)' lang=\(lang) [\(existing == nil ? "NEW row" : "existing row")], result=\(result)") // NEW
    
    switch result {                                                    // bump whichever counter matches this attempt
    case .correct: record.correct += 1                                 // one more correct attempt
    case .incorrect: record.incorrect += 1                             // one more incorrect attempt
    }
    record.lastSeen = .now                                             // stamp when this word was last practiced
    
    try? modelContext.save()                                           // persist the change to disk
    print("💾 recordGuess — saved. '\(toolName)' now correct=\(record.correct) incorrect=\(record.incorrect) accuracy=\(record.accuracy)") // NEW
  }
  
  func exit() {// called by ResultView's exit button
    print("🚪 WordVM.exit — user backed out, notifying AppManager")
    exitToSettings?()
  }
}
