import SwiftUI
import SwiftData

struct RootView: View {
    let manager: AppManager
    @State private var showMenu = false
    @State private var speechManager = SpeechManager()
    @AppStorage("pickedLanguage") private var pickedLanguage = ""
    @Query(filter: #Predicate<SwiftDataWordModel> { $0.incorrect > 0 })
    private var missed: [SwiftDataWordModel]
    
    private var hasStruggle: Bool {
        missed.contains { $0.targetLanguage == pickedLanguage }
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
                MainView(
                    requestModel: manager.requestModel,
                    vm: vm,
                    onExitToSettings: {
                        manager.exitToSettings()
                    },
                    onReviewStruggle: {
                        Task{ await manager.startStruggleReview() }
                    }
                )
            case .failed(let message):
                ErrorView(message: message, onRetry: { await manager.startGame() }, onExit: { manager.exitToSettings()})
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
            topRow
        }
    }
    
    @ViewBuilder
    private var topRow: some View {
        switch manager.phase {
        case .onboarding where hasStruggle:
            row(word: nil, showSettings: false, singleButton: true)
            
        case .playing(let vm) where hasStruggle:
            row(word: vm.word?.targetWord ?? "", showSettings: true, singleButton: false)
        default:
            EmptyView()
        }
    }
    
    private func row(word: String?, showSettings: Bool, singleButton: Bool) -> some View {
        ButtonsTopRow(
            showMenu: $showMenu,
            speechManager: speechManager,
            requestModel: manager.requestModel,
            showSettings: showSettings,
            showStruggle: hasStruggle,
            word: word,
            onExitToSettings: { manager.exitToSettings()},
            onReviewStruggle: {Task { await manager.startStruggleReview()}}
        )
        .padding(.horizontal)
    }
}
