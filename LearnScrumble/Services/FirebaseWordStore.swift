//
//  FirebaseWordStore.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import FirebaseFirestore

// MARK: - Flow of this file
// FirebaseWordStore is the Firestore layer for word documents, one doc per
// toolName under the "words" collection. It knows nothing about GPT, SwiftData,
// or sessions — RequestModel is the only caller.
//
//   fetchExisting(toolNames:)  <- RequestModel.buildQuestions (and generateStruggleReview), once per batch:
//                                 "which of these words do we already have cached, and with what data?"
//                                 -> cached image URLs are reused instead of paying for new images
//   saveIfNeeded(...)          <- RequestModel.resolveImage, once per word after its image is resolved:
//                                 creates the doc if it's new, or fills in whichever translation/image
//                                 slot was still missing (origin, target, or both)
//   documentID(for:)           <- both of the above: toolName -> safe Firestore document id

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
  // 1. Points at this word's doc — one doc per toolName, the word's canonical Firebase record — and reads it.
  // 2. Case 1 — doc doesn't exist yet (or can't be decoded): builds a brand-new doc with the two languages
  //    we have right now (origin + target) and the image URL, and writes it.
  // 3. Otherwise checks what the doc already has: origin translation? target translation? image URL?
  //    Case 2 — both translations already there: nothing new to add, no write.
  // 4. Case 3 — word exists but is missing one or both translations: fills only the missing slots,
  //    sets the image only if the doc had none and we have one, and merges that into the doc
  //    (everything else in it stays untouched).
  // Any Firestore error is only logged — a failed save never stops the game.
  static func saveIfNeeded(
    toolName: String,
    originLanguage: Languages,
    originWord: String,
    targetLanguage: Languages,
    targetWord: String,
    imageURL: String
  ) async {
    let docRef = Firestore.firestore().collection("words").document(documentID(for: toolName))
    Log.debug("🔥 saveIfNeeded — checking '\(toolName)' (origin=\(originLanguage.rawValue), target=\(targetLanguage.rawValue))", .firebase)
    
    do {
      let snapshot = try await docRef.getDocument()
      
      guard snapshot.exists, var existing = try? snapshot.data(as: FirebaseWordModel.self) else {
        let newWord = FirebaseWordModel(
          id: toolName,
          word: toolName,
          translation: [
            originLanguage.rawValue: originWord,
            targetLanguage.rawValue: targetWord
          ],
          image: imageURL
        )
        try docRef.setData(from: newWord)
        Log.info("🆕 saveIfNeeded — '\(toolName)' did not exist, created new doc with [\(originLanguage.rawValue), \(targetLanguage.rawValue)]", .firebase)
        return
      }
      let hasOrigin = existing.translation[originLanguage.rawValue] != nil
      let hasTarget = existing.translation[targetLanguage.rawValue] != nil
      let hasImage = !existing.image.isEmpty
      if hasOrigin && hasTarget {
        Log.debug("✅ saveIfNeeded — '\(toolName)' already has both [\(originLanguage.rawValue), \(targetLanguage.rawValue)], no write needed", .firebase)
        return
      }
      
      if !hasOrigin { existing.translation[originLanguage.rawValue] = originWord }
      if !hasTarget { existing.translation[targetLanguage.rawValue] = targetWord }
      if !hasImage && !imageURL.isEmpty { existing.image = imageURL }
      try docRef.setData(from: existing, merge: true)
      Log.info("➕ saveIfNeeded — '\(toolName)' existed, filled missing slots (origin=\(!hasOrigin), target=\(!hasTarget), image=\(!hasImage && !imageURL.isEmpty))", .firebase)
      
    } catch {
      Log.error("FirebaseWordStore error for \(toolName): \(error)", .firebase)
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
  
}
