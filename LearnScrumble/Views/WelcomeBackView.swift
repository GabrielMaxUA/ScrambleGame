//
//  WelcomeBackView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI

struct WelcomeBackView: View {
  let targetLanguage: String                     // language being learned — scopes the stats
  let hasAccess: Bool                            // paid/unlocked user
  var onContinue: () -> Void                     // start a game with the saved languages and profession
  var onReview: () -> Void                       // struggle review (paid)
  var onShowPaywall: () -> Void                  // "See plans" in the alert
  var onSettings: () -> Void                     // back to EntryView (paid)
  var previewHasStruggle: Bool? = nil            // previews only: force the struggle check on or off
  @State private var showAlert = false
  @State private var alertType: MenuAlert = .subscriptionRequired

  private var overallScore: Double? {            // nil when nothing has been answered yet, so the tile shows "—"
    let stat = PersistenceController.shared.overallAccuracy(targetLanguage: targetLanguage)
    guard stat.total > 0 else { return nil }
    return Double(stat.correct) / Double(stat.total)
  }

  private var hasStruggleWords: Bool {
    previewHasStruggle ?? !PersistenceController.shared.struggleToolNames(targetLanguage: targetLanguage).isEmpty
  }

  var body: some View {
    let score = overallScore

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

      statTile(title: "Overall", score: score)
        .overlay(alignment: .top) {
          LineOwl(isCelebrating: (score ?? 0) >= 0.8)   // nil (no history) counts as 0: owl sits still
            .alignmentGuide(.top) { $0[.bottom] - 4 }  // feet rest on the card
        }
        .padding(.top, 80)                             // room for the owl

      Spacer()

      VStack(spacing: 12) {
        Button(action: onContinue) {
          Text("Continue learning")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .glassEffect(.clear.interactive(), in: .capsule)

        if hasStruggleWords {
          Button {
            if hasAccess { onReview() } else { alertType = .subscriptionRequired; showAlert = true }
          } label: {
            Label("Improve previous!", systemImage: hasAccess ? "arrow.counterclockwise" : "lock.fill")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
          }
          .glassEffect(.clear.interactive(), in: .capsule)
        }

        Button {
          if hasAccess { onSettings() } else { alertType = .settingsLocked; showAlert = true }
        } label: {
          Label("Settings", systemImage: hasAccess ? "gear" : "lock.fill")
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
    .alert(alertType.title, isPresented: $showAlert) {
      Button(alertType.confirmTitle) { onShowPaywall() }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text(alertType.message)
    }
  }

  // same tile as ResultView
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
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(.white.opacity(0.2), lineWidth: 1)
    }
    .accessibilityElement(children: .combine)        // VoiceOver reads "Overall, 80%"
  }
}

#Preview {
  WelcomeBackView(targetLanguage: "uk-UA", hasAccess: false,
                  onContinue: {}, onReview: {}, onShowPaywall: {}, onSettings: {},
                  previewHasStruggle: true)
}
