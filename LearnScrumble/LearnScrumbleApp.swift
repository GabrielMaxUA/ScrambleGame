//
//  LearnScrumbleApp.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI

@main
struct LearnScrumbleApp: App {
  @State private var requestModel = RequestModel()
  @AppStorage("allSet") var allSet: Bool = false
  
    var body: some Scene {
      WindowGroup {
          if allSet {
            MainView(questions: requestModel.questions, requestModel: requestModel)
              .task {
                if requestModel.questions.isEmpty {
                  await requestModel.generate()
                }
              }
              .fullScreenCover(isPresented: $requestModel.isLoading) {
                LoadingView()
              }
          } else {
            EntryView(requestModel: requestModel)
          }
      }
    }
}
