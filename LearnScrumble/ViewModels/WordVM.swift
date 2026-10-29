// WordVM.swift
import SwiftUI
import SwiftData


// MARK: - Flow of this file
// WordVM owns one play session: the current word, the scrambled letters, and
// when to pause for a results checkpoint. It's created once by AppManager
// (startGame() or startReview()) and handed down through GamePhase
// to whichever view needs it.
//
// Called FROM the view layer:
//   - selectLetter / deselectLetter  <- user taps letter tiles
//   - checkAnswer()                  <- user submits a completed guess
//   - nextWord()                     <- user taps "continue" after seeing the result
//   - continueFromCheckpoint()       <- user taps "Play more!" on ResultView
//   - resetGuess()                   <- user taps "clear/retry" on current word
//   - reportPicture()                <- user confirms the flag on the picture: the server may draw a new one,
//                                        which replaces the picture here and in the saved word
//
// Called FROM AppManager (via init):
//   - checkpointMode <- .everyN(10) for normal play (pause every 10th word,
//                        more content can be fetched via fetchMore), or
//                        .endOfSession — pause exactly once, after the last word
//   - fetchMore    <- how WordVM asks RequestModel for more words when running
//                      low; nil for a fixed pool (the "My words" review, the
//                      tutorial): the last word always ends with a checkpoint
//   - profession / originLanguage <- saved with each new word, so "My words"
//                      can list and replay it without the server
//   - onCheckpoint <- tells AppManager "show ResultView now"
//   - onResume     <- tells AppManager "return to playing (or show LoadingView
//                      if the next batch/word isn't ready yet)" — fired from a
//                      SINGLE place, advance(), on every outcome (success,
//                      waiting on a fetch, or genuinely finished), so no
//                      caller of advance() needs to fire it separately
//
// Internal chain when the user finishes a word:
//   nextWord() -> checkpointMode decides: .everyN hits its Nth word, or
//                 .endOfSession or a fixed pool hits its last word -> pause +
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
//   recordGuess()      <- saves correct/incorrect after every answered word, and the whole
//                          word (job, words, picture) the first time it's answered
//   batchAccuracy()    <- % correct for the current checkpoint's window —
//                          the last N words for .everyN, or the whole pool
//                          for .endOfSession (see currentBatchWindow)
//   overallAccuracy()  <- % correct across all-time history in this target language
//   jobProgress()      <- learned / played words of this session's job (ResultView)

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
  private let fetchMore: (([String]) async -> [QuestionModel])?  // closure back to RequestModel.generateMore, injected by AppManager                    //exiting to Entry view/settings view
  private let onCheckpoint: (() -> Void)?                        // closure back to AppManager: "show ResultView now"
  private let onResume: (() -> Void)?                            // closure back to AppManager: "return to playing (or generating if still loading)"
  private let onFetchFailed: (() -> Void)?        // closure back to AppManager: "the user is waiting and the fetch failed — show ErrorView"
  private let onWordAnswered: (() -> Void)?            // AppManager: count this word toward the 10 free words
  private let canContinue: (() -> Bool)?               // AppManager: may the user play another word?
  private let canFetchMore: ((Int) -> Bool)?           // AppManager: may we download more, given how many words are still unplayed?
  private let onReportPicture: ((QuestionModel) async -> RequestModel.ReportResult)?   // AppManager -> RequestModel.reportPicture; nil = no flag (tutorial)
  private(set) var pictureReport: PictureReport = .idle          // the current word's report, shown on the picture (ImageComponent)
  private let isPractice: Bool                         // tutorial word (OnboardingService): answers aren't saved to progress
  private let modelContext: ModelContext                         // SwiftData context, shared singleton from PersistenceController
  private let targetLanguage: String                             // Languages.rawValue for this session — scopes all progress queries below
  let profession: String                                         // the job this session is for (Occupation rawValue) — saved with new words
  private let originLanguage: String                             // the hint's language — saved with new words
  var overlayShown: Bool = false                                 // controls the correct/incorrect result overlay shown after checkAnswer()
  var isLoadingMore = false                                      // true while requestMoreNow()'s background Task is in flight
  private(set) var pendingAdvance = false                             // true when the user is waiting on advance() but the next batch hasn't landed yet
  var isRightToleft: Bool {                                      // target language written right-to-left -> MainView flips the answer row
    Languages(rawValue: targetLanguage)?.isRtL ?? false
  }
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
  
  // MARK: - init
  // Builds the session from the first batch and whatever AppManager wired in:
  //   questions       — initial batch of questions, from RequestModel.generate() (or the review pool)
  //   targetLanguage  — which language this whole session is testing (drives SwiftData scoping)
  //   profession / originLanguage — saved with every new word (default "" for the tutorial, which saves nothing)
  //   checkpointMode  — NEW, .everyN(10) by default so normal play keeps today's behavior
  //   fetchMore       — how to fetch more words when running low; nil = fixed-size session ("My words" review, tutorial)
  //   onCheckpoint    — fired every 10th word; AppManager wires this to show ResultView
  //   onResume        — fired when leaving the checkpoint; AppManager wires this to resume play
  //   onFetchFailed / onWordAnswered / canContinue / canFetchMore — see the properties above
  //   onReportPicture — how a picture report reaches the server; nil hides the flag
  //   isPractice      — true for the "How to play" tutorial: nothing is saved to SwiftData
  // Steps: grab the shared SwiftData context once, up front -> store the starting batch, lock in the language
  // this session tracks progress against, store every injected closure (or nil) -> scramble letters for the
  // very first word immediately -> start a prefetch if the batch is already short.
  init(questions: [QuestionModel],
       targetLanguage: String,
       profession: String = "",
       originLanguage: String = "",
       checkpointMode: CheckpointMode = .everyN(10),
       fetchMore: (([String]) async -> [QuestionModel])? = nil,
       onCheckpoint: (() -> Void)? = nil,
       onResume: (() -> Void)? = nil,
       onFetchFailed: (() -> Void)? = nil,
       onWordAnswered: (() -> Void)? = nil,
       canContinue: (() -> Bool)? = nil,
       canFetchMore: ((Int) -> Bool)? = nil,
       onReportPicture: ((QuestionModel) async -> RequestModel.ReportResult)? = nil,
       isPractice: Bool = false
  ) {
    self.modelContext = PersistenceController.shared.context
    self.questions = questions
    self.targetLanguage = targetLanguage
    self.profession = profession
    self.originLanguage = originLanguage
    self.checkpointMode = checkpointMode
    self.fetchMore = fetchMore
    self.onCheckpoint = onCheckpoint
    self.onResume = onResume
    self.onFetchFailed = onFetchFailed
    self.onWordAnswered = onWordAnswered
    self.canContinue = canContinue
    self.canFetchMore = canFetchMore
    self.onReportPicture = onReportPicture
    self.isPractice = isPractice
    Log.info("🟢 WordVM.init — \(questions.count) starting questions, targetLanguage=\(targetLanguage), fetchMore=\(fetchMore != nil)", .game)
    setupCurrentWord()
    requestMoreIfNeeded()
  }
  
  var word: WordModel? { questions.indices.contains(currentIndex) ? questions[currentIndex].word : nil }  // the word model currently being played, if any
  var hintWord: String { word?.originWord ?? "" }                                                          // the native-language hint shown to the user
  var image: UIImage? {                                            // the illustration image for the current word, if it's loaded
    guard questions.indices.contains(currentIndex),                 // make sure currentIndex is actually valid right now
          let data = questions[currentIndex].imageData else { return nil } // and that its image bytes have arrived
    return UIImage(data: data)                                     // decode the raw bytes into a displayable image
  }
  var isComplete: Bool { !guessedWord.contains(where: { $0 == nil }) }  // true once every letter slot has been filled in
  var canReport: Bool { onReportPicture != nil }                   // show the flag on the picture
  
  // MARK: - setupCurrentWord
  // Resets scrambled tiles + empty guess slots for whatever word is now current.
  // 1. No word (e.g. ran past the end of questions) -> clear slots and tiles, nothing else to do.
  // 2. Letters = the target-language word with spaces stripped (they're not tiles, just layout gaps),
  //    each character lowercased.
  // 3. Every answer slot starts empty (one per letter).
  // 4. Shuffle — only if there are at least two DIFFERENT letters, so another order exists ("mm" or "妈妈" skip this):
  //    reshuffle until it differs from the answer, but never more than 10 tries; still in answer order
  //    after that (very rare, e.g. "ab") -> move the first letter to the end: always a different order.
  // 5. Wrap each shuffled letter into a tappable LetterModel tile (id = its position), all unused.
  func setupCurrentWord() {
    pictureReport = .idle                                         // a new word starts without a report
    guard let word else {
      guessedWord = []
      scrumbledWord = []
      Log.debug("⚪️ setupCurrentWord — no word at index \(currentIndex), clearing tiles", .game)
      return
    }
    let letters = word.targetWord
      .filter { $0 != " " }
      .map { String($0).lowercased() }

    let totalLetters = letters.count
    guessedWord = Array(repeating: nil, count: totalLetters)

    var shuffledLetters = letters
    if Set(letters).count > 1 {
      var attempts = 0
      repeat {
        shuffledLetters = letters.shuffled()
        attempts += 1
      } while shuffledLetters == letters && attempts < 10

      if shuffledLetters == letters {
        shuffledLetters = Array(letters.dropFirst()) + [letters[0]]
      }
    }

    scrumbledWord = shuffledLetters
      .enumerated()
      .map { LetterModel(id: $0.offset, letter: $0.element, isUsed: false) }
    Log.debug("🔤 setupCurrentWord — index \(currentIndex): '\(word.targetWord)' (\(totalLetters) letters), hint='\(word.originWord)'", .game)
  }
  
  // MARK: - selectLetter
  // Called when the user taps an available letter tile (LetterBoxView -> MainView).
  // Finds the next empty answer slot (answer already full -> nothing) and the tile in the tray,
  // marks the tile as placed (it dims in the tray) and drops it into that slot.
  func selectLetter(_ tile: LetterModel) {
    guard let emptySlot = guessedWord.firstIndex(where: { $0 == nil }) else { return }
    guard let index = scrumbledWord.firstIndex(where: { $0.id == tile.id }) else { return }
    scrumbledWord[index].isUsed = true
    guessedWord[emptySlot] = tile
    Log.debug("👉 selectLetter — placed '\(tile.letter)' at slot \(emptySlot), current guess='\(resultWord)'", .game)
  }
  
  // MARK: - deselectLetter
  // Called when the user taps a tile they'd already placed, to undo it (GuessedLetterView).
  // Finds where the tile sits in the answer and in the tray, marks it available again and clears that slot.
  func deselectLetter(_ tile: LetterModel) {
    guard let slotIndex = guessedWord.firstIndex(where: { $0?.id == tile.id }) else { return }
    guard let index = scrumbledWord.firstIndex(where: { $0.id == tile.id }) else { return }
    scrumbledWord[index].isUsed = false
    guessedWord[slotIndex] = nil
    Log.debug("👈 deselectLetter — removed '\(tile.letter)' from slot \(slotIndex), current guess='\(resultWord)'", .game)
  }
  
  // MARK: - checkAnswer
  // Called when every slot is filled (MainView .onChange of isComplete).
  // 1. Only scores when the answer is complete and there's a real word.
  // 2. Compares the guess to the target word, case-insensitive (resultWord is already lowercased, with spaces between words).
  // 3. Records the verdict for the UI (guessResult) and shows the result overlay.
  // 4. recordGuess: saves this attempt to SwiftData, keyed by the canonical concept name
  //    (skipped for the tutorial's practice word, so it never shows up in stats or "My words"),
  //    and Streak.shared.recordPlay(): today counts as a day played.
  // 5. onWordAnswered: counts it toward the free words, right or wrong (not wired for the review).
  func checkAnswer() {
    guard isComplete, let word else { return }
    let isCorrect = resultWord == word.targetWord.lowercased()
    guessResult = isCorrect ? .correct : .incorrect
    overlayShown = true
    Log.debug("✅❌ checkAnswer — guessed='\(resultWord)' target='\(word.targetWord)' -> \(isCorrect ? "CORRECT" : "INCORRECT")", .game)
    if !isPractice {
      recordGuess(for: questions[currentIndex], result: guessResult!)
      Streak.shared.recordPlay()
    }
    onWordAnswered?()
  }
  
  // MARK: - nextWord
  // "Next" on AnswerResultView.
  // 1. Clears the verdict. Free daily limit reached (canContinue false) -> end the round here with a checkpoint.
  // 2. A fixed pool (no fetchMore) or .endOfSession: that was the last word -> checkpoint and isFinished
  //    (this pool is exhausted — there's genuinely nothing after this checkpoint).
  //    .everyN: the next word would be the Nth -> checkpoint (ResultView), staying on the current index.
  // 3. Otherwise -> advance() to the next word.
  func nextWord() {
    guessResult = nil
    if let canContinue, !canContinue() {
      isAtCheckpoint = true
      Log.info("⛔️ nextWord — free words used up, ending the round", .game)
      onCheckpoint?()
      return
    }
    let nextIndex = currentIndex + 1

    if fetchMore == nil, nextIndex >= questions.count {            // fixed pool: nothing comes after the last word
      isAtCheckpoint = true
      isFinished = true
      Log.info("🏁 nextWord — last word of a fixed pool (\(questions.count) total), showing end-of-session result", .game)
      onCheckpoint?()
      return
    }

    switch checkpointMode {
    case .everyN(let interval):
      if nextIndex % interval == 0 {
        isAtCheckpoint = true
        Log.info("🏁 nextWord — checkpoint at word #\(nextIndex) (every \(interval)), holding at index \(currentIndex)", .game)
        onCheckpoint?()
        return
      }
    case .endOfSession:
      if nextIndex >= questions.count {
        isAtCheckpoint = true
        isFinished = true
        Log.info("🏁 nextWord — final word answered (\(questions.count) total), showing end-of-session result", .game)
        onCheckpoint?()
        return
      }
    }

    Log.debug("➡️ nextWord — advancing from index \(currentIndex) to \(nextIndex)", .game)
    advance(to: nextIndex)
  }
  
  // MARK: - continueFromCheckpoint
  // Called from ResultView's Continue action.
  // 1. Daily limit reached -> don't advance; onResume lets AppManager route away.
  // 2. Leaves the checkpoint. .endOfSession already hit its true end -> nothing left to advance into, let AppManager route away.
  // 3. Otherwise advance() to the next word. advance() already notified AppManager if we're now waiting on a fetch —
  //    so onResume is only signalled here when the next word was ready.
  func continueFromCheckpoint() {
    if let canContinue, !canContinue() {
      Log.info("⛔️ continueFromCheckpoint — free words used up, not advancing", .game)
      onResume?()
      return
    }
    isAtCheckpoint = false
    guard !isFinished else {
      Log.info("🔚 continueFromCheckpoint — session already finished, nothing to advance, letting AppManager route away", .game)
      onResume?()
      return
    }
    Log.info("▶️ continueFromCheckpoint — leaving checkpoint, attempting advance to index \(currentIndex + 1)", .game)
    advance(to: currentIndex + 1)
      if !pendingAdvance { onResume?() }
  }
  
  // MARK: - advance(to:)
  // The single place that actually moves currentIndex forward.
  // Ran past what's currently loaded:
  //   - a fetch is already in flight -> pendingAdvance: advance automatically once it lands
  //   - no fetch in flight but more content is possible -> pendingAdvance + fetch right now
  //     (safety net — the prefetch wasn't triggered in time)
  //   - no fetchMore at all (fixed-size session, e.g. the "My words" review) -> isFinished: genuinely nothing left
  //   then (NEW) onResume right away — waiting on a fetch means AppManager shows LoadingView.
  // Otherwise: move to the requested word -> scramble its letters / reset guess slots
  // -> kick off a background prefetch if we're getting close to the end -> hide the previous word's result overlay.
  private func advance(to index: Int) {
    guard index < questions.count else {
      if isLoadingMore {
        pendingAdvance = true
        Log.info("⏳ advance(\(index)) — out of bounds (\(questions.count) loaded), fetch already in flight, setting pendingAdvance", .game)
      } else if fetchMore != nil {
        pendingAdvance = true
        Log.info("🚨 advance(\(index)) — out of bounds, no fetch in flight, triggering safety-net fetch now", .game)
        requestMoreNow()
      } else {
        isFinished = true
        Log.info("🔚 advance(\(index)) — out of bounds, no fetchMore source, marking session isFinished", .game)
      }
      onResume?()
      return
    }
    currentIndex = index
    setupCurrentWord()
    requestMoreIfNeeded()
    overlayShown = false
    Log.debug("📍 advance — now at index \(currentIndex) of \(questions.count) loaded questions", .game)
  }
  
  private let prefetchThreshold = 3                                    // start the next batch when only this many words (incl. the current one) are left — 3 words of play time to hide the server call + new pictures

  // MARK: - requestMoreIfNeeded
  // Decides whether it's time to quietly start fetching the next batch. Only when:
  //   - no fetch already claimed for this batch (don't double-fire while one is in flight)
  //   - few enough words left (≤ prefetchThreshold) — also retries on the next word if a prefetch failed
  //   - a fetch source exists
  //   - canFetchMore: a free user wouldn't hit the daily limit before needing these words
  // Then -> requestMoreNow().
  private func requestMoreIfNeeded() {
    guard !hasRequestedMore,
          questions.count - currentIndex <= prefetchThreshold,
          fetchMore != nil else { return }
    let unplayed = questions.count - currentIndex
    guard canFetchMore?(unplayed) ?? true else {
      Log.debug("⛔️ requestMoreIfNeeded — skipping prefetch, free words used up", .game)
      return
    }
    Log.info("🛰️ requestMoreIfNeeded — index \(currentIndex), \(unplayed) of \(questions.count) left, triggering prefetch", .game)
    requestMoreNow()
  }
  
  // MARK: - requestMoreNow
  // Actually performs the background fetch for more questions.
  // 1. Needs a fetch source, and never stacks a second fetch on top of one in flight.
  // 2. Marks this batch's prefetch as claimed and isLoadingMore (drives LoadingView decisions upstream).
  // 3. Exclusion list = the canonical, language-independent toolNames already in this session (was targetWord).
  // 4. Task on the main thread (UI state changes must happen there): await fetchMore -> append the new questions,
  //    clear the loading flags.
  // 5. Nobody waiting (background prefetch) -> done; if it failed, the safety net in advance() retries later.
  //    User was waiting (pendingAdvance) and nothing came back -> onFetchFailed (ErrorView) instead of looping back into advance().
  //    User was waiting and words arrived -> advance() to the next word + onResume.
  private func requestMoreNow() {
    guard let fetchMore, !isLoadingMore else {
      Log.debug("⛔️ requestMoreNow — skipped (fetchMore=\(self.fetchMore != nil), isLoadingMore=\(isLoadingMore))", .game)
      return
    }
    hasRequestedMore = true
    isLoadingMore = true
    let existingToolNames = questions.map { $0.word.toolName }
    Log.info("📡 requestMoreNow — fetching more, excluding \(existingToolNames.count) toolNames", .game, private: "\(existingToolNames)")

    Task { @MainActor in
      let newQuestions = await fetchMore(existingToolNames)
      questions.append(contentsOf: newQuestions)
      isLoadingMore = false
      hasRequestedMore = false
      Log.info("📥 requestMoreNow — fetch resolved, appended \(newQuestions.count) new questions, total now \(questions.count)", .game)

      guard pendingAdvance else { return }
      pendingAdvance = false

      if newQuestions.isEmpty {
        Log.error("❌ requestMoreNow — user was waiting and fetch returned nothing, reporting failure", .game)
        onFetchFailed?()
        return
      }
      advance(to: currentIndex + 1)
      onResume?()
    }
  }
  
  // MARK: - resetGuess
  // Called when the user wants to clear their current attempt and retry (ResultWordRow's arrow).
  // Every placed letter is marked available again in the tray, and every answer slot is emptied.
  func resetGuess() {
    for tile in guessedWord.compactMap({ $0 }) {
      if let idx = scrumbledWord.firstIndex(where: { $0.id == tile.id }) {
        scrumbledWord[idx].isUsed = false
      }
    }
    guessedWord = Array(repeating: nil, count: guessedWord.count)
    Log.debug("♻️ resetGuess — cleared all answer slots for index \(currentIndex)", .game)
  }
  
  // MARK: - reportPicture
  // The user confirmed the flag on the picture (ImageComponent).
  // 1. No report hook, or a report already running/finished for this word -> nothing.
  // 2. .sending (the picture shows "Drawing a new picture…") -> onReportPicture -> RequestModel.reportPicture.
  // 3. A new picture came back (drawn for this user, or the already-fixed shared one) -> replaces this question's
  //    picture and link, and the saved word's (if the word was already answered): this phone keeps it in "My words"
  //    and the review, whatever the developer decides for everyone else. -> .redrawn
  //    Otherwise .received / .tooMany / .failed — ImageComponent shows a short note for each.
  //    The user moved on meanwhile -> the result is dropped (the next word has its own state).
  func reportPicture() async {
    guard let onReportPicture, pictureReport == .idle, questions.indices.contains(currentIndex) else { return }
    let index = currentIndex
    let question = questions[index]
    pictureReport = .sending
    let result = await onReportPicture(question)
    guard currentIndex == index else { return }
    switch result {
    case .newPicture(let data, let link):
      questions[index].imageData = data
      questions[index].imageURL = link
      updateSavedPicture(for: question.word.toolName, data: data, link: link)
      pictureReport = .redrawn
    case .received: pictureReport = .received
    case .tooMany:  pictureReport = .tooMany
    case .failed:   pictureReport = .failed
    }
  }

  // MARK: - updateSavedPicture(for:data:link:)
  // The saved word (this language) gets the new picture and link. Not answered yet -> no row: recordGuess saves the
  // new picture later, because it reads it from the question.
  private func updateSavedPicture(for toolName: String, data: Data, link: String) {
    let lang = targetLanguage
    let descriptor = FetchDescriptor<SwiftDataWordModel>(predicate: #Predicate { $0.concept == toolName && $0.targetLanguage == lang })
    guard let record = (try? modelContext.fetch(descriptor))?.first else { return }
    record.imageData = data
    record.imageURL = link
    try? modelContext.save()
  }

  // MARK: - SwiftData stats (scoped to this session's target language)

    // MARK: - accuracy(for:)
    // Sums correct/incorrect across a set of SwiftData records -> (correct, all attempts).
    private func accuracy(for records: [SwiftDataWordModel]) -> (correct: Int, total: Int) {
      let correct = records.reduce(0) { $0 + $1.correct }
      let incorrect = records.reduce(0) { $0 + $1.incorrect }
      return (correct, correct + incorrect)
    }

    private var currentBatchWindow: ArraySlice<QuestionModel> {        // the words in the current checkpoint window
      guard questions.indices.contains(currentIndex) else { return [] }
      switch checkpointMode {
      case .everyN(let interval):
        let start = currentIndex / interval * interval              // start of this round — also right for a shorter last round of a fixed pool
        return questions[start...currentIndex]
      case .endOfSession:
        return questions[0...currentIndex]                            // the whole review pool is "this batch"
      }
    }

    // MARK: - batchAccuracy
    // Correct vs all answers for the current checkpoint's words only (ResultView "This round").
    // The words in currentBatchWindow -> their concepts -> fetch those records in this language -> accuracy(for:).
    // No words -> (0, 0).
    func batchAccuracy() -> (correct: Int, total: Int) {
      let concepts = Set(currentBatchWindow.map { $0.word.toolName })
      guard !concepts.isEmpty else { return (0, 0) }
      let lang = targetLanguage
      let descriptor = FetchDescriptor<SwiftDataWordModel>(
        predicate: #Predicate { concepts.contains($0.concept) && $0.targetLanguage == lang }
      )
      let result = accuracy(for: (try? modelContext.fetch(descriptor)) ?? [])
      Log.debug("📊 batchAccuracy — \(concepts.count) concepts, lang=\(lang) -> \(result.correct)/\(result.total)", .game)
      return result
    }

    // MARK: - overallAccuracy
    // Correct vs all answers across all-time history (ResultView "All time") — the logic lives in PersistenceController.
    func overallAccuracy() -> (correct: Int, total: Int) {
      PersistenceController.shared.overallAccuracy(targetLanguage: targetLanguage)
    }

    // MARK: - jobProgress
    // Learned words and right / wrong answers of this session's job in this language (ResultView's progress card).
    func jobProgress() -> JobProgress {
      PersistenceController.shared.jobProgress(profession: profession, targetLanguage: targetLanguage)
    }
  
    // MARK: - recordGuess(for:result:)
    // Saves one answered word's outcome to SwiftData.
    // 1. Finds this exact (word, language) row — the language is captured first for use inside #Predicate.
    // 2. Reuses the existing row, or creates and inserts a fresh one for this (word, language) pair (NEW: logs which).
    // 3. A row without the whole word yet (new, or saved before 28 Oct 2026) gets it now: job, both words,
    //    picture prompt and picture — "My words" and the review then need no server.
    // 4. Bumps whichever counter matches this attempt, stamps when the word was last practiced.
    // 5. Saves the change to disk.
    private func recordGuess(for question: QuestionModel, result: GuessResult) {
      let toolName = question.word.toolName
      let lang = targetLanguage
      let predicate = #Predicate<SwiftDataWordModel> { $0.concept == toolName && $0.targetLanguage == lang }
      let descriptor = FetchDescriptor<SwiftDataWordModel>(predicate: predicate)

      let existing = (try? modelContext.fetch(descriptor))?.first
      let record = existing ?? {
        let new = SwiftDataWordModel(concept: toolName, targetLanguage: lang)
        modelContext.insert(new)
        return new
      }()
      Log.debug("💾 recordGuess — concept='\(toolName)' lang=\(lang) [\(existing == nil ? "NEW row" : "existing row")], result=\(result)", .game)

      if !record.hasWord, !profession.isEmpty {
        record.profession = profession
        record.targetWord = question.word.targetWord
        record.originWord = question.word.originWord
        record.originLanguage = originLanguage
        record.imagePrompt = question.word.imagePrompt
        record.imageData = question.imageData
        record.imageURL = question.imageURL ?? ""
      }

      switch result {
      case .correct: record.correct += 1
      case .incorrect: record.incorrect += 1
      }
      record.lastSeen = .now

      try? modelContext.save()
      Log.debug("💾 recordGuess — saved. '\(toolName)' now correct=\(record.correct) incorrect=\(record.incorrect) accuracy=\(record.accuracy)", .game)
    }
}

// MARK: - PictureReport
// Where the current word's picture report stands (WordVM.reportPicture -> ImageComponent).
enum PictureReport: Equatable {
  case idle                 // not reported: the flag shows
  case sending              // waiting for the server (a new picture can take ~20 s)
  case redrawn              // a new picture replaced the wrong one on this phone
  case received             // recorded, a person will check it
  case tooMany              // today's reports are used up
  case failed               // couldn't send it (offline, server problem)
}
