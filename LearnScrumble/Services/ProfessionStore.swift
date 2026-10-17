//
//  ProfessionStore.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-16.
//

import Foundation
import FirebaseFirestore

// MARK: - Flow of this file
// Counts which jobs people learn for, to decide which jobs to add to the menu (AppFlowIdeas §1).
// Firestore collection "professions", one document per job in English, e.g. professions/cook:
//   name: "cook" · typed: 14 (typed under "Not listed?") · picked: 0 (chosen from the menu)
//   firstSeen · lastSeen · status: "in menu" (already a menu job: nothing to review) or "new" (missing from the menu:
//   review it, then set "added" or "rejected" by hand). Filter status == "new" in the console for the review list.
// Stored: only the English job name, the counts and the dates. Never the text the user typed, never a user ID.
// The same job typed or picked lands in the same document (menu "Electrician" and typed "elektryk" -> "electrician").
//
// Who calls what:
//   RequestModel.generate (first batch of a game worked) -> recordIfNew(profession:jobInEnglish:)
//     1. Same job as the last one counted on this phone (UserDefaults "countedProfession") -> nothing:
//        playing again with the same job doesn't count again. A changed job counts once.
//     2. Menu job -> its English menu name, +1 "picked". Analytics: profession_selected, job = menu name.
//     3. Typed job -> GPT's English name (RequestModel.lastJobInEnglish), +1 "typed". Analytics: job = "custom",
//        never the typed text. "invalid" (not a real job, a name, junk) or missing -> not saved.
//   increment: updateData (count +1, lastSeen; menu jobs also get status "in menu") -> no document yet -> setData creates it
//   (firstSeen, status "in menu" or "new").
//   Any Firestore error is logged and ignored: counting must never get in the way of the game.
// Later (ServerMigrationPlan Phase 4) the server does this write instead, and the data stays.

enum ProfessionStore {
  private static let countedKey = "countedProfession"              // the profession text last counted on this phone
  private static let collection = "professions"

  // MARK: - recordIfNew(profession:jobInEnglish:)
  // See the steps above. `profession` = what's in RequestModel (menu English name or typed text).
  static func recordIfNew(profession: String, jobInEnglish: String?) {
    let current = profession.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !current.isEmpty, UserDefaults.standard.string(forKey: countedKey) != current else { return }
    UserDefaults.standard.set(current, forKey: countedKey)

    if let menuJob = Occupation(rawValue: current), menuJob != .notListed {
      Track.professionSelected(job: menuJob.rawValue)
      Task { await increment("picked", name: menuJob.rawValue.lowercased()) }
      return
    }

    Track.professionSelected(job: "custom")
    guard let job = jobInEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
          !job.isEmpty, job != "invalid", job.count <= 40 else {
      Log.info("👷 ProfessionStore — typed job not counted (invalid or missing)", .firebase)
      return
    }
    Task { await increment("typed", name: job) }
  }

  private static let menuNames = Set(Occupation.allCases.filter { $0 != .notListed }.map { $0.rawValue.lowercased() })   // "cook", "electrician"…
  
  // MARK: - increment(_:name:)
  // 1. Existing document: +1 on `field` and a new lastSeen.
  //    A menu job also gets status "in menu" (fixes documents created as "new" before this rule).
  // 2. Not there yet (notFound): create it with this count at 1, the other at 0, firstSeen, status "in menu" or "new".
  //    merge + increment, so two phones creating it at the same moment still add up.
  private static func increment(_ field: String, name: String) async {
    let id = name.replacingOccurrences(of: "/", with: "-")           // "/" isn't allowed in a document id
    let ref = Firestore.firestore().collection(collection).document(id)
    let inMenu = menuNames.contains(name)
    do {
      var update: [String: Any] = [
        field: FieldValue.increment(Int64(1)),
        "lastSeen": FieldValue.serverTimestamp()
      ]
      if inMenu { update["status"] = "in menu" }                    // never overwrite a reviewer's added / rejected otherwise
      try await ref.updateData(update)
      Log.info("👷 ProfessionStore — +1 \(field)", .firebase, private: "'\(name)'")
    } catch let error as NSError where error.domain == FirestoreErrorDomain && error.code == FirestoreErrorCode.notFound.rawValue {
      let other = field == "typed" ? "picked" : "typed"
      do {
        try await ref.setData([
          "name": name,
          field: FieldValue.increment(Int64(1)),
          other: FieldValue.increment(Int64(0)),
          "firstSeen": FieldValue.serverTimestamp(),
          "lastSeen": FieldValue.serverTimestamp(),
          "status": inMenu ? "in menu" : "new"
        ], merge: true)
        Log.info("👷 ProfessionStore — new job, \(field) = 1", .firebase, private: "'\(name)'")
      } catch {
        Log.error("👷 ProfessionStore — create failed", .firebase, private: "\(name): \(error)")
      }
    } catch {
      Log.error("👷 ProfessionStore — update failed", .firebase, private: "\(name): \(error)")
    }
  }
}
