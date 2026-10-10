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

@Observable
final class AppManager {
  private enum SessionKind { case game, review }
  private var lastSession: SessionKind = .game
  private var isStarting = false                                   // true while startGame()/startStruggleReview() runs — blocks a second load (auto-retry + tap)
  var phase: GamePhase = .onboarding                               // drives what RootView renders — the single UI state machine for the app
  let requestModel: RequestModel                                   // shared generation/data layer, same instance across the whole app lifetime
  private weak var activeVM: WordVM?                                // weak on purpose — `phase`'s associated value is the real owner, this is just a way for callbacks to reach it
  var nativeLanguage: Languages { requestModel.nativeLanguage }
  var locale: Locale { nativeLanguage.locale }
  var layoutDirection: LayoutDirection {
    nativeLanguage.isRtL ? .rightToLeft : .leftToRight
  }
  var hasAccess = false   // paid or unlocked. For now always false; RevenueCat will set it later
  var canPlay: Bool { hasAccess || !FreeAllowance.shared.isLimitReached }   // paid, or free words left today
  
  init(requestModel: RequestModel) {
    self.requestModel = requestModel
    print("🟢 AppManager.init") // NEW
  }
  
  @MainActor
  func startGame() async {                                          // normal play — builds a fresh, ever-growing word session via GPT
    guard !isStarting else { print("🎮 startGame — already loading, ignoring"); return }
    isStarting = true
    defer { isStarting = false }
    lastSession = .game
    print("🎮 startGame — starting") // NEW
      requestModel.progress = 0
    phase = .generating                                             // show LoadingView while the first batch is built
    await FreeAllowance.shared.syncClock()                  // internet time before checking the allowance
    guard canPlay else {                                    // safety net: the buttons should already prevent this
      phase = .welcomeBack
      return
    }
    await requestModel.generate()                                   // RequestModel handles SwiftData-exclusion + GPT + Firebase, populates requestModel.questions
    
    if requestModel.questions.isEmpty {                              // generate() failed or returned nothing usable
      print("Error: \(requestModel.errorMessage ?? "Unknown error")")
      await showFailure()                                             // OfflineView or ErrorView, depending on the cause
      return
    }
    
    print("🎮 startGame — got \(requestModel.questions.count) questions, building WordVM") // NEW
    let vm = WordVM(
      questions: requestModel.questions,                             // hand off the freshly generated batch
      targetLanguage: requestModel.selectedLanguage.rawValue,        // lock this session's SwiftData scoping to the current target language
      fetchMore: { [requestModel] exclude in                         // how WordVM asks for more words once it's running low — no checkpointMode passed, so it defaults to .everyN(10)
        await requestModel.generateMore(excluding: exclude)
      },
      onCheckpoint: { [weak self] in                                 // fired by WordVM every 10th word
        guard let self, let vm = self.activeVM else { return }        // activeVM being nil here would mean the session was already torn down — bail safely
        print("🏁 startGame.onCheckpoint — showing ResultView") // NEW
        self.phase = .result(vm)
      },
      onResume: { [weak self] in                                     // fired by WordVM when leaving a checkpoint
        guard let self, let vm = self.activeVM else { return }
        guard self.canPlay else {                                    // NEW — limit reached: don't go back to the answered word
          print("⛔️ startGame.onResume — daily free limit reached, back to welcome")
          self.exitToWelcome()
          return
        }
        print("▶️ startGame.onResume — pendingAdvance=\(vm.pendingAdvance), routing to \(vm.pendingAdvance ? ".generating" : ".playing")")
          if vm.pendingAdvance && self.requestModel.progress >= 1 { self.requestModel.progress = 0}
        self.phase = vm.pendingAdvance ? .generating : .playing(vm)    // if the next batch isn't ready yet, show LoadingView briefly; otherwise go straight back to play
      },
      onFetchFailed: { [weak self] in
          guard let self, self.activeVM != nil else { return }
          print("❌ startGame.onFetchFailed — showing ErrorView")
          self.activeVM = nil
          Task { @MainActor in
            await self.showFailure()
          }
      },
      onWordAnswered: { FreeAllowance.shared.recordAnsweredWord() },             // every answered word counts
      canContinue: { [weak self] in self?.canPlay ?? false },                     // checked after every word
      canFetchMore: { [weak self] unplayed in                                     // no downloads the user can't play
        guard let self else { return false }
        return self.hasAccess || FreeAllowance.shared.wordsUsedToday + unplayed < FreeAllowance.dailyWordLimit
      }
    )
    activeVM = vm                                                     // keep a weak reference so the callbacks above can reach this vm later
    phase = .playing(vm)                                              // hand control to MainView
  }
  
