//
//  LearnScrumbleApp.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI
import SwiftData

// MARK: - Flow of this file
// The app's entry point (@main).
//   Launch -> AppDelegate sets up Firebase
//          -> init() creates the one RequestModel and the one AppManager for the whole app
//          -> body shows RootView(manager:) with the SwiftData container attached
//   Every time the app comes on screen -> FreeAllowance.refresh() -> DailyReminder.reschedule()

@main
struct LearnScrumbleApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate   // plugs in AppDelegate (Firebase setup at launch)
  @State private var manager: AppManager                           // the app's single AppManager — kept alive for the whole run
  @Environment(\.scenePhase) private var scenePhase               // tells us when the app comes on screen — used for the daily reminder below
  
  // MARK: - init
  // Builds the shared data layer (RequestModel) and hands it to AppManager,
  // which every screen then reaches through RootView.
  init() {
    let requestModel = RequestModel()
    _manager = State(initialValue: AppManager(requestModel: requestModel))
  }
  
  var body: some Scene {
    WindowGroup {
      RootView(manager: manager)                                   // RootView picks the screen from manager.phase
    }
    .modelContainer(PersistenceController.shared.container)        // SwiftData store for @Query in the views
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
