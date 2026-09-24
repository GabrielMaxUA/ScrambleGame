//
//  FirebaseWordStore.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import FirebaseFirestore

enum FirebaseWordStore {
  
  static func saveIfNeeded(
    toolName: String,
    originLanguage: Languages,
    originWord: String,
    targetLanguage: Languages,
    targetWord: String,
    imageURL: String
  ) async {
    let docRef = Firestore.firestore().collection("words").document(toolName)
    
    do {
      let snapshot = try await docRef.getDocument()
      
      //checking on word if its in the base. if not else would write it
      guard snapshot.exists, var existing = try? snapshot.data(as: FirebaseWordModel.self) else {
        // Case 1: word doesn't exist yet — create it
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
        return
      }
      //if word is in the base we check if it has users translation laready or not so as image
      let hasOrigin = existing.translation[originLanguage.rawValue] != nil
      let hasTarget = existing.translation[targetLanguage.rawValue] != nil
      let hasImage = !existing.image.isEmpty
      if hasOrigin && hasTarget {
        // Case 2: both translations already there — nothing to do
        return
      }
      
      // Case 3: word exists, but missing one or both translations — adding up 
      if !hasOrigin { existing.translation[originLanguage.rawValue] = originWord }
      if !hasTarget { existing.translation[targetLanguage.rawValue] = targetWord }
      if !hasImage && !imageURL.isEmpty { existing.image = imageURL }
      try docRef.setData(from: existing, merge: true)
      
    } catch {
      print("FirebaseWordStore error for \(toolName): \(error)")
    }
  }
  
  static func fetchExisting(toolNames: [String]) async -> [String: FirebaseWordModel] {
    guard !toolNames.isEmpty else { return [:] }
    
    do {
      let snapshot = try await Firestore.firestore()
        .collection("words")
        .whereField(FieldPath.documentID(), in: toolNames)
        .getDocuments()
      
      var result: [String: FirebaseWordModel] = [:]
      for doc in snapshot.documents {
        if let model = try? doc.data(as: FirebaseWordModel.self) {
          result[model.id] = model
        }
      }
      return result
    } catch {
      print("fetchExisting error: \(error)")
      return [:]
    }
  }
  
  static func createWord(
    toolName: String,
    originLanguage: Languages,
    originWord: String,
    targetLanguage: Languages,
    targetWord: String,
    imageURL: String
  ) async {
    let newWord = FirebaseWordModel(
      id: toolName,
      word: toolName,
      translation: [
        originLanguage.rawValue: originWord,
        targetLanguage.rawValue: targetWord
      ],
      image: imageURL
    )
    do {
      try Firestore.firestore().collection("words").document(toolName).setData(from: newWord)
    } catch {
      print("createWord error for \(toolName): \(error)")
    }
  }
  
  static func addMissingTranslations(
    toolName: String,
    originLanguage: Languages,
    originWord: String,
    targetLanguage: Languages,
    targetWord: String,
    missingOrigin: Bool,
    missingTarget: Bool
  ) async {
    var updates: [String: Any] = [:]
    if missingOrigin { updates["translation.\(originLanguage.rawValue)"] = originWord }
    if missingTarget { updates["translation.\(targetLanguage.rawValue)"] = targetWord }
    guard !updates.isEmpty else { return }
    
    do {
      try await Firestore.firestore().collection("words").document(toolName)
        .setData(updates, merge: true)
    } catch {
      print("addMissingTranslations error for \(toolName): \(error)")
    }
  }
  
}
