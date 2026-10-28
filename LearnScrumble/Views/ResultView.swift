//
//  ResultView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

// MARK: - Flow of this file
// The checkpoint screen after a round (phase .result(vm)).
//   WordVM reaches a checkpoint -> AppManager sets .result(vm) -> RootView shows ResultView
//   Reads WordVM: batchAccuracy (this round), jobProgress (JobProgressCard: learned, right, wrong), isFinished;
//   Streak for the 🔥 days in a row.
//   -> main button: "Keep reviewing" (a review with words left) or "Learn more words!" -> onContinue
//      (resume, or a new game after a finished review); free words used up -> alert -> "Unlock" -> onShowPaywall
//   -> "My words": unlocked -> onWordList; otherwise the unlock alert
//   -> "Exit" -> exitToWelcome
//   The owl celebrates a strong round (80%+).

struct ResultView: View {
    let vm: WordVM                                        // the session that just paused — source of all scores
    let job: Occupation?                                  // the current job, for the progress card's header
    let isReview: Bool                                    // this round was a "My words" review
    let hasAccess: Bool                                   // the current job is unlocked, passed in from AppManager
    let canPlay: Bool                                     // unlocked, or free words left
    var onContinue: () -> Void                            // resume this session (or start a new game after a review)
    var onWordList: () -> Void                            // "My words"
    var onShowPaywall: () -> Void                         // "Unlock" in the alert
    var exitToWelcome: () -> Void                         // back to WelcomeBackView
    @State private var alertType: MenuAlert = .wordListLocked   // which alert to show
    @State private var showAlert = false                  // is the alert open
    // MARK: - fraction(_:)
    // (correct, total) -> 0...1 share of right answers.
    // nil when there's nothing to score yet, so the tile shows "—".
    private func fraction(_ stat: (correct: Int, total: Int)) -> Double? {
        guard stat.total > 0 else { return nil }
        return Double(stat.correct) / Double(stat.total)
    }
    
    var body: some View {
        let setScore = fraction(vm.batchAccuracy())               // this round only
        let progress = vm.jobProgress()                           // this job, all time, this target language
        let keepReviewing = isReview && !vm.isFinished            // a review with words still to come
        
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            
            // the owl perches on top of the round's score
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    statTile(title: "This round", score: setScore)
                        .overlay(alignment: .top) {
                            LineOwl(isCelebrating: (setScore ?? 0) >= 0.8)
                                .alignmentGuide(.top) { $0[.bottom] - 4 }  // feet rest on the card
                        }
                    Text("Share of words you answered correctly")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                JobProgressCard(job: job, progress: progress, streak: Streak.shared.current)
            }
            .padding(.top, 80)                                      // room for the owl
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {                                              // can play: continue; free words used up: alert right here, no silent jump to Welcome
                    if canPlay {
                        onContinue()
                    } else {
                        alertType = .freeWordsDone
                        showAlert = true
                    }
                } label: {
                    Label(keepReviewing ? "Keep reviewing" : "Learn more words!", systemImage: canPlay ? "arrow.right" : "lock.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .glassCompat(in: .capsule, interactive: true)
                if progress.played > 0 {
                    Button {                                            // unlocked: the list; otherwise: the unlock alert
                        if hasAccess {
                            onWordList()
                        } else {
                            alertType = .wordListLocked
                            showAlert = true
                        }
                    } label: {
                        Label("My words", systemImage: hasAccess ? "list.bullet.rectangle" : "lock.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .glassCompat(in: .capsule, interactive: true)
                }
                
                Button(action: exitToWelcome) {                       // quiet text button at the bottom
                    Text("Exit")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 24)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92))
        .alert(alertType.title, isPresented: $showAlert) {                    // one alert for both cases
            Button(alertType.confirmTitle) { onShowPaywall() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(alertType.message)
        }
        .alertSound(isPresented: showAlert)
    }
    
    // MARK: - Building blocks
    
    // MARK: - statTile(title:score:)
    // One score card: a title and a big percent, or "No answers yet" when there's no score yet (nil).
    // The percent follows the app's locale (e.g. Arabic digits) and rolls when it changes.
    // VoiceOver reads the card as one element, e.g. "This round, 80%".
    private func statTile(title: LocalizedStringKey, score: Double?) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Group {
                if let score {
                    Text(score, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                } else {
                    Text("No answers yet")                         // nothing answered yet
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 48)                      // same height as the big percent, so the card doesn't jump
                }
            }
            .foregroundStyle(.white)
            .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ResultView(
        vm: WordVM(questions: [], targetLanguage: "uk-UA"),
        job: .plumber,
        isReview: false,
        hasAccess: false,
        canPlay: false,
        onContinue: {},
        onWordList: {},
        onShowPaywall: {},
        exitToWelcome: {})
}
