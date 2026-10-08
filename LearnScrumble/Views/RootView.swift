import SwiftUI
import SwiftData

struct RootView: View {
    let manager: AppManager
    @State private var showMenu = false
    @State private var speechManager = SpeechManager()
    @State private var launching: Bool = true
    @AppStorage("pickedLanguage") private var pickedLanguage = "en-US"
    @Query(filter: #Predicate<SwiftDataWordModel> { $0.incorrect > 0 })
    private var missed: [SwiftDataWordModel]
    var direction: Bool {
      manager.layoutDirection == .leftToRight ? true : false
    }
    private var hasStruggle: Bool {
        missed.contains { $0.targetLanguage == pickedLanguage && $0.isStruggle }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            switch manager.phase {
            case .onboarding:
              EntryView(requestModel: manager.requestModel, onSubmit: {
                await manager.startGame()
              })
            case .generating:
                LoadingView()
            case .playing(let vm):
                MainView(vm: vm)
            case .failed(let message):
              ErrorView(message: LocalizedStringKey(message), direction: direction, onRetry: { await manager.startGame() }, onExit: { manager.exitToSettings()})
            case .result(let vm):
                ResultView(
                    vm: vm,
                    onContinue: {
                        if vm.isFinished {
                            Task { await manager.startGame() }   // struggle review just finished — nothing to continue, start a fresh normal session
                        } else {
                            vm.continueFromCheckpoint()          // normal checkpoint — resume this same session
                        }
                    },
                    onRetry: { Task { await manager.startStruggleReview() }},
                    exitToSettings: { manager.exitToSettings() })
            
            }
          if launching {
            LaunchScreen()
              .transition(.opacity)
              .zIndex(10)
          }
          topRow
        }//zs
        .environment(\.locale, manager.locale)
        .environment(\.layoutDirection, manager.layoutDirection)
        .task {
          try? await Task.sleep(for: .seconds(5))
          withAnimation(.easeOut(duration: 0.8)) {
            launching = false
          }
        }//task
    }
    
    @ViewBuilder
    private var topRow: some View {
        switch manager.phase {
        case .onboarding where hasStruggle:
            row(word: nil, buttons: .struggle, manager: manager)
        case .playing(let vm) where vm.guessResult == nil:
            row(word: vm.word?.targetWord, buttons: hasStruggle ? .menu : .settings, manager: manager)
        default:
            EmptyView()
        }
    }
    
  private func row(word: String?, buttons: MenuButtonsEnum, manager: AppManager) -> some View {
    ButtonsTopRow(
      speechManager: speechManager,
      requestModel: manager.requestModel,
      word: word,
      direction: direction,
      onExitToSettings: { manager.exitToSettings()
      },
      onReviewStruggle: { Task { await  manager.startStruggleReview() }},
      buttons: buttons)
        .padding(.horizontal)
    }
}
