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
// Every query is scoped to one target language: progress in French never affects Russian.
//
//   container                          <- LearnScrumbleApp attaches it to the window (for @Query in RootView)
//   context                            <- WordVM reads/writes answer records directly through it
//   seenToolNames(targetLanguage:)     <- RequestModel.generate / generateMore: "which concepts has the user
//                                         already practiced in this language" — sent to getWords as `exclude`
//   jobWords(profession:targetLanguage:) <- MyWordsView's list and AppManager.startReview: every saved word of the job,
//                                         weakest first
//   jobProgress(profession:targetLanguage:) <- WelcomeBackView / ResultView: learned words, right and wrong answers
//   overallAccuracy(targetLanguage:)   <- WordVM.overallAccuracy (ResultView) and WelcomeBackView's stats
//   resetProgress(targetLanguage:)     <- SettingsView "reset progress" for the current target language
//   deleteAllProgress()                <- not called right now (AppManager's deleteAllData is commented out)
//   debugPrintAllWords()               <- manual dev-console dump, not called by app logic

@Observable
final class PersistenceController {
    static let shared = PersistenceController()                      // one instance for the whole app — never construct this type directly elsewhere
    let container: ModelContainer                                    // the SwiftData store backing SwiftDataWordModel
    var context: ModelContext { container.mainContext }               // main-thread context every read/write in the app uses
    
    // MARK: - init
    // Private — enforces the singleton, nobody else can create a second container.
    // Creates the store; its schema is just SwiftDataWordModel for now.
    // If the store can't be created the app stops (fatalError): it can't run without local storage.
    private init() {
        do {
            container = try ModelContainer(for: SwiftDataWordModel.self)
            Log.info("🟢 PersistenceController.init — ModelContainer created", .storage)
        } catch {
            fatalError("Couldn't initialize ModelContainer: \(error)")
        }
    }
    
    // MARK: - debugPrintAllWords
    // Manual dev helper — dumps every SwiftData row to the console.
    // No predicate: every record, every language (the language is printed on each line, since rows are per-language).
    func debugPrintAllWords() {
        let descriptor = FetchDescriptor<SwiftDataWordModel>()
        do {
            let all = try context.fetch(descriptor)
            Log.debug("📦 SwiftData word count: \(all.count)", .storage)
            for record in all {
                Log.debug("  • \(record.concept) [\(record.targetLanguage)] — correct: \(record.correct), incorrect: \(record.incorrect), lastSeen: \(record.lastSeen), learned: \(record.isLearned), job: \(record.profession)", .storage)
            }
        } catch {
            Log.error("📦 Fetch failed: \(error)", .storage)
        }
    }
    
    // MARK: - seenToolNames(targetLanguage:)
    // Every concept ever practiced in this specific target language.
    // Scoped — switching target language re-opens words practiced in other languages.
    // A failed fetch returns an empty set: the caller treats that as "nothing seen yet" rather than crashing.
    func seenToolNames(targetLanguage: String) -> Set<String> {
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage }
        )
        let records = (try? context.fetch(descriptor)) ?? []
        let result = Set(records.map { $0.concept })
        Log.debug("🧠 seenToolNames — lang=\(targetLanguage) -> \(result.count) concepts: \(result)", .storage)
        return result
    }
    
    // MARK: - jobWords(profession:targetLanguage:)
    // Every word saved for this job in this target language (records with the whole word only, see hasWord).
    // Order: worst accuracy first; on a tie, the one practiced longest ago — the review starts with what needs it most.
    func jobWords(profession: String, targetLanguage: String) -> [SwiftDataWordModel] {
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage && $0.profession == profession && $0.targetWord != "" }
        )
        let records = ((try? context.fetch(descriptor)) ?? [])
            .sorted { ($0.accuracy, $0.lastSeen) < ($1.accuracy, $1.lastSeen) }
        Log.debug("📚 jobWords — lang=\(targetLanguage) -> \(records.count) words", .storage)
        return records
    }

    // MARK: - jobProgress(profession:targetLanguage:)
    // How far the user is with one job in one language: words learned (isLearned), words played,
    // and all right / wrong answers. No fixed goal — the job's word bank keeps growing.
    func jobProgress(profession: String, targetLanguage: String) -> JobProgress {
        let records = jobWords(profession: profession, targetLanguage: targetLanguage)
        return JobProgress(learned: records.filter(\.isLearned).count,
                           played: records.count,
                           correct: records.reduce(0) { $0 + $1.correct },
                           incorrect: records.reduce(0) { $0 + $1.incorrect })
    }
    
    // MARK: - overallAccuracy(targetLanguage:)
    // Correct answers vs all answers across the whole history in one target language.
    // Adds up `correct` and `incorrect` of every record; returns (correct, total).
    // A failed fetch gives (0, 0) — the caller shows "—".
    func overallAccuracy(targetLanguage: String) -> (correct: Int, total: Int) {
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage }
        )
        let records = (try? context.fetch(descriptor)) ?? []
        let correct = records.reduce(0) { $0 + $1.correct }
        let incorrect = records.reduce(0) { $0 + $1.incorrect }
        Log.debug("📈 overallAccuracy — lang=\(targetLanguage) -> \(correct)/\(correct + incorrect)", .storage)
        return (correct, correct + incorrect)
    }
    
    // MARK: - resetProgress(targetLanguage:)
    // Deletes all answers in one target language: fetch that language's records -> delete each -> save.
    // Those words count as unseen again, so the server (bank or GPT) may offer them again.
    func resetProgress(targetLanguage: String) {
        let descriptor = FetchDescriptor<SwiftDataWordModel>(
            predicate: #Predicate { $0.targetLanguage == targetLanguage }
        )
        let records = (try? context.fetch(descriptor)) ?? []
        records.forEach { context.delete($0) }
        try? context.save()
        Log.info("🗑️ resetProgress — lang=\(targetLanguage), deleted \(records.count) records", .storage)
    }
    
    // MARK: - deleteAllProgress
    // Deletes every answer in every language, then saves.
    func deleteAllProgress() {
        try? context.delete(model: SwiftDataWordModel.self)
        try? context.save()
        Log.info("🗑️ deleteAllProgress — all records deleted", .storage)
    }
}
