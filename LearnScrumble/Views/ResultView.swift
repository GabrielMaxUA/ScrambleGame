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
//   Reads WordVM: batchAccuracy (this set), overallAccuracy (all time), hasStruggleWords, isFinished
//   -> "Learn more words!" / "Play again!": free words left -> onContinue (resume, or a new game after a review);
//      limit reached -> daily-limit alert right here
//   -> "Improve previous!": paid -> onRetry -> struggle review; free -> subscription alert
//   -> "Exit" -> exitToWelcome
//   The owl celebrates a strong set (80%+) or when there's nothing left to struggle with.

struct ResultView: View {
    let vm: WordVM                                        // the session that just paused — source of all scores
    let hasAccess: Bool                                   // NEW — paid/unlocked user, passed in from AppManager
    let canPlay: Bool                                     // paid, or free words left today
    var onContinue: () -> Void                            // resume this session (or start a new game after a review)
    var onRetry: () -> Void                               // start a struggle review
    var onShowPaywall: () -> Void                         // NEW — "See plans" in the alert
    var exitToWelcome: () -> Void                         // back to WelcomeBackView
    @State private var showSubscriptionAlert = false      // NEW — true while the "Premium feature" alert is showing
    @State private var alertType: MenuAlert = .subscriptionRequired   // NEW — which alert to show
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
        let overallScore = fraction(vm.overallAccuracy())         // all-time, this target language
        let learnedEverything = !vm.hasStruggleWords && overallScore != nil   // only after at least one answered word
        let owlCelebrates = learnedEverything || (setScore ?? 0) >= 0.8   // big win or a strong set
        
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            
            if learnedEverything {                                // headline only for the big win
                VStack(spacing: 8) {
                    Text("Congratulations!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("You have learned everything!")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // the owl perches on top of the score cards
            HStack(spacing: 12) {
                statTile(title: "This set", score: setScore)
                statTile(title: "Overall", score: overallScore)
            }
            .overlay(alignment: .top) {
                LineOwl(isCelebrating: owlCelebrates)
                    .alignmentGuide(.top) { $0[.bottom] - 4 }      // feet rest on the cards
            }
            .padding(.top, 80)                                      // room for the owl
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {                                              // free words left: continue; limit reached: alert right here, no silent jump to Welcome
                    if canPlay {
                        onContinue()
                    } else {
                        alertType = .dailyLimitReached
                        showAlert = true
                    }
                } label: {
                    Label(vm.isFinished ? "Play again!" : "Learn more words!", systemImage: canPlay ? "arrow.right" : "lock.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .glassCompat(in: .capsule, interactive: true)
                if vm.hasStruggleWords {
                    Button {                                            // NEW — paid users review, free users see the alert
                        if hasAccess {
                            onRetry()
                        } else {
                            alertType = .subscriptionRequired
                            showAlert = true
                        }
                    } label: {
                        Label("Improve previous!", systemImage: hasAccess ? "arrow.counterclockwise" : "lock.fill")
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
        .alert(alertType.title, isPresented: $showAlert) {                    // NEW — one alert for both cases
            Button(alertType.confirmTitle) { onShowPaywall() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(alertType.message)
        }
        .alertSound(isPresented: showAlert)
    }
    
    // MARK: - Building blocks
    
    // MARK: - statTile(title:score:)
    // One score card: a title and a big percent, or "—" when there's no score yet (nil).
    // The percent follows the app's locale (e.g. Arabic digits) and rolls when it changes.
    // VoiceOver reads the card as one element, e.g. "This set, 80%".
    private func statTile(title: LocalizedStringKey, score: Double?) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Group {
                if let score {
                    Text(score, format: .percent.precision(.fractionLength(0)))
                } else {
                    Text(verbatim: "—")
                }
            }
            .font(.system(size: 40, weight: .semibold, design: .rounded))
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
        hasAccess: false,// NEW
        canPlay: false,
        onContinue: {
        },
        onRetry: {},
        onShowPaywall: {},
        exitToWelcome: {})
}
