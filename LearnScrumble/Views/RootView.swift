
import SwiftUI
import SwiftData

// MARK: - Flow of this file
// The app's one root screen: switches on AppManager.phase and shows the matching view.
//   LearnScrumbleApp -> RootView(manager:)
//   phase -> EntryView / WelcomeBackView / LoadingView / MainView / ErrorView / OfflineView / ResultView / SettingsView
//   Each view's buttons call back into AppManager (startGame, startStruggleReview, retry, exitToWelcome, openSettings…),
//   which changes phase -> RootView redraws with the new screen.
//   On top: LaunchScreen for the first 5s, and the top button row (ButtonsTopRow) on onboarding / playing.
//   "How to play" tutorial (OnboardingView) over everything while showTutorial is true:
//     after the setup screen's Start (the first words load behind it), at launch for anyone who finished setup
//     but never saw it, and from Settings' "How to play".
//     Closing it ("Let's go!" or Skip) over the welcome screen starts the game; after Start the game is already
//     loading behind it; from Settings it returns to Settings.
//   Applies the user's native language (locale + left/right direction) to every screen below it.

struct RootView: View {
    let manager: AppManager                                           // owns phase and starts every session
    @State private var showMenu = false                               // not used right now
    @State private var speechManager = SpeechManager()                // one speech engine shared by the top row
    @State private var launching: Bool = true                         // LaunchScreen visible
    @AppStorage("pickedLanguage") private var pickedLanguage = "en-US"   // target language code, saved by EntryView/Settings
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false   // true after the first "Let's go"
    @AppStorage(OnboardingService.seenKey) private var hasSeenTutorial = false        // true once "How to play" was finished or skipped
    @State private var showTutorial = false                           // the "How to play" tutorial is on screen
    @Query(filter: #Predicate<SwiftDataWordModel> { $0.incorrect > 0 })
    private var missed: [SwiftDataWordModel]                          // every word missed at least once (any language), kept live by SwiftData
    var direction: Bool {                                             // true = native language reads left-to-right
      manager.layoutDirection == .leftToRight ? true : false
    }
    private var hasStruggle: Bool {                                   // any struggle word in the current target language -> show the review button
        missed.contains { $0.targetLanguage == pickedLanguage && $0.isStruggle }
    }

    var body: some View {
        ZStack(alignment: .top) {
          Group {                                                // the current screen
            switch manager.phase {
            case .onboarding:                                    // first launch: languages + profession
              EntryView(requestModel: manager.requestModel, onSubmit: {
                hasCompletedOnboarding = true                    // setup done: next launch shows the welcome-back screen
                // MARK: - Daily reminder permission
                // "Let's go" -> DailyReminder.requestPermission() -> iOS Allow / Don't Allow popup (iOS shows it once ever)
                //   Allow -> DailyReminder.reschedule() books the 9am reminders for the next 7 days
                // Separate Task so startGame() below starts loading words while the popup is on screen
                Task { await DailyReminder.requestPermission() }
                if !hasSeenTutorial { showTutorial = true }        // tutorial while the first words load behind it
                await manager.startGame()
              })
            case .welcomeBack:                                   // NEW — returning user's start screen
              WelcomeBackView(
                targetLanguage: manager.requestModel.selectedLanguage.rawValue,
                hasAccess: manager.hasAccess,
                canPlay: manager.canPlay,
                onContinue: { Task { await manager.startGame() } },
                onReview: { Task { await manager.startStruggleReview() } },
                onShowPaywall: { print("💳 paywall — not built yet") },
                onSettings: { manager.openSettings() })
            case .generating:                                    // words/images loading
                LoadingView(progress: manager.requestModel.progress)
            case .playing(let vm):                               // the game
                MainView(vm: vm, manager: manager)
            case .failed(let error):                             // something broke — ErrorView picks the useful button
              ErrorView(
                error: error,
                direction: direction,
                onRetry: { await manager.retry() },
                onExit: { manager.exitToWelcome()},
                onChangeProfession: { manager.openSettings() })
            case .offline:                                       // no internet — retries by itself when back online
              OfflineView(
                direction: direction,
                onRetry: { await manager.retry() },
                onExit: { manager.exitToWelcome() })
            case .result(let vm):                                // checkpoint summary after a round
                ResultView(
                    vm: vm,
                    hasAccess: manager.hasAccess,// NEW
                    canPlay: manager.canPlay,
                    onContinue: {
                        if vm.isFinished {
                            Task { await manager.startGame() }   // struggle review just finished — start a fresh normal session
                        } else {
                            vm.continueFromCheckpoint()          // normal checkpoint — resume this same session
                        }
                    },
                    onRetry: { Task { await manager.startStruggleReview() }},
                    onShowPaywall: { print("💳 paywall — not built yet") },   // NEW
                    exitToWelcome: { manager.exitToWelcome() })
            case .settings:
              SettingsView(
                requestModel: manager.requestModel,
                hasAccess: manager.hasAccess,
                onShowPaywall: { print("💳 paywall — not built yet") },
                onDone: { manager.closeSettings() },
                onHowToPlay: { showTutorial = true }             // replay the tutorial over Settings
              )
            }
          }
          .accessibilityHidden(showTutorial)                     // VoiceOver reads only the tutorial while it's on top
          if launching {                                         // intro over everything for the first 5s
            LaunchScreen()
              .transition(.opacity)
              .zIndex(10)
          }
          topRow                                                 // top buttons, only on some phases
          if showTutorial {                                      // "How to play", over the game and its buttons
            OnboardingView(manager: manager) {                   // "Let's go!" or Skip
              withAnimation { showTutorial = false }
              if case .welcomeBack = manager.phase, manager.canPlay {   // opened over the welcome screen (at launch): go straight into the game
                Task { await manager.startGame() }
              }                                                  // after Start the game is already loading behind it; from Settings: back to Settings
            }
            .transition(.opacity)
            .zIndex(5)
          }
        }//zs
        .environment(\.locale, manager.locale)                   // whole app in the user's native language
        .environment(\.layoutDirection, manager.layoutDirection) // right-to-left for Arabic, Hebrew…
        .task {                                                  // once at launch
          if hasCompletedOnboarding && !manager.requestModel.proffession.isEmpty {
            manager.phase = .welcomeBack                         // NEW — returning user: welcome screen instead of setup
            if !hasSeenTutorial { showTutorial = true }          // set up before, never saw (or closed the app mid-) tutorial
          }
          try? await Task.sleep(for: .seconds(5))                // keep LaunchScreen up for 5s
          withAnimation(.easeOut(duration: 0.8)) {
            launching = false
          }
        }//task
    }

    @ViewBuilder
    private var topRow: some View {                              // which top buttons each phase gets
        switch manager.phase {
        case .onboarding where hasStruggle:                       // setup screen: only the review button
            row(word: nil, buttons: .struggle, manager: manager)
        case .playing(let vm) where vm.guessResult == nil:        // in game, hidden while the answer result shows
            row(word: vm.word?.targetWord, buttons: hasStruggle ? .menu : .settings, manager: manager)
        default:
            EmptyView()                                          // includes .welcomeBack: it has its own buttons
        }
    }

  // MARK: - row(word:buttons:manager:)
  // Builds ButtonsTopRow for the current screen and wires its buttons to AppManager:
  //   word -> speaker button reads it (nil = no speaker); buttons -> which glass buttons show
  //   gear -> manager.openSettings(); review -> manager.startStruggleReview()
  //   hasAccess + onShowPaywall (NEW) -> free users get the paywall alert (paywall not built yet, just logs)
  private func row(word: String?, buttons: MenuButtonsEnum, manager: AppManager) -> some View {
    ButtonsTopRow(
      speechManager: speechManager,
      requestModel: manager.requestModel,
      word: word,
      direction: direction,
      hasAccess: manager.hasAccess,
      onShowPaywall: { print("💳 paywall — not built yet") },
      onOpenSettings: { manager.openSettings() },
      onReviewStruggle: { Task { await manager.startStruggleReview() }},
      buttons: buttons)
        .padding(.horizontal)
    }
}
