//
//  WelcomeBackView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI

// MARK: - Flow of this file
// The returning user's start screen (phase .welcomeBack).
//   Reads PersistenceController.jobProgress (JobProgressCard: learned, right, wrong), Streak (🔥 days in a row)
//   and overall accuracy (the owl celebrates at 80% or more).
//   -> "Continue learning": unlocked or free words left (canPlay) -> onContinue -> AppManager.startGame();
//      free words used up -> alert -> "Unlock" -> onShowPaywall (PaywallView)
//   -> "My words" (once a word of this job was played): unlocked -> onWordList -> MyWordsView; otherwise the alert
//   -> gear (top) -> onSettings -> AppManager.openSettings()

struct WelcomeBackView: View {
  @Environment(\.topButtonsPadding) private var topButtons          // iPhone Duo: where the gear sits (RootView)
  let targetLanguage: String                     // language being learned — scopes the stats
  let job: Occupation?                           // the current job — scopes the progress card and "My words"
  let hasAccess: Bool                            // the current job is unlocked
  let canPlay: Bool                              // unlocked, or free words left (AppManager.canPlay)
  var onContinue: () -> Void                     // start a game with the saved languages and profession
  var onWordList: () -> Void                     // "My words" (unlocked)
  var onShowPaywall: () -> Void                  // "Unlock" in the alert
  var onSettings: () -> Void                     // opens SettingsView (free for everyone)
  @State private var showAlert = false                    // is the free-words / locked-list alert open
  @State private var alertType: MenuAlert = .wordListLocked   // which of the two alerts
  
  private var overallScore: Double? {            // nil when nothing has been answered yet, so the tile shows "—"
    let stat = PersistenceController.shared.overallAccuracy(targetLanguage: targetLanguage)
    guard stat.total > 0 else { return nil }
    return Double(stat.correct) / Double(stat.total)
  }
  
  private var progress: JobProgress {           // this job's numbers in this language (zeros when no job is picked)
    PersistenceController.shared.jobProgress(profession: job?.rawValue ?? "", targetLanguage: targetLanguage)
  }
  
  var body: some View {
    let score = overallScore                     // read once per redraw (it's a SwiftData fetch)
    let progress = progress
    
    VStack(spacing: 24) {
      Spacer(minLength: 40)
      
      VStack(spacing: 8) {
        Text("Welcome back!")
          .font(.largeTitle.bold())
          .foregroundStyle(.white)
        Text("Ready for more words?")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
      }
      .multilineTextAlignment(.center)
      
      Spacer()
      
      VStack(spacing: 8) {                             // the progress card + what "learned" means
        JobProgressCard(job: job, progress: progress, streak: Streak.shared.current)
          .overlay(alignment: .top) {
            LineOwl(isCelebrating: (score ?? 0) >= 0.8)   // nil (no history) counts as 0: owl sits still
              .alignmentGuide(.top) { $0[.bottom] - 4 }  // feet rest on the card
          }
        Text("A word is learned once you get it right at least twice, and 3 times out of 4.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)
      }
      .padding(.top, 80)                               // room for the owl
      
      Spacer()
      
      VStack(spacing: 12) {
        Button {                                       // free words left or unlocked: play; otherwise: alert
          if canPlay {
            onContinue()
          } else {
            alertType = .freeWordsDone
            showAlert = true
          }
        } label: {
          Label("Continue learning", systemImage: canPlay ? "arrow.right" : "lock.fill")   // lock once the free words are used
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .glassCompat(in: .capsule, interactive: true)
        
        if progress.played > 0 {
          Button {                                     // unlocked: the list; otherwise: the unlock alert
            if hasAccess { onWordList() } else { alertType = .wordListLocked; showAlert = true }
          } label: {
            Label("My words", systemImage: hasAccess ? "list.bullet.rectangle" : "lock.fill")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
          }
          .glassCompat(in: .capsule, interactive: true)
        }
        // NEW — the bottom Settings text button was removed; it's the gear at the top now
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {                                        // NEW — same place as the in-game gear
      Button(action: onSettings) {
        Image(systemName: "gear")
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: topButtons?.isFolded == true ? 40 : 44, height: topButtons?.isFolded == true ? 40 : 44)   // folded Duo: smaller
      }
      .glassCompat(in: .circle, interactive: true)
      .accessibilityLabel(Text("Settings"))
      .padding(.horizontal, topButtons?.horizontal ?? 20)   // iPhone Duo: like the in-game gear
      .padding(.top, topButtons?.top ?? 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(Color.black.opacity(0.92))
    .foldAlert(alertType.title, isPresented: $showAlert, message: alertType.message,   // locked list or free words used up
               confirmTitle: alertType.confirmTitle) { onShowPaywall() }
    .alertSound(isPresented: showAlert)
  }
}

#Preview {
  WelcomeBackView(targetLanguage: "uk-UA", job: .plumber, hasAccess: false,
                  canPlay: false,                                  // shows the locked "Continue learning"
                  onContinue: {}, onWordList: {}, onShowPaywall: {}, onSettings: {})
}
