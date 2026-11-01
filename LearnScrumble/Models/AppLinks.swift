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
// French app language -> the French pages (learnscrumble.com/fr/…), see page(_:).
//
// Used by:
//   SettingsView   -> Privacy Policy, Terms of Use, Contact support
//   EntryView      -> Privacy Policy link under the consent checkbox
//   ConsentSheet   -> Privacy Policy link in the one-time consent sheet

enum AppLinks {
  static let website = URL(string: "https://learnscrumble.com")!
  static var privacy: URL { page("privacy") }                                  // privacy.html (fr/privacy.html)
  static var terms: URL { page("terms") }                                      // terms.html (fr/terms.html)
  static var support: URL { page("support") }                                  // support.html (FAQ + contact)

  // MARK: - page(_:)
  // The site has English pages and French ones under /fr/ (Québec law: the terms and privacy policy in French).
  // When the user's own language (the app's language, "nativeLanguage") is French, the French page opens.
  private static func page(_ name: String) -> URL {
    let native = UserDefaults.standard.string(forKey: "nativeLanguage") ?? "en-US"
    let folder = native.hasPrefix("fr") ? "fr/" : ""
    return URL(string: "https://learnscrumble.com/\(folder)\(name)")!
  }

  static let supportEmail = "support@learnscrumble.com"                        // Namecheap Private Email
  static let supportMail = URL(string: "mailto:\(supportEmail)")!              // opens Mail with the address filled in
}
