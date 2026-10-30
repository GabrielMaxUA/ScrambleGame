//
//  ProfessionStore.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-16.
//

import Foundation

// MARK: - Flow of this file
// Counts which jobs people learn for, to decide which jobs to add to the menu.
// Firestore collection "professions", one document per job in English, e.g. professions/cook:
//   name: "cook" · typed: 14 (typed under "Not listed?") · picked: 0 (chosen from the menu)
//   firstSeen · lastSeen · status: "in menu" (already a menu job: nothing to review) or "new" (missing from the menu:
//   review it, then set "added" or "rejected" by hand). Filter status == "new" in the console for the review list.
// Stored: only the English job name, the counts and the dates. Never the text the user typed, never a user ID.
// The same job typed or picked lands in the same document (menu "Electrician" and typed "elektryk" -> "electrician").
//
// Who calls what (since the Cloud Functions, the server does the Firestore write):
//   RequestModel.generate -> needsCounting(profession:) -> true is sent to getWords as countJob
//     -> the server counts the job (functions/src/store.ts countProfession: +1 "picked" or "typed", status, dates)
//   getWords worked -> markCounted(profession:)
//     1. Saves the job as counted on this phone (UserDefaults "countedProfession"):
//        playing again with the same job doesn't count again. A changed job counts once.
//     2. Analytics: profession_selected, job = menu name, or "custom" for a typed job (never the typed text).
//   The old in-app Firestore write (increment) is kept commented out below.

enum ProfessionStore {
  private static let countedKey = "countedProfession"              // the profession text last counted on this phone
  private static let collection = "professions"

  // MARK: - needsCounting(profession:)
  // true when this job hasn't been counted on this phone yet (empty job -> false).
  static func needsCounting(profession: String) -> Bool {
    let current = profession.trimmingCharacters(in: .whitespacesAndNewlines)
    return !current.isEmpty && UserDefaults.standard.string(forKey: countedKey) != current
  }

  // MARK: - markCounted(profession:)
  // After getWords counted the job: remembers it on this phone and sends the analytics event.
  static func markCounted(profession: String) {
    let current = profession.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !current.isEmpty else { return }
    UserDefaults.standard.set(current, forKey: countedKey)
    if let menuJob = Occupation(rawValue: current) ?? Occupation.renamed[current], menuJob != .notListed {
      Track.professionSelected(job: menuJob.rawValue)
    } else {
      Track.professionSelected(job: "custom")
    }
    Log.info("👷 ProfessionStore — job counted by the server", .firebase)
  }

  // MARK: - LEGACY (before Cloud Functions): the app wrote the counter itself
  /*
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
  */
}