  @MainActor
  func startStruggleReview() async {                                 // review mode — fixed pool of previously-struggled words, no new generation
    guard !isStarting else { print("🎯 startStruggleReview — already loading, ignoring"); return }
    isStarting = true
    defer { isStarting = false }
    print("🎯 startStruggleReview — starting") // NEW
    lastSession = .review
    phase = .generating                                              // show LoadingView while the review set is resolved
      let toolNames = PersistenceController.shared.struggleToolNames(targetLanguage: requestModel.selectedLanguage.rawValue, limit: 10) // pull the current struggle list for this language
    
    guard !toolNames.isEmpty else {                                   // nothing to review right now
      print("🎯 startStruggleReview — no struggle words found") // NEW
      phase = .failed(.noStruggleWords)
      return
    }
    
    print("🎯 startStruggleReview — reviewing \(toolNames.count) struggle words: \(toolNames)") // NEW
    let reviewQuestions = await requestModel.generateStruggleReview(toolNames: toolNames) // resolve these known toolNames via Firebase (no GPT word-list call)
      guard !reviewQuestions.isEmpty else {
        print("🎯 startStruggleReview — resolution produced 0 questions")
        await showFailure(fallback: .reviewUnavailable)
        return
      }
    
    print("🎯 startStruggleReview — built \(reviewQuestions.count) reviewable questions, building WordVM") // NEW
    let vm = WordVM(
      questions: reviewQuestions,                                     // the fixed set of words to review this session
      targetLanguage: requestModel.selectedLanguage.rawValue,
      checkpointMode: .endOfSession,                                  // one checkpoint only, after the last word — no interim pauses
      fetchMore: nil, // fixed pool — this is a finite review set, not infinite generation
      onCheckpoint: { [weak self] in                                  // fired once, when the last review word is answered
        guard let self, let vm = self.activeVM else { return }
        print("🏁 startStruggleReview.onCheckpoint — review complete, showing ResultView") // NEW
        self.phase = .result(vm)
      },
      onResume: { [weak self] in                                      // fired if continueFromCheckpoint() is somehow called (isFinished guards against advancing further)
        guard let self, let vm = self.activeVM else { return }
        print("▶️ startStruggleReview.onResume — isLoadingMore=\(vm.isLoadingMore)") // NEW
        self.phase = vm.isLoadingMore ? .generating : .playing(vm)
      }
    )
    activeVM = vm
    phase = .playing(vm)
  }
  
  /// Single place that decides which failure screen to show.
  /// Offline wins if RequestModel saw it, OR if the phone has no connection right now —
  /// some failures (Firebase reads, every image download failing) hide the offline reason.
  @MainActor
  private func showFailure(fallback: GenerationError = .unknown) async {
    let error = requestModel.lastError ?? fallback                     // nil only when the load was cancelled mid-way
    if error == .offline {
      phase = .offline
    } else if !(await Connectivity.isOnline()) {
      print("📵 showFailure — '\(error)' but the phone is offline, showing OfflineView")
      phase = .offline
    } else {
      if error == .serviceUnavailable {                                // our side is broken (key, billing, request) — loud log until server-side alerts exist
        print("🚨 showFailure — SERVICE UNAVAILABLE: every user is blocked until the key/billing/request is fixed")
      }
      phase = .failed(error)
    }
  }
  
  func exitToWelcome() {                                             // called when the user leaves a session (result or error screen)
    print("🚪 exitToWelcome — dropping activeVM, returning to Welcome Screen")
    activeVM = nil                                                     // last strong-ish reference removed here; vm deallocates once phase changes below
    phase = .welcomeBack
  }
  
  func openSettings() {                                             // gear or welcome-back Settings button
    activeVM = nil                                                  // a running round ends; every answer is already saved
    phase = .settings
  }
  
  func closeSettings() {                                            // Done in Settings
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
