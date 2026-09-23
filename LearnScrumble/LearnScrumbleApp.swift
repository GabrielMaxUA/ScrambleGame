//
//  LearnScrumbleApp.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI
import SwiftData

@main
struct LearnScrumbleApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @State private var manager: AppManager
  
  init() {
    let requestModel = RequestModel()
    _manager = State(initialValue: AppManager(requestModel: requestModel))
  }
  
  var body: some Scene {
    WindowGroup {
      RootView(manager: manager)
    }
    .modelContainer(PersistenceController.shared.container)
  }
}
