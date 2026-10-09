//
//  ResultView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

struct ResultView: View {
    let vm: WordVM
    let hasAccess: Bool                                   // NEW — paid/unlocked user, passed in from AppManager
    let canPlay: Bool
    var onContinue: () -> Void
    var onRetry: () -> Void
    var onShowPaywall: () -> Void                         // NEW — "See plans" in the alert
    var exitToWelcome: () -> Void
    @State private var showSubscriptionAlert = false      // NEW — true while the "Premium feature" alert is showing
    @State private var alertType: MenuAlert = .subscriptionRequired   // NEW — which alert to show
    @State private var showAlert = false
    /// nil when there's nothing to score yet, so the tile shows "—"
    private func fraction(_ stat: (correct: Int, total: Int)) -> Double? {
        guard stat.total > 0 else { return nil }
        return Double(stat.correct) / Double(stat.total)
    }
    
    var body: some View {
        let setScore = fraction(vm.batchAccuracy())
        let overallScore = fraction(vm.overallAccuracy())
        let learnedEverything = !vm.hasStruggleWords && overallScore != nil   // only after at least one answered word
        let owlCelebrates = learnedEverything || (setScore ?? 0) >= 0.8   // big win or a strong set
        
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            
            if learnedEverything {
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
                
                Button(action: exitToWelcome) {
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
    }
    
    // MARK: - Building blocks
    
    private func statTile(title: LocalizedStringKey, score: Double?) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Group {
                if let score {
                    Text(score, format: .percent.precision(.fractionLength(0)))   // follows the app's locale, e.g. Arabic digits
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
        .accessibilityElement(children: .combine)                     // VoiceOver reads "This set, 80%"
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
