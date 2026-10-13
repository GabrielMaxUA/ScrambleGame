//
//  FirebaseWordModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import Foundation

// MARK: - Flow of this file
// One word document in Firestore ("words" collection), shared by all users.
//   FirebaseWordStore.fetchExisting() decodes docs into it -> RequestModel reuses cached translations/images
//   FirebaseWordStore.saveIfNeeded() creates or fills it after a word's image is resolved.

struct FirebaseWordModel: Codable, Identifiable {
    let id: String                                  // document id — the English toolName ("/" swapped for "-")
    let word: String                                // English toolName, e.g. "hammer"
    var translation: [String : String]//"language code suck as "uk-UA"": "translated word to it"
    var image: String                               // download URL of the WebP image in Firebase Storage ("" = none yet)
}
