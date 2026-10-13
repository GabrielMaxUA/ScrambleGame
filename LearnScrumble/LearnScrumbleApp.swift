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
  @Environment(\.scenePhase) private var scenePhase               // tells us when the app comes on screen — used for the daily reminder below
  
  init() {
    let requestModel = RequestModel()
    _manager = State(initialValue: AppManager(requestModel: requestModel))
  }
  
  var body: some Scene {
    WindowGroup {
      RootView(manager: manager)
    }
    .modelContainer(PersistenceController.shared.container)
    // MARK: - Daily reminder renewal
    // App opened / back from background -> FreeAllowance.refresh() -> DailyReminder.reschedule()
    //   refresh(): if midnight passed, today's word count resets to 0
    //   reschedule(): reads that count -> books 9am reminders for the next 7 days (skips today if already played)
    // This is what keeps the 7-day window moving forward while the user keeps opening the app
    .onChange(of: scenePhase) { _, phase in                          // scenePhase = is the app on screen, in background or closing
      guard phase == .active else { return }                         // only when the app comes on screen
      FreeAllowance.shared.refresh()                                 // new day since last open: count starts at 0
      Task { await DailyReminder.reschedule() }                      // re-book the reminders using the fresh count
    }
  }
}
