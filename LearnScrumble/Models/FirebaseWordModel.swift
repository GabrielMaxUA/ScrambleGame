//
//  FirebaseWordModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import Foundation

// MARK: - Flow of this file
// One word document in Firestore ("words" collection), shared by all users.
// ⚠️ LEGACY in the app: only the old FirebaseWordStore uses it. The server now owns these docs
// (functions/src/store.ts WordDoc — same fields) and sends the app plain words instead.
// The fields below still describe what's stored in Firestore:
//   the server's getWords finds every word tagged with a profession (the word bank), creates or fills docs,
//   and adds the profession the word was shown for to `professions`; getPicture sets `image`.

struct FirebaseWordModel: Codable, Identifiable {
    let id: String                                  // document id — the English toolName ("/" swapped for "-")
    let word: String                                // English toolName, e.g. "hammer"
    var translation: [String : String]//"language code suck as "uk-UA"": "translated word to it"
    var image: String                               // download URL of the WebP image in Firebase Storage ("" = none yet)
    var professions: [String]?                      // English profession keys this word belongs to, e.g. ["cook", "baker"]
                                                    // (RequestModel.professionKey). nil on words saved before the bank existed:
                                                    // they get tagged the next time they're shown for a profession.
}
