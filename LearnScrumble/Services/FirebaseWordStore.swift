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
  // Firestore document IDs can't contain "/" (it separates path levels), so "a/c unit" -> "a-c unit".
  // Only "/" changes, so every ID already saved stays exactly the same.
  private static func documentID(for toolName: String) -> String {
    toolName.replacingOccurrences(of: "/", with: "-")
  }
  private static let maxInQueryValues = 30
  static func saveIfNeeded(                                          // create-or-fill: the single entry point buildQuestions actually uses
    toolName: String,
    originLanguage: Languages,
    originWord: String,
    targetLanguage: Languages,
    targetWord: String,
    imageURL: String
  ) async {
    let docRef = Firestore.firestore().collection("words").document(documentID(for: toolName)) // one doc per toolName — this word's canonical Firebase record
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
  
    static func fetchExisting(toolNames: [String]) async -> [String: FirebaseWordModel] {
      let ids = Array(Set(toolNames.map { documentID(for: $0) }))        // no duplicates
      guard !ids.isEmpty else { return [:] }

      var result: [String: FirebaseWordModel] = [:]
      for start in stride(from: 0, to: ids.count, by: maxInQueryValues) { // one query per group of 30
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
          print("fetchExisting error for chunk \(start / maxInQueryValues): \(error)")  // one group failing doesn't lose the others
        }
      }
      return result
    }
  
}
