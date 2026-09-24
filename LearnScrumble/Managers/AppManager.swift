// AppManager.swift
import SwiftUI

@Observable
final class AppManager {
  var phase: GamePhase = .onboarding
  let requestModel: RequestModel
  private weak var activeVM: WordVM?

  init(requestModel: RequestModel) {
    self.requestModel = requestModel
  }

  @MainActor
  func startGame() async {
    phase = .generating
    await requestModel.generate()

    if requestModel.questions.isEmpty {
      phase = .failed(requestModel.errorMessage ?? "Something went wrong")
      print("Error: \(requestModel.errorMessage ?? "Unknown error")")
      return
    }

    let vm = WordVM(
      questions: requestModel.questions,
      targetLanguage: requestModel.selectedLanguage.rawValue,
      fetchMore: { [requestModel] exclude in
        await requestModel.generateMore(excluding: exclude)
      },
      onCheckpoint: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        self.phase = .result(vm)
      },
      onResume: { [weak self] in
        guard let self, let vm = self.activeVM else { return }
        self.phase = vm.isLoadingMore ? .generating : .playing(vm)
      }
    )
    activeVM = vm
    phase = .playing(vm)
  }

  func exitToSettings() {
    activeVM = nil
    phase = .onboarding
  }
}
