
import SwiftUI

// MARK: - Flow of this file
// The app's one root screen: switches on AppManager.phase and shows the matching view.
//   LearnScrumbleApp -> RootView(manager:)
//   phase -> EntryView / WelcomeBackView / LoadingView / MainView / ErrorView / OfflineView / ResultView / SettingsView / MyWordsView
//   Each view's buttons call back into AppManager (startGame, openWordList, startReview, retry, exitToWelcome, openSettings…),
//   which changes phase -> RootView redraws with the new screen.
//   On top: LaunchScreen for the first 2s, and the top button row (ButtonsTopRow) on onboarding / playing.
//   "How to play" tutorial (OnboardingView) over everything while showTutorial is true:
//     after the setup screen's Start (the first words load behind it), at launch for anyone who finished setup
//     but never saw it, and from Settings' "How to play".
//     Closing it ("Let's go!" or Skip) over the welcome screen starts the game; after Start the game is already
//     loading behind it; from Settings it returns to Settings.
//   Applies the user's native language (locale + left/right direction) to every screen below it.
//   OpenAI consent: anyone without it (set up before the consent step existed) gets ConsentSheet before
//     their next game (withConsent). "I agree" runs what they tapped; "Not now" keeps them here.
//   Every "Unlock" button -> showPaywall -> PaywallView for the current job (a sheet).

struct RootView: View {
    let manager: AppManager                                           // owns phase and starts every session
    @State private var showMenu = false                               // not used right now
    @State private var speechManager = SpeechManager()                // one speech engine shared by the top row
    @State private var launching: Bool = true                         // LaunchScreen visible
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false   // true after the first "Let's go"
    @AppStorage(OnboardingService.seenKey) private var hasSeenTutorial = false        // true once "How to play" was finished or skipped
    @State private var showTutorial = false                           // the "How to play" tutorial is on screen
    @AppStorage(AIConsent.key) private var consentDate: Double = 0    // when the user agreed to OpenAI; 0 = not yet
    @State private var showConsent = false                            // ConsentSheet is on screen
    @State private var afterConsent: (() -> Void)?                    // what to start once they agree
    @State private var showPaywall = false                            // PaywallView is on screen
    @State private var screenSize: CGSize = .zero                     // decides FoldLayout (opened iPhone Duo or not)
    @State private var safeTop: CGFloat = 50                          // 0 on the folded Duo's outer screen (clock on the side)
    private var topButtons: TopButtonsPadding? {                      // where the round top buttons sit (FoldLayout.swift)
      FoldLayout.topButtonsPadding(FoldLayout.from(screenSize), safeTop: safeTop)
    }
    var direction: Bool {                                             // true = native language reads left-to-right
      manager.layoutDirection == .leftToRight ? true : false
    }

