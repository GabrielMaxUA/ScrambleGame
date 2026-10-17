// AppManager.swift
import SwiftUI

// MARK: - Flow of this file
// AppManager is the single source of truth for what's on screen (phase) and
// owns the one active WordVM for the current session. RootView just switches
// on `phase` and renders accordingly — all the actual decisions happen here.
//
// Two entry points build a session, both follow the same shape:
//   startGame()            <- normal play: RequestModel generates a fresh
//                              GPT word list, checkpointMode defaults to
//                              .everyN(10), fetchMore is wired so WordVM can
//                              ask for more words indefinitely
//   startStruggleReview()  <- review mode: pulls a FIXED list of struggling
//                              toolNames from SwiftData, resolves them via
//                              Firebase (no GPT word-list call), checkpointMode
//                              is .endOfSession (one checkpoint, at the very end),
//                              fetchMore is nil (no more content ever comes)
//
// Both entry points end the same way: build a WordVM, store it (weak) in
// activeVM, set phase = .playing(vm). From there, WordVM drives everything
// via its two injected callbacks:
//   onCheckpoint -> phase = .result(vm)                  (show ResultView)
//   onResume     -> phase = .playing(vm) or .generating   (resume, or show a
//                    brief loading state if the next batch isn't ready yet)
//
// Free allowance: every answered word -> FreeAllowance.recordAnsweredWord() + DailyReminder.cancelToday();
// canPlay / canContinue / canFetchMore stop free users at the daily limit.
// Failures -> showFailure() -> OfflineView or ErrorView; retry() starts the last session kind again.

@Observable
final class AppManager {
  private enum SessionKind { case game, review }                   // which kind of session retry() should start again
  private var lastSession: SessionKind = .game                     // set by startGame / startStruggleReview
  private var isStarting = false                                   // true while startGame()/startStruggleReview() runs — blocks a second load (auto-retry + tap)
  var phase: GamePhase = .onboarding                               // drives what RootView renders — the single UI state machine for the app
  let requestModel: RequestModel                                   // shared generation/data layer, same instance across the whole app lifetime
  private weak var activeVM: WordVM?                                // weak on purpose — `phase`'s associated value is the real owner, this is just a way for callbacks to reach it
  var nativeLanguage: Languages { requestModel.nativeLanguage }    // the user's own language — the whole UI is shown in it
  var locale: Locale { nativeLanguage.locale }                     // RootView puts it in the environment
  var layoutDirection: LayoutDirection {                           // right-to-left for Arabic, Hebrew, Farsi…
    nativeLanguage.isRtL ? .rightToLeft : .leftToRight
  }
  var hasAccess = false   // paid or unlocked. For now always false; RevenueCat will set it later
  var canPlay: Bool { hasAccess || !FreeAllowance.shared.isLimitReached }   // paid, or free words left today
  
  // MARK: - init
  // Keeps the shared RequestModel (created once in LearnScrumbleApp). phase starts at .onboarding;
  // RootView switches it to .welcomeBack at launch for a returning user.
  init(requestModel: RequestModel) {
    self.requestModel = requestModel
    Log.info("🟢 AppManager.init", .app)
  }
  
