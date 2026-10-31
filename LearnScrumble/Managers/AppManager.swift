// AppManager.swift
import SwiftUI

// MARK: - Flow of this file
// AppManager is the single source of truth for what's on screen (phase) and
// owns the one active WordVM for the current session. RootView just switches
// on `phase` and renders accordingly — all the actual decisions happen here.
//
// Two entry points build a session, both follow the same shape:
//   startGame()            <- normal play: RequestModel gets a fresh batch from
//                              the server (getWords: word bank first, GPT for the
//                              rest), checkpointMode defaults to
//                              .everyN(10), fetchMore is wired so WordVM can
//                              ask for more words indefinitely
//   startReview()          <- "My words" review: every saved word of the job,
//                              weakest first, straight from SwiftData (words and
//                              pictures are on the phone — no server call), in
//                              rounds of 10, fetchMore is nil (the list is fixed)
//
// Both entry points end the same way: build a WordVM, store it (weak) in
// activeVM, set phase = .playing(vm). From there, WordVM drives everything
// via its two injected callbacks:
//   onCheckpoint -> phase = .result(vm)                  (show ResultView)
//   onResume     -> phase = .playing(vm) or .generating   (resume, or show a
//                    brief loading state if the next batch isn't ready yet)
//
// Access: the first 10 words are free (FreeAllowance, once for the whole app). After that the current job has to be
// unlocked (Purchases, $9.99 once per job): hasAccess. "My words" (openWordList / startReview) needs hasAccess too.
// Every answered game word -> FreeAllowance.recordAnsweredWord() + DailyReminder.cancelToday();
// canPlay / canContinue / canFetchMore stop free users at the limit.
// Failures -> showFailure() -> OfflineView or ErrorView; retry() starts the last session kind again.

@Observable
final class AppManager {
  private enum SessionKind { case game, review }                   // which kind of session retry() should start again
  private var lastSession: SessionKind = .game                     // set by startGame / startReview
  private var isStarting = false                                   // true while startGame() runs — blocks a second load (auto-retry + tap)
  var phase: GamePhase = .onboarding                               // drives what RootView renders — the single UI state machine for the app
  let requestModel: RequestModel                                   // shared generation/data layer, same instance across the whole app lifetime
  let cabinet: CabinetVM                                           // WelcomeBackView's cards (profession + language) and their taps
  private weak var activeVM: WordVM?                                // weak on purpose — `phase`'s associated value is the real owner, this is just a way for callbacks to reach it
  var nativeLanguage: Languages { requestModel.nativeLanguage }    // the user's own language — the whole UI is shown in it
  var locale: Locale { nativeLanguage.locale }                     // RootView puts it in the environment
  var layoutDirection: LayoutDirection {                           // right-to-left for Arabic, Hebrew, Farsi…
    nativeLanguage.isRtL ? .rightToLeft : .leftToRight
  }
  var currentJob: Occupation? { Occupation.listed(requestModel.proffession) }   // the picked menu job (nil: none, or an old typed one)
  var hasAccess: Bool { currentJob.map(Purchases.shared.isUnlocked) ?? false }  // the current job is unlocked
  var canPlay: Bool { hasAccess || !FreeAllowance.shared.isLimitReached }   // unlocked, or free words left
  var isReviewSession: Bool { lastSession == .review }             // the running/last session is a "My words" review
  
  // MARK: - init
  // Keeps the shared RequestModel (created once in LearnScrumbleApp). phase starts at .onboarding;
  // RootView switches it to .welcomeBack at launch for a returning user.
  init(requestModel: RequestModel) {
    self.requestModel = requestModel
    self.cabinet = CabinetVM(requestModel: requestModel)
    Log.info("🟢 AppManager.init", .app)
  }
  
