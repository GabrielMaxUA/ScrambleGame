//
//  AppLinks.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-18.
//

import Foundation

// MARK: - Flow of this file
// Every web address and email the app shows, in one place.
// The pages live in WebsiteContent/ and are published with Firebase Hosting to learnscrumble.com
// (see WebsiteContent/README.md). Change an address here and every screen follows.
//
// Used by:
//   SettingsView   -> Privacy Policy, Terms of Use, Contact support
//   EntryView      -> Privacy Policy link under the consent checkbox
//   ConsentSheet   -> Privacy Policy link in the one-time consent sheet

enum AppLinks {
  static let website = URL(string: "https://learnscrumble.com")!
  static let privacy = URL(string: "https://learnscrumble.com/privacy")!       // privacy.html
  static let terms = URL(string: "https://learnscrumble.com/terms")!           // terms.html
  static let support = URL(string: "https://learnscrumble.com/support")!       // support.html (FAQ + contact)

  static let supportEmail = "support@learnscrumble.com"                        // Namecheap Private Email
  static let supportMail = URL(string: "mailto:\(supportEmail)")!              // opens Mail with the address filled in
}