  // MARK: - startGame
  // Normal play — builds a fresh, ever-growing word session via GPT.
  // 1. Already loading? ignore the call (an auto-retry and a tap can't start two loads). Marks the session kind as .game.
  // 2. Progress to 0 and phase = .generating -> LoadingView while the first batch is built.
  // 3. FreeAllowance.syncClock(): internet time before checking the allowance.
  //    Can't play (free limit reached) -> back to WelcomeBackView — a safety net, the buttons should already prevent this.
  // 4. requestModel.generate(): SwiftData exclusion (seen words) + GPT word list + Firebase/GPT images -> requestModel.questions.
  //    Nothing usable came back -> showFailure() picks OfflineView or ErrorView, depending on the cause.
  // 5. Builds the WordVM for this session and wires its callbacks:
  //    - questions: the freshly generated batch
  //    - targetLanguage: locks this session's SwiftData scoping to the current target language
  //    - fetchMore: how WordVM asks for more words once it's running low -> requestModel.generateMore
  //      (no checkpointMode passed, so it defaults to .everyN(10))
  //    - onCheckpoint: fired by WordVM every 10th word -> phase = .result(vm) (ResultView).
  //      activeVM being nil here would mean the session was already torn down — bail safely
  //    - onResume: fired by WordVM when leaving a checkpoint.
  //      Limit reached (NEW) -> don't go back to the answered word, exit to welcome.
  //      Next batch not ready yet (pendingAdvance) -> reset a finished progress bar to 0 and show LoadingView briefly;
  //      otherwise straight back to play
  //    - onFetchFailed: fetching more words failed mid-session -> drop the session and show the failure screen
  //    - onWordAnswered: every answered word counts -> FreeAllowance +1, and DailyReminder.cancelToday()
  //      (played today: delete today's booked 9am reminder, see DailyReminder.swift)
  //    - canContinue: checked after every word -> paid, or free words left
  //    - canFetchMore: no downloads the user can't play -> paid, or used + still unplayed words stay under the daily limit
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
    await FreeAllowance.shared.syncClock()
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
      fetchMore: { [requestModel] exclude in
        await requestModel.generateMore(excluding: exclude)
      },
      onCheckpoint: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        Log.info("🏁 startGame.onCheckpoint — showing ResultView", .app)
        Track.roundCompleted(mode: .game)
        if !self.canPlay { Track.dailyLimitReached() }             // the round ended because today's free words are used up
        self.phase = .result(vm)
      },
      onResume: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        guard self.canPlay else {
          Log.info("⛔️ startGame.onResume — daily free limit reached, back to welcome", .app)
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
        return self.hasAccess || FreeAllowance.shared.wordsUsedToday + unplayed < FreeAllowance.dailyWordLimit
      }
    )
    activeVM = vm
    phase = .playing(vm)
  }
  
  // MARK: - startStruggleReview
  // Review mode — fixed pool of previously-struggled words, no new generation.
  // 1. Already loading? ignore. Marks the session kind as .review, phase = .generating (LoadingView).
  // 2. Pulls the current struggle list for this language from SwiftData — the weakest 10.
  //    Nothing to review right now -> ErrorView with .noStruggleWords.
  // 3. requestModel.generateStruggleReview(): resolves these known toolNames via Firebase (no GPT word-list call).
  //    Nothing came back -> showFailure(), falling back to .reviewUnavailable.
  // 4. Builds the WordVM:
  //    - questions: the fixed set of words to review this session
  //    - checkpointMode .endOfSession: one checkpoint only, after the last word — no interim pauses
  //    - fetchMore nil: fixed pool — this is a finite review set, not infinite generation
  //    - onCheckpoint: fired once, when the last review word is answered -> ResultView
  //    - onResume: fired if continueFromCheckpoint() is somehow called (isFinished guards against advancing further)
  //    Review answers don't count against the free allowance (no onWordAnswered).
  // 5. activeVM = vm, phase = .playing(vm).
  @MainActor
  func startStruggleReview() async {
    guard !isStarting else { Log.debug("🎯 startStruggleReview — already loading, ignoring", .app); return }
    isStarting = true
    defer { isStarting = false }
    Log.info("🎯 startStruggleReview — starting", .app)
    lastSession = .review
    phase = .generating
      let toolNames = PersistenceController.shared.struggleToolNames(targetLanguage: requestModel.selectedLanguage.rawValue, limit: 10)
    
    guard !toolNames.isEmpty else {
      Log.info("🎯 startStruggleReview — no struggle words found", .app)
      phase = .failed(.noStruggleWords)
      return
    }
    
    Log.info("🎯 startStruggleReview — reviewing \(toolNames.count) struggle words", .app, private: "\(toolNames)")
    let reviewQuestions = await requestModel.generateStruggleReview(toolNames: toolNames)
      guard !reviewQuestions.isEmpty else {
        Log.error("🎯 startStruggleReview — resolution produced 0 questions", .app)
        await showFailure(fallback: .reviewUnavailable)
        return
      }
    
    Log.info("🎯 startStruggleReview — built \(reviewQuestions.count) reviewable questions, building WordVM", .app)
    Track.reviewStarted(words: reviewQuestions.count)
    let vm = WordVM(
      questions: reviewQuestions,
      targetLanguage: requestModel.selectedLanguage.rawValue,
      checkpointMode: .endOfSession,
      fetchMore: nil,
      onCheckpoint: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        Log.info("🏁 startStruggleReview.onCheckpoint — review complete, showing ResultView", .app)
        Track.roundCompleted(mode: .review)
        self.phase = .result(vm)
      },
      onResume: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        Log.info("▶️ startStruggleReview.onResume — isLoadingMore=\(vm.isLoadingMore)", .app)
        self.phase = vm.isLoadingMore ? .generating : .playing(vm)
      }
    )
    activeVM = vm
    phase = .playing(vm)
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
  func exitToWelcome() {
    Log.info("🚪 exitToWelcome — dropping activeVM, returning to Welcome Screen", .app)
    activeVM = nil
    phase = .welcomeBack
  }
  
  // MARK: - openSettings
  // Gear (in game or on WelcomeBackView) or ErrorView's "Change profession".
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
      await startStruggleReview()
    }
  }
}
