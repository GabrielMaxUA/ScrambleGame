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
// or sessions — RequestModel.buildQuestions is the only caller in the live flow.
//
// Called FROM RequestModel.buildQuestions, per batch:
//   fetchExisting(toolNames:)  <- one batched read: "which of these words do
//                                  we already have cached, and with what data?"
//   saveIfNeeded(...)          <- called once per word after buildQuestions
//                                  resolves its image, to create the doc if it's
//                                  new, or fill in whichever translation/image
//                                  slot was still missing (origin, target, or both)
//
// createWord(...) and addMissingTranslations(...) are NOT called anywhere in
// the current app — saveIfNeeded already covers both jobs (create-if-missing +
// fill-if-partial) in one function. Left in as unused/dead code for now.

enum FirebaseWordStore {
  
  static func saveIfNeeded(                                          // create-or-fill: the single entry point buildQuestions actually uses
    toolName: String,
    originLanguage: Languages,
    originWord: String,
    targetLanguage: Languages,
    targetWord: String,
    imageURL: String
  ) async {
    let docRef = Firestore.firestore().collection("words").document(toolName) // one doc per toolName — this word's canonical Firebase record
    print("🔥 saveIfNeeded — checking '\(toolName)' (origin=\(originLanguage.rawValue), target=\(targetLanguage.rawValue))") // NEW
    
    do {
      let snapshot = try await docRef.getDocument()                    // read the current state of this word's doc, if any
      
      //checking on word if its in the base. if not else would write it
      guard snapshot.exists, var existing = try? snapshot.data(as: FirebaseWordModel.self) else { // doc doesn't exist yet, or failed to decode
        // Case 1: word doesn't exist yet — create it
        let newWord = FirebaseWordModel(                               // build a brand-new doc with just the two languages we currently have
          id: toolName,
          word: toolName,
          translation: [
            originLanguage.rawValue: originWord,
            targetLanguage.rawValue: targetWord
          ],
          image: imageURL
        )
        try docRef.setData(from: newWord)                              // write it as a new document
        print("🆕 saveIfNeeded — '\(toolName)' did not exist, created new doc with [\(originLanguage.rawValue), \(targetLanguage.rawValue)]") // NEW
        return
      }
      //if word is in the base we check if it has users translation laready or not so as image
      let hasOrigin = existing.translation[originLanguage.rawValue] != nil // does the doc already have this origin language's translation?
      let hasTarget = existing.translation[targetLanguage.rawValue] != nil // does the doc already have this target language's translation?
      let hasImage = !existing.image.isEmpty                            // does the doc already have an image URL?
      if hasOrigin && hasTarget {                                       // both languages already present — nothing new to add
        // Case 2: both translations already there — nothing to do
        print("✅ saveIfNeeded — '\(toolName)' already has both [\(originLanguage.rawValue), \(targetLanguage.rawValue)], no write needed") // NEW
        return
      }
      
      // Case 3: word exists, but missing one or both translations — adding up
      if !hasOrigin { existing.translation[originLanguage.rawValue] = originWord } // fill the origin slot only if it was actually missing
      if !hasTarget { existing.translation[targetLanguage.rawValue] = targetWord } // fill the target slot only if it was actually missing
      if !hasImage && !imageURL.isEmpty { existing.image = imageURL }   // only overwrite image if the doc had none and we actually have one to add
      try docRef.setData(from: existing, merge: true)                  // merge the fill-ins into the existing doc, leaving everything else untouched
      print("➕ saveIfNeeded — '\(toolName)' existed, filled missing slots (origin=\(!hasOrigin), target=\(!hasTarget), image=\(!hasImage && !imageURL.isEmpty))") // NEW
      
    } catch {
      print("FirebaseWordStore error for \(toolName): \(error)")
    }
  }
  
  static func fetchExisting(toolNames: [String]) async -> [String: FirebaseWordModel] { // one batched lookup for a whole word list at once
    guard !toolNames.isEmpty else { return [:] }                        // nothing to look up — avoid an empty/invalid Firestore query
    
    do {
      let snapshot = try await Firestore.firestore()                    // single query for all requested toolNames at once, not one-by-one
        .collection("words")
        .whereField(FieldPath.documentID(), in: toolNames)
        .getDocuments()
      
      var result: [String: FirebaseWordModel] = [:]                     // toolName -> decoded doc, for whichever ones actually exist
      for doc in snapshot.documents {
        if let model = try? doc.data(as: FirebaseWordModel.self) {      // skip any doc that fails to decode rather than failing the whole batch
          result[model.id] = model
        }
      }
      print("🔥 fetchExisting — asked for \(toolNames.count), found \(result.count) cached: \(result.keys.sorted())") // NEW
      return result
    } catch {
      print("fetchExisting error: \(error)")
      return [:]                                                        // on failure, act as if nothing was cached — caller will regenerate everything
    }
  }
  
}
