//
//  FirebaseWordStore.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import FirebaseFirestore

// MARK: - Flow of this file
// ⚠️ LEGACY — not called any more. Since the Cloud Functions, the server reads and writes the word docs
// (functions/src/store.ts: fetchBank, fetchWords, saveWord), and the Firestore rules will be read-only for phones.
// Kept for reference only, with RequestModel's LEGACY block; delete both together.
//
// What it did: the Firestore layer for word documents, one doc per
// toolName under the "words" collection. It knew nothing about GPT, SwiftData,
// or sessions — RequestModel was the only caller.
//
//   fetchExisting(toolNames:)  <- RequestModel.buildQuestions (and generateStruggleReview), once per batch:
//                                 "which of these words do we already have cached, and with what data?"
//                                 -> cached image URLs are reused instead of paying for new images
//   fetchBank(profession:)     <- RequestModel.generate (once per game session): every word already tagged
//                                 with this profession -> words the user hasn't seen are played without GPT
//   saveIfNeeded(...)          <- RequestModel.resolveImage, once per word after its image is resolved:
//                                 creates the doc if it's new, or fills in whichever translation/image
//                                 slot was still missing (origin, target, or both), and adds the
//                                 profession to the word's `professions` list (arrayUnion: never twice)
//   documentID(for:)           <- all of the above: toolName -> safe Firestore document id

enum FirebaseWordStore {
  // MARK: - documentID(for:)
  // Firestore document IDs can't contain "/" (it separates path levels), so "a/c unit" -> "a-c unit".
  // Only "/" changes, so every ID already saved stays exactly the same.
  private static func documentID(for toolName: String) -> String {
    toolName.replacingOccurrences(of: "/", with: "-")
  }
  private static let maxInQueryValues = 30                           // Firestore's limit for one "in" query
  
  // MARK: - saveIfNeeded
  // Create-or-fill: the single entry point buildQuestions actually uses (through resolveImage).
  // `profession` = the bank key the word was shown for (nil for struggle review: no tagging).
  // `knownDoc` = the word's doc if the caller already has it (bank or fetchExisting) -> no extra read.
  // 1. Points at this word's doc — one doc per toolName. Reads it only if the caller didn't pass knownDoc.
  // 2. Case 1 — doc doesn't exist yet: builds a brand-new doc with the two languages we have right now
  //    (origin + target), the image URL and the profession, and writes it.
  // 3. Otherwise works out what's missing: origin translation? target translation? image? this profession?
  //    Case 2 — nothing missing: no write.
  // 4. Case 3 — something missing: one updateData with only the missing fields. The profession goes in
  //    with arrayUnion, so two phones tagging the same word at once never duplicate or lose it.
  //    Everything else in the doc stays untouched.
  // Any Firestore error is only logged — a failed save never stops the game.
  static func saveIfNeeded(
    toolName: String,
    originLanguage: Languages,
    originWord: String,
    targetLanguage: Languages,
    targetWord: String,
    imageURL: String,
    profession: String?,
    knownDoc: FirebaseWordModel?
  ) async {
    let docRef = Firestore.firestore().collection("words").document(documentID(for: toolName))
    Log.debug("🔥 saveIfNeeded — checking '\(toolName)' (origin=\(originLanguage.rawValue), target=\(targetLanguage.rawValue), known=\(knownDoc != nil))", .firebase)

    do {
      var stored = knownDoc
      if stored == nil {                                              // caller didn't have it -> one read
        let snapshot = try await docRef.getDocument()
        if snapshot.exists { stored = try? snapshot.data(as: FirebaseWordModel.self) }
      }

      guard let existing = stored else {                                       // Case 1: brand-new word
        let newWord = FirebaseWordModel(
          id: toolName,
          word: toolName,
          translation: [
            originLanguage.rawValue: originWord,
            targetLanguage.rawValue: targetWord
          ],
          image: imageURL,
          professions: profession.map { [$0] }
        )
        try docRef.setData(from: newWord)
        Log.info("🆕 saveIfNeeded — new word, created doc with [\(originLanguage.rawValue), \(targetLanguage.rawValue)], tagged=\(profession != nil)", .firebase, private: "'\(toolName)' profession=\(profession ?? "-")")
        return
      }

      let missingOrigin = existing.translation[originLanguage.rawValue] == nil
      let missingTarget = existing.translation[targetLanguage.rawValue] == nil
      let missingImage = existing.image.isEmpty && !imageURL.isEmpty
      let missingProfession = profession.map { !(existing.professions ?? []).contains($0) } ?? false
      guard missingOrigin || missingTarget || missingImage || missingProfession else {   // Case 2
        Log.debug("✅ saveIfNeeded — '\(toolName)' already complete for this pair and profession, no write", .firebase)
        return
      }

      var update: [AnyHashable: Any] = [:]                             // Case 3: only the missing fields
      if missingOrigin { update[FieldPath(["translation", originLanguage.rawValue])] = originWord }
      if missingTarget { update[FieldPath(["translation", targetLanguage.rawValue])] = targetWord }
      if missingImage { update["image"] = imageURL }
      if missingProfession, let profession { update["professions"] = FieldValue.arrayUnion([profession]) }
      try await docRef.updateData(update)
      Log.info("➕ saveIfNeeded — word existed, filled origin=\(missingOrigin) target=\(missingTarget) image=\(missingImage) profession=\(missingProfession)", .firebase, private: "'\(toolName)' profession=\(profession ?? "-")")

    } catch {
      Log.error("FirebaseWordStore save error", .firebase, private: "\(toolName): \(error)")
    }
  }

