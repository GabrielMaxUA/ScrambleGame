//
//  AIConsent.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-15.
//

import Foundation
import SwiftUI

// MARK: - Flow of this file
// The user's "I agree" to sending their job and two languages to OpenAI (App Review guideline 5.1.2(i)).
// Asked once. Saved in UserDefaults as the moment they agreed (seconds since 1970, 0 = not yet),
// shared with the views through @AppStorage(AIConsent.key).
//
// Who uses it:
//   EntryView    -> "Your data" card with the sentence and an "I agree" checkbox; Start Learning stays
//                   disabled until it's ticked (ticking saves the date, unticking clears it)
//   RootView     -> anyone who finished setup before this existed gets ConsentSheet once,
//                   before their next game or review; "Not now" leaves them on the welcome screen
//   SettingsView -> "Legal and support" repeats the sentence
//
// Without it the app can't create words, so declining simply means no game. That's acceptable,
// because the AI is the app's core function and the screen says so (AppStoreReadiness.md §1.4).

enum AIConsent {
  static let key = "aiConsentDate"                                  // when the user agreed, seconds since 1970; 0 = not yet
  static let message: LocalizedStringKey = "To create your words and pictures, your job, your two languages and the words you've already practised are sent to OpenAI."
}