  // MARK: - startGame
  // Normal play — builds a fresh, ever-growing word session from the server (word bank + GPT).
  // 1. Already loading? ignore the call (an auto-retry and a tap can't start two loads). Marks the session kind as .game.
  // 2. Progress to 0 and phase = .generating -> LoadingView while the first batch is built.
  // 3. Can't play (free words used, job not unlocked) -> back to WelcomeBackView — a safety net, the buttons should already prevent this.
  // 4. requestModel.generate(): SwiftData exclusion (seen words) -> getWords (bank first, GPT for the rest)
  //    -> pictures (stored, or new from getPicture) -> requestModel.questions.
  //    Nothing usable came back -> showFailure() picks OfflineView or ErrorView, depending on the cause.
  // 5. Builds the WordVM for this session and wires its callbacks:
  //    - questions: the freshly generated batch
  //    - targetLanguage: locks this session's SwiftData scoping to the current target language
  //    - profession / originLanguage: saved with every new word for "My words"
  //    - fetchMore: how WordVM asks for more words once it's running low -> requestModel.generateMore
  //      (no checkpointMode passed, so it defaults to .everyN(10))
  //    - onCheckpoint: fired by WordVM every 10th word -> phase = .result(vm) (ResultView).
  //      activeVM being nil here would mean the session was already torn down — bail safely
  //    - onResume: fired by WordVM when leaving a checkpoint.
  //      Free words used up -> don't go back to the answered word, exit to welcome.
  //      Next batch not ready yet (pendingAdvance) -> reset a finished progress bar to 0 and show LoadingView briefly;
  //      otherwise straight back to play
  //    - onFetchFailed: fetching more words failed mid-session -> drop the session and show the failure screen
  //    - onWordAnswered: every answered word counts -> FreeAllowance +1, and DailyReminder.cancelToday()
  //      (played today: delete today's booked 9am reminder, see DailyReminder.swift)
  //    - canContinue: checked after every word -> unlocked, or free words left
  //    - canFetchMore: no downloads the user can't play -> unlocked, or used + still unplayed words stay under the free limit
  //    - onReportPicture: the flag on the picture -> reportPicture (also in the review)
  // 6. Keeps a weak reference (activeVM) so the callbacks above can reach this vm later,
  //    then phase = .playing(vm) hands control to MainView.
  @MainActor
  func startGame() async {
    guard !isStarting else { Log.debug("🎮 startGame — already loading, ignoring", .app); return }
    isStarting = true
    defer { isStarting = false }
    lastSession = .game
    Log.info("🎮 startGame — starting", .app)
      requestModel.progress = 0
    phase = .generating
    guard canPlay else {
      phase = .welcomeBack
      return
    }
    await requestModel.generate()
    
    if requestModel.questions.isEmpty {
      Log.error("❌ startGame — no questions: \(requestModel.errorMessage ?? "unknown error")", .app)
      await showFailure()
      return
    }
    
    Log.info("🎮 startGame — got \(requestModel.questions.count) questions, building WordVM", .app)
    let vm = WordVM(
      questions: requestModel.questions,
      targetLanguage: requestModel.selectedLanguage.rawValue,
      profession: currentJob?.rawValue ?? requestModel.proffession,
      originLanguage: requestModel.nativeLanguage.rawValue,
      fetchMore: { [requestModel] exclude in
        await requestModel.generateMore(excluding: exclude)
      },
      onCheckpoint: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        Log.info("🏁 startGame.onCheckpoint — showing ResultView", .app)
        Track.roundCompleted(mode: .game)
        if !self.canPlay { Track.freeLimitReached() }              // the round ended because the free words are used up
        self.phase = .result(vm)
      },
      onResume: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        guard self.canPlay else {
          Log.info("⛔️ startGame.onResume — free words used up, back to welcome", .app)
          self.exitToWelcome()
          return
        }
        Log.info("▶️ startGame.onResume — pendingAdvance=\(vm.pendingAdvance), routing to \(vm.pendingAdvance ? ".generating" : ".playing")", .app)
          if vm.pendingAdvance && self.requestModel.progress >= 1 { self.requestModel.progress = 0}
        self.phase = vm.pendingAdvance ? .generating : .playing(vm)
      },
      onFetchFailed: { [weak self] in
          guard let self, self.activeVM != nil else { return }
          Log.error("❌ startGame.onFetchFailed — showing ErrorView", .app)
          self.activeVM = nil
          Task { @MainActor in
            await self.showFailure()
          }
      },
      onWordAnswered: {
        FreeAllowance.shared.recordAnsweredWord()
        DailyReminder.cancelToday()
      },
      canContinue: { [weak self] in self?.canPlay ?? false },
      canFetchMore: { [weak self] unplayed in
        guard let self else { return false }
        return self.hasAccess || FreeAllowance.shared.wordsUsed + unplayed < FreeAllowance.freeWordLimit
      },
      onReportPicture: reportPicture
    )
    activeVM = vm
    phase = .playing(vm)
  }
  
  // MARK: - openWordList
  // "My words" (WelcomeBackView, ResultView): the job's saved words with their right / wrong counts.
  // Only for an unlocked job — the buttons show the paywall otherwise. Drops a running session.
  func openWordList() {
    guard hasAccess else { return }
    activeVM = nil
    phase = .wordList
  }

  // MARK: - startReview
  // "Repeat all" on MyWordsView — replays the job's saved words, no server call.
  // 1. The job's words in this language from SwiftData, weakest first (PersistenceController.jobWords), only those
  //    with a picture. Nothing to review -> stays on the word list.
  // 2. Builds the WordVM:
  //    - questions: those words, built from what's stored on the phone (SwiftDataWordModel.asQuestion)
  //    - checkpointMode .everyN(10): a ResultView after every 10 words; fetchMore nil: after the last word the
  //      session is finished (isFinished) and the last ResultView offers new words or "My words"
  //    - onCheckpoint -> ResultView; onResume -> back to playing, or to the list once the review is finished
  //    Review answers update the counters and the streak and cancel today's reminder, but don't use free words.
  // 3. activeVM = vm, phase = .playing(vm).
  @MainActor
  func startReview() {
    guard hasAccess, let job = currentJob else { return }
    lastSession = .review
    let lang = requestModel.selectedLanguage.rawValue
    let questions = PersistenceController.shared.jobWords(profession: job.rawValue, targetLanguage: lang)
      .filter(\.hasPicture)
      .map(\.asQuestion)
    guard !questions.isEmpty else {
      Log.info("🎯 startReview — no saved words for this job yet", .app)
      phase = .wordList
      return
    }
    Log.info("🎯 startReview — reviewing \(questions.count) saved words", .app)
    Track.reviewStarted(words: questions.count)
    let vm = WordVM(
      questions: questions,
      targetLanguage: lang,
      profession: job.rawValue,
      originLanguage: requestModel.nativeLanguage.rawValue,
      fetchMore: nil,
      onCheckpoint: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        Log.info("🏁 startReview.onCheckpoint — showing ResultView", .app)
        Track.roundCompleted(mode: .review)
        self.phase = .result(vm)
      },
      onResume: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        Log.info("▶️ startReview.onResume — isFinished=\(vm.isFinished)", .app)
        if vm.isFinished { self.openWordList() } else { self.phase = .playing(vm) }
      },
      onWordAnswered: { DailyReminder.cancelToday() },
      onReportPicture: reportPicture
    )
    activeVM = vm
    phase = .playing(vm)
  }
  
  // MARK: - reportPicture(_:)
  // The flag on a picture (WordVM.reportPicture): sends the report with the picture the user saw.
  private func reportPicture(_ question: QuestionModel) async -> RequestModel.ReportResult {
    Track.pictureReported()
    return await requestModel.reportPicture(toolName: question.word.toolName, imageURL: question.imageURL)
  }

  // MARK: - reportSavedPicture(_:)
  // The flag on My words' card (WordCardOverlay): the same report as in the game, for a word saved on the phone.
  func reportSavedPicture(_ word: SwiftDataWordModel) async -> RequestModel.ReportResult {
    Track.pictureReported()
    return await requestModel.reportPicture(toolName: word.concept, imageURL: word.imageURL)
  }

  // MARK: - showFailure(fallback:)
  // Single place that decides which failure screen to show.
  // Offline wins if RequestModel saw it, OR if the phone has no connection right now —
  // some failures (Firebase reads, every image download failing) hide the offline reason.
  // error = RequestModel.lastError, or `fallback` (lastError is nil only when the load was cancelled mid-way).
  //   .offline -> OfflineView; phone offline right now (Connectivity.isOnline) -> OfflineView;
  //   otherwise ErrorView with that error. .serviceUnavailable means our side is broken (key, billing, request) —
  //   a loud log until server-side alerts exist.
  @MainActor
  private func showFailure(fallback: GenerationError = .unknown) async {
    let error = requestModel.lastError ?? fallback
    if error == .offline {
      phase = .offline
    } else if !(await Connectivity.isOnline()) {
      Log.info("📵 showFailure — '\(error)' but the phone is offline, showing OfflineView", .app)
      phase = .offline
    } else {
      if error == .serviceUnavailable {
        Log.error("🚨 showFailure — SERVICE UNAVAILABLE: every user is blocked until the key/billing/request is fixed", .app)
      }
      phase = .failed(error)
    }
  }
  
  // MARK: - exitToWelcome
  // Called when the user leaves a session (result, error or offline screen).
  // Drops activeVM — the last strong-ish reference; the vm deallocates once phase changes — then shows WelcomeBackView.
  // Also the game's back arrow (ButtonsTopRow): every answer is already saved.
  func exitToWelcome() {
    Log.info("🚪 exitToWelcome — dropping activeVM, returning to Welcome Screen", .app)
    activeVM = nil
    phase = .welcomeBack
  }
  
  // MARK: - openSettings
  // Gear on WelcomeBackView or ErrorView's "Change profession".
  // A running round ends — every answer is already saved — and SettingsView opens.
  func openSettings() {
    activeVM = nil
    phase = .settings
  }
  
  // MARK: - closeSettings
  // "Done" in Settings -> back to WelcomeBackView.
  func closeSettings() {
    phase = .welcomeBack
  }
  
//  @MainActor
//  func deleteAllData() {                                            // "Delete my data": back to a first-launch state
//    PersistenceController.shared.deleteAllProgress()
//    for key in ["nativeLanguage", "pickedLanguage", "pickedProffession",
//                "hasCompletedOnboarding", "speechRate"] {
//      UserDefaults.standard.removeObject(forKey: key)              // @AppStorage values fall back to their defaults
//    }
//    requestModel.proffession = ""
//    activeVM = nil
//    phase = .onboarding
//  }
  
  // MARK: - retry
  // ErrorView / OfflineView "Retry" or OfflineView's automatic retry: starts the same kind of session again.
  @MainActor
  func retry() async {
    switch lastSession {
    case .game:
      await startGame()
    case .review:
      startReview()
    }
  }
}