    // MARK: - fetchExisting(toolNames:)
    // Reads the Firestore docs for a list of words in as few requests as possible.
    // 1. toolNames -> document ids, duplicates removed. Nothing to look up -> empty result.
    // 2. Firestore allows at most 30 ids per "in" query, so the ids go in groups of 30, one query per group.
    // 3. Every doc that decodes into a FirebaseWordModel goes into the result, keyed by its id (toolName).
    // One group failing is only logged — the other groups' results are still returned.
    // Returns [toolName: FirebaseWordModel] — words missing from it aren't cached yet.
    static func fetchExisting(toolNames: [String]) async -> [String: FirebaseWordModel] {
      let ids = Array(Set(toolNames.map { documentID(for: $0) }))
      guard !ids.isEmpty else { return [:] }

      var result: [String: FirebaseWordModel] = [:]
      for start in stride(from: 0, to: ids.count, by: maxInQueryValues) {
        let chunk = Array(ids[start..<min(start + maxInQueryValues, ids.count)])
        do {
          let snapshot = try await Firestore.firestore()
            .collection("words")
            .whereField(FieldPath.documentID(), in: chunk)
            .getDocuments()
          for doc in snapshot.documents {
            if let model = try? doc.data(as: FirebaseWordModel.self) {
              result[model.id] = model
            }
          }
        } catch {
          Log.error("fetchExisting error for chunk \(start / maxInQueryValues): \(error)", .firebase)
        }
      }
      return result
    }

  // MARK: - fetchBank(profession:)
  // The word bank for one profession: every word whose `professions` list contains `profession`.
  // 1. One Firestore query (array-contains uses Firestore's automatic single-field index, nothing to set up).
  // 2. Every doc that decodes goes into the result, keyed by its id (toolName) — same shape as fetchExisting,
  //    so RequestModel can hand these docs to buildQuestions without reading them again.
  // An error is only logged and returns [:] — the game then falls back to GPT, exactly as before the bank.
  // Cost: one read per word in the bank (100–200 for a filled profession), once per game session.
  static func fetchBank(profession: String) async -> [String: FirebaseWordModel] {
    do {
      let snapshot = try await Firestore.firestore()
        .collection("words")
        .whereField("professions", arrayContains: profession)
        .getDocuments()
      var result: [String: FirebaseWordModel] = [:]
      for doc in snapshot.documents {
        if let model = try? doc.data(as: FirebaseWordModel.self) {
          result[model.id] = model
        }
      }
      Log.info("🏦 fetchBank — \(result.count) words in the bank", .firebase, private: "profession='\(profession)'")
      return result
    } catch {
      Log.error("🏦 fetchBank failed — falling back to GPT", .firebase, private: "profession='\(profession)': \(error)")
      return [:]
    }
  }
}
