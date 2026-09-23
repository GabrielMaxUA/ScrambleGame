//
//  AppManager.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import SwiftUI

@Observable
final class AppManager {
  var phase: GamePhase = .onboarding
  let requestModel: RequestModel
  
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
      questions: requestModel.questions) { [requestModel] exclude in
        await requestModel.generateMore(excluding: exclude)
      }
    phase = .playing(vm)
  }
  
  func exitToSettings() {
    phase = .onboarding
  }
}