    var body: some View {
        ZStack(alignment: .top) {
          Group {                                                // the current screen
            switch manager.phase {
            case .onboarding:                                    // first launch: languages + profession
              EntryView(requestModel: manager.requestModel, onSubmit: {
                hasCompletedOnboarding = true                    // setup done: next launch shows the welcome-back screen
                Track.onboardingCompleted(origin: manager.requestModel.nativeLanguage, target: manager.requestModel.selectedLanguage)
                // MARK: - Daily reminder permission
                // "Let's go" -> DailyReminder.requestPermission() -> iOS Allow / Don't Allow popup (iOS shows it once ever)
                //   Allow -> DailyReminder.reschedule() books the 9am reminders for the next 7 days
                // Separate Task so startGame() below starts loading words while the popup is on screen
                Task {
                  if await DailyReminder.requestPermission() { Track.reminderEnabled(source: .onboarding) }
                }
                if !hasSeenTutorial { showTutorial = true }        // tutorial while the first words load behind it
                await manager.startGame()
              })
            case .welcomeBack:                                   // NEW — returning user's start screen
              WelcomeBackView(
                cabinet: manager.cabinet,
                targetLanguage: manager.requestModel.selectedLanguage.rawValue,
                onCard: { card in                                // the card becomes the current job + language
                  switch manager.cabinet.select(card) {
                  case .wordList: manager.openWordList()         // bought: "My words" with Continue / Repeat all
                  case .play: withConsent { Task { await manager.startGame() } }   // free words left
                  case .paywall: showPaywall = true              // free words used up: unlock this job
                  }
                },
                onSettings: { manager.openSettings() })
            case .generating:                                    // words/images loading
                LoadingView(progress: manager.requestModel.progress)
            case .playing(let vm):                               // the game
                MainView(vm: vm, manager: manager, topInset: topButtons?.isFolded == true ? 60 : 72)   // folded Duo: below the 40 pt buttons (12 + 40 + 8)
            case .failed(let error):                             // something broke — ErrorView picks the useful button
              ZStack {                                           // opened iPhone Duo: dims everything, the message on the right / top half
                Color.black.ignoresSafeArea()
                PopupHalf(layout: FoldLayout.from(screenSize)) {
                  ErrorView(
                    error: error,
                    direction: direction,
                    onRetry: { await manager.retry() },
                    onExit: { manager.exitToWelcome()},
                    onChangeProfession: { manager.openSettings() })
                }
              }
            case .offline:                                       // no internet — retries by itself when back online
              OfflineView(
                direction: direction,
                onRetry: { await manager.retry() },
                onExit: { manager.exitToWelcome() })
            case .result(let vm):                                // checkpoint summary after a round
                ResultView(
                    vm: vm,
                    job: manager.currentJob,
                    isReview: manager.isReviewSession,
                    hasAccess: manager.hasAccess,
                    canPlay: manager.canPlay,
                    onContinue: {
                        if vm.isFinished {
                            withConsent { Task { await manager.startGame() } }   // review finished — start a fresh normal session
                        } else {
                            vm.continueFromCheckpoint()          // normal checkpoint — resume this same session
                        }
                    },
                    onWordList: { manager.openWordList() },
                    onShowPaywall: { showPaywall = true },
                    exitToWelcome: { manager.exitToWelcome() })
            case .settings:
              SettingsView(
                requestModel: manager.requestModel,
                hasAccess: Purchases.shared.hasAnyUnlock,        // any unlocked job opens the voice picker
                onShowPaywall: { showPaywall = true },
                onDone: { manager.closeSettings() },
                onHowToPlay: { showTutorial = true }             // replay the tutorial over Settings
              )
            case .wordList:                                      // "My words" — the job's saved words
              MyWordsView(
                job: manager.currentJob,
                targetLanguage: manager.requestModel.selectedLanguage.rawValue,
                onContinue: { withConsent { Task { await manager.startGame() } } },
                onRepeat: { manager.startReview() },
                onBack: { manager.exitToWelcome() })
            }
          }
          .accessibilityHidden(showTutorial)                     // VoiceOver reads only the tutorial while it's on top
          if launching {                                         // intro over everything for the first 2s
            LaunchScreen()
              .transition(.opacity)
              .zIndex(10)
          }
          topRow                                                 // top buttons, only on some phases
          if showTutorial {                                      // "How to play", over the game and its buttons
            OnboardingView(manager: manager) {                   // "Let's go!" or Skip
              withAnimation { showTutorial = false }
              if case .welcomeBack = manager.phase, manager.canPlay {   // opened over the welcome screen (at launch): go straight into the game
                withConsent { Task { await manager.startGame() } }
              }                                                  // after Start the game is already loading behind it; from Settings: back to Settings
            }
            .transition(.opacity)
            .zIndex(5)
          }
          if let alert = FoldAlertCenter.shared.current, let layout = FoldLayout.from(screenSize) {
            FoldAlertCard(alert: alert, layout: layout)          // opened iPhone Duo: the app's alerts on the right / top half
              .zIndex(10)
          }
        }//zs
        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = $0 }
        .background {                                            // the screen's real top inset (a view inside the safe area reads 0)
          Color.clear
            .ignoresSafeArea()
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { safeTop = $0 }
        }
        .environment(\.foldLayout, FoldLayout.from(screenSize)) // MainView, alerts and pop-ups follow the opened iPhone Duo
        .environment(\.topButtonsPadding, topButtons)            // WelcomeBackView's gear, like the top row here
        .sheet(isPresented: $showConsent, onDismiss: { afterConsent = nil }) {   // one-time OpenAI consent for older users
          ConsentSheet(
            onAgree: {
              let action = afterConsent
              showConsent = false
              action?()                                          // start the game/review they tapped
            },
            onNotNow: { showConsent = false })
          .environment(\.locale, manager.locale)                 // same language and direction as the screen behind it
          .environment(\.layoutDirection, manager.layoutDirection)
          .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPaywall) {                      // "Unlock" anywhere -> the current job's unlock screen
          if let job = manager.currentJob {
            PaywallView(job: job,
                        onUnlocked: { showPaywall = false },     // hasAccess is true now: the locked buttons open up
                        onClose: { showPaywall = false })
            .environment(\.locale, manager.locale)
            .environment(\.layoutDirection, manager.layoutDirection)
          }
        }
        .environment(\.locale, manager.locale)                   // whole app in the user's native language
        .environment(\.layoutDirection, manager.layoutDirection) // right-to-left for Arabic, Hebrew…
        .task {                                                  // once at launch
          if hasCompletedOnboarding && !manager.requestModel.proffession.isEmpty {
            manager.phase = .welcomeBack                         // NEW — returning user: welcome screen instead of setup
            if !hasSeenTutorial { showTutorial = true }          // set up before, never saw (or closed the app mid-) tutorial
            // MARK: - "Not listed?" hidden (28 Oct 2026): a saved typed job can't be unlocked -> Settings to pick a menu job
            // (ProfessionPicker clears the typed text there). Remove when typed jobs come back.
            if manager.currentJob == nil { manager.phase = .settings }
          }
          try? await Task.sleep(for: .seconds(2))                // keep LaunchScreen up for 2s
          withAnimation(.easeOut(duration: 0.8)) {
            launching = false
          }
        }//task
    }

    @ViewBuilder
    private var topRow: some View {                              // which top buttons each phase gets
        switch manager.phase {
        case .playing(let vm) where vm.guessResult == nil:        // in game, hidden while the answer result shows
            row(word: vm.word?.targetWord, buttons: .settings, manager: manager)
        default:
            EmptyView()                                          // includes .welcomeBack: it has its own buttons
        }
    }

  // MARK: - row(word:buttons:manager:)
  // Builds ButtonsTopRow for the current screen and wires its buttons to AppManager:
  //   word -> speaker button reads it (nil = no speaker); buttons -> which glass buttons show
  //   gear -> manager.openSettings(); onShowPaywall -> PaywallView
  private func row(word: String?, buttons: MenuButtonsEnum, manager: AppManager) -> some View {
    ButtonsTopRow(
      speechManager: speechManager,
      requestModel: manager.requestModel,
      word: word,
      onShowPaywall: { showPaywall = true },
      onOpenSettings: { manager.openSettings() },
      buttons: buttons,
      buttonSize: topButtons?.buttonSize ?? 50)
        .padding(.horizontal, topButtons?.horizontal ?? 16)      // iPhone Duo: clear of its corners and edges
        .padding(.top, topButtons?.top ?? 0)
    }

  // MARK: - withConsent(_:)
  // Runs `action` right away if the user already agreed to OpenAI (AIConsent.key).
  // Otherwise remembers it and shows ConsentSheet; "I agree" runs it, "Not now" drops it.
  private func withConsent(_ action: @escaping () -> Void) {
    if consentDate > 0 {
      action()
    } else {
      afterConsent = action
      showConsent = true
    }
  }
}
