//
//  RootView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import SwiftUI

struct RootView: View {
  let manager: AppManager
  
  var body: some View {
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
        }
      )
    case .failed(let message):
     ErrorView(message: message, onRetry: { await manager.startGame() })
    case .result(let vm):
      ResultView(vm: vm, onContinue: { vm.continueFromCheckpoint() })
    }
  }
}

#Preview {
  RootView(manager: AppManager(requestModel: RequestModel()))
}
