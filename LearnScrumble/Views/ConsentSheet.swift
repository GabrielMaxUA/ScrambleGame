//
//  ConsentSheet.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-15.
//

import SwiftUI

// MARK: - Flow of this file
// One-time "I agree" for people who finished setup before the consent step existed (App Review 5.1.2(i)).
//   RootView shows it before their next game or review, only while AIConsent.key is still 0.
//   "I agree"  -> saves the date (AIConsent.key) -> onAgree() -> RootView runs the game/review they tapped
//   "Not now" or swipe down -> sheet closes, they stay on the welcome screen; tapping play shows it again.
// New users never see it: EntryView's "I agree" checkbox covers them.

struct ConsentSheet: View {
  @AppStorage(AIConsent.key) private var consentDate: Double = 0    // when the user agreed; 0 = not yet
  let onAgree: () -> Void                                           // RootView: close the sheet, then start what was tapped
  let onNotNow: () -> Void                                          // RootView: just close the sheet
  private let privacyURL = URL(string: "https://your-site.com/privacy")! // TODO: replace with your real privacy policy URL

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "hand.raised")
        .font(.largeTitle)
        .foregroundStyle(.white)
      Text("Before you continue")
        .font(.title2.bold())
        .foregroundStyle(.white)
      Text(AIConsent.message)
        .font(.body)
        .foregroundStyle(.white.opacity(0.8))
      Text("Without this, the app can't create your words.")
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.6))
      Link("Privacy Policy", destination: privacyURL)
        .font(.footnote)
        .underline()
        .foregroundStyle(.white.opacity(0.6))

      VStack(spacing: 12) {
        Button {                                                    // save the agreement, then carry on
          consentDate = Date().timeIntervalSince1970
          onAgree()
        } label: {
          Text("I agree")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .glassCompat(in: .capsule, interactive: true)

        Button("Not now") { onNotNow() }
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding(.top, 8)
    }
    .multilineTextAlignment(.center)
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
  }
}

#Preview {
  ConsentSheet(onAgree: {}, onNotNow: {})
}
