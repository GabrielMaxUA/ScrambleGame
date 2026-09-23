//
//  PersistenceController.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import SwiftData

@Observable
final class PersistenceController {
  static let shared = PersistenceController()
  let container: ModelContainer
  var context: ModelContext { container.mainContext }
  private init() {
    do {
      container = try ModelContainer(for: SwiftDataWordModel.self)
    } catch {
      fatalError("Couldn't initialize ModelContainer: \(error)")
    }
  }
  
  func debugPrintAllWords() {
    let descriptor = FetchDescriptor<SwiftDataWordModel>()
    do {
      let all = try context.fetch(descriptor)
      print("📦 SwiftData word count: \(all.count)")
      for record in all {
        print("  • \(record.concept) — correct: \(record.correct), incorrect: \(record.incorrect), lastSeen: \(record.lastSeen), struggle: \(record.isStruggle)")
      }
    } catch {
      print("📦 Fetch failed: \(error)")
    }
  }
}
