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
// exitToSettings() drops activeVM and returns to .onboarding — since activeVM
// is `weak`, the WordVM deallocates once `phase` stops referencing it too.

@Observable
final class AppManager {
  var phase: GamePhase = .onboarding                               // drives what RootView renders — the single UI state machine for the app
  let requestModel: RequestModel                                   // shared generation/data layer, same instance across the whole app lifetime
  private weak var activeVM: WordVM?                                // weak on purpose — `phase`'s associated value is the real owner, this is just a way for callbacks to reach it
  
  init(requestModel: RequestModel) {
    self.requestModel = requestModel
    print("🟢 AppManager.init") // NEW
  }
  
  @MainActor
  func startGame() async {                                          // normal play — builds a fresh, ever-growing word session via GPT
    print("🎮 startGame — starting") // NEW
    phase = .generating                                             // show LoadingView while the first batch is built
    await requestModel.generate()                                   // RequestModel handles SwiftData-exclusion + GPT + Firebase, populates requestModel.questions
    
    if requestModel.questions.isEmpty {                              // generate() failed or returned nothing usable
      phase = .failed(requestModel.errorMessage ?? "Something went wrong") // show ErrorView with whatever message RequestModel set
      print("Error: \(requestModel.errorMessage ?? "Unknown error")")
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
        print("▶️ startGame.onResume — isLoadingMore=\(vm.isLoadingMore), routing to \(vm.isLoadingMore ? ".generating" : ".playing")") // NEW
        self.phase = vm.isLoadingMore ? .generating : .playing(vm)    // if the next batch isn't ready yet, show LoadingView briefly; otherwise go straight back to play
      }
    )
    activeVM = vm                                                     // keep a weak reference so the callbacks above can reach this vm later
    phase = .playing(vm)                                              // hand control to MainView
  }
  
  @MainActor
  func startStruggleReview() async {                                 // review mode — fixed pool of previously-struggled words, no new generation
    print("🎯 startStruggleReview — starting") // NEW
    phase = .generating                                              // show LoadingView while the review set is resolved
    let toolNames = PersistenceController.shared.struggleToolNames(targetLanguage: requestModel.selectedLanguage.rawValue) // pull the current struggle list for this language
    
    guard !toolNames.isEmpty else {                                   // nothing to review right now
      print("🎯 startStruggleReview — no struggle words found") // NEW
      phase = .failed("No struggle words yet — keep practicing!")
      return
    }
    
    print("🎯 startStruggleReview — reviewing \(toolNames.count) struggle words: \(toolNames)") // NEW
    let reviewQuestions = await requestModel.generateStruggleReview(toolNames: toolNames) // resolve these known toolNames via Firebase (no GPT word-list call)
    guard !reviewQuestions.isEmpty else {                              // resolution failed entirely (e.g. Firebase docs missing the current target translation)
      print("🎯 startStruggleReview — resolution produced 0 questions") // NEW
      phase = .failed("Couldn't load your struggle words. Try again.")
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
  
  func exitToSettings() {                                             // called when the user backs out to onboarding mid-session
    print("🚪 exitToSettings — dropping activeVM, returning to onboarding") // NEW
    activeVM = nil                                                     // last strong-ish reference removed here; vm deallocates once phase changes below
    phase = .onboarding
  }
}
