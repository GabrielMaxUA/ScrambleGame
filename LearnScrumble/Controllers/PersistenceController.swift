//
//  PersistenceController.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import SwiftData
import Foundation

// MARK: - Flow of this file
// PersistenceController owns the one SwiftData ModelContainer/context for the
// whole app — everything that reads or writes SwiftDataWordModel goes through
// PersistenceController.shared, never a container built anywhere else.
//
// Called FROM WordVM (per session, scoped to that session's targetLanguage):
//   context               <- WordVM.recordGuess/batchAccuracy/overallAccuracy
//                             fetch/write records directly against this
//
// Called FROM RequestModel (before generating any batch):
//   seenToolNames(targetLanguage:)  <- "which concepts has the user already
//                                       practiced in this language" — feeds
//                                       GPT's exclusion list
//
// Called FROM AppManager (when starting a struggle-review session):
//   struggleToolNames(targetLanguage:) <- "which concepts is the user
//                                          currently struggling with in this
//                                          language" — becomes the fixed
//                                          question pool for review mode
//
// Called FROM WordVM.hasStruggleWords (live, every time ResultView renders):
//   struggleToolNames(targetLanguage:) <- same query, just checked for
//                                          emptiness to decide whether to
//                                          show the "Improve previous!" button
//
// debugPrintAllWords() is a manual dev-console dump, not called by app logic.

@Observable
final class PersistenceController {
    static let shared = PersistenceController()                      // one instance for the whole app — never construct this type directly elsewhere
    let container: ModelContainer                                    // the SwiftData store backing SwiftDataWordModel
    var context: ModelContext { container.mainContext }               // main-thread context every read/write in the app uses
    
    private init() {                                                  // private — enforces the singleton, nobody else can create a second container
        do {
            container = try ModelContainer(for: SwiftDataWordModel.self) // schema is just SwiftDataWordModel for now
            print("🟢 PersistenceController.init — ModelContainer created") // NEW
        } catch {
            fatalError("Couldn't initialize ModelContainer: \(error)") // unrecoverable — app can't run without local storage
        }
    }
    
    func debugPrintAllWords() {                                       // manual dev helper — dumps every SwiftData row to console
        let descriptor = FetchDescriptor<SwiftDataWordModel>()          // no predicate — every record, every language
        do {
            let all = try context.fetch(descriptor)
            print("📦 SwiftData word count: \(all.count)")
            for record in all {
                print("  • \(record.concept) [\(record.targetLanguage)] — correct: \(record.correct), incorrect: \(record.incorrect), lastSeen: \(record.lastSeen), struggle: \(record.isStruggle)") // NEW — added targetLanguage to the line since rows are now per-language
            }
        } catch {
            print("📦 Fetch failed: \(error)")
        }
    }
    
    func seenToolNames(targetLanguage: String) -> Set<String> {        // every concept ever practiced in this specific target language
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage } // scoped — switching target language re-opens words practiced in other languages
        )
        let records = (try? context.fetch(descriptor)) ?? []            // empty on failure — caller treats that as "nothing seen yet" rather than crashing
        let result = Set(records.map { $0.concept })
        print("🧠 seenToolNames — lang=\(targetLanguage) -> \(result.count) concepts: \(result)") // NEW
        return result
    }
    
    func struggleToolNames(targetLanguage: String, limit: Int? = nil) -> [String] {   // concepts in this target language currently below the isStruggle threshold; limit = how many to return, nil = all
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage } // same language scoping as seenToolNames — a struggle in French doesn't flag the word in Russian
        )
        let records = (try? context.fetch(descriptor)) ?? []
        let struggling = records
            .filter { $0.isStruggle }                                     // isStruggle is defined on SwiftDataWordModel
            .sorted { ($0.accuracy, $0.lastSeen) < ($1.accuracy, $1.lastSeen) }   // worst accuracy first; on a tie, the one practiced longest ago
            .map { $0.concept }
        let result = limit.map { Array(struggling.prefix($0)) } ?? struggling   // with a limit, only the weakest N
        print("🎯 struggleToolNames — lang=\(targetLanguage), limit=\(limit.map(String.init) ?? "none") -> \(result.count) struggling: \(result)")
        return result
    }
    
    func overallAccuracy(targetLanguage: String) -> (correct: Int, total: Int) { // % correct across all-time history in one target language
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage } // same language scoping as the functions above
        )
        let records = (try? context.fetch(descriptor)) ?? []            // empty on failure — caller shows "—"
        let correct = records.reduce(0) { $0 + $1.correct }             // total correct answers in this language
        let incorrect = records.reduce(0) { $0 + $1.incorrect }         // total incorrect answers in this language
        print("📈 overallAccuracy — lang=\(targetLanguage) -> \(correct)/\(correct + incorrect)")
        return (correct, correct + incorrect)
    }
    
    func resetProgress(targetLanguage: String) {                      // deletes all answers in one target language
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage }
        )
        let records = (try? context.fetch(descriptor)) ?? []
        records.forEach { context.delete($0) }
        try? context.save()
        print("🗑️ resetProgress — lang=\(targetLanguage), deleted \(records.count) records")
    }
    
    func deleteAllProgress() {                                        // deletes every answer in every language
        try? context.delete(model: SwiftDataWordModel.self)
        try? context.save()
        print("🗑️ deleteAllProgress — all records deleted")
    }
}
