

import SwiftData
import SwiftUI

// MARK: - Flow of this file
// The user's own history for one word in one target language, saved on the phone with SwiftData.
//   WordVM records every answer here (correct / incorrect, lastSeen) and, the first time, the whole word:
//   its job, both words, the picture prompt and the picture itself, so "My words" works without the server.
//   PersistenceController reads it: seen words (not asked again), the job's word list, accuracy, learned count.
//   Records saved before 28 Oct 2026 only have the counters (empty profession/targetWord): they still count as
//   seen, but don't appear in "My words" or in the job's progress.

@Model
final class SwiftDataWordModel {
    var concept: String                     // English toolName — same key as Firebase
    var correct: Int                        // times answered right
    var incorrect: Int                      // times answered wrong
    var targetLanguage: String              // language code it was practiced in, e.g. "fr-FR"
    var lastSeen: Date                      // last time it was answered
    var profession: String = ""             // the job it was learned for (Occupation rawValue, e.g. "Plumber")
    var targetWord: String = ""             // the word in the language being learned
    var originWord: String = ""             // the hint in the user's own language when it was learned
    var originLanguage: String = ""         // language code of originWord
    var imagePrompt: String = ""            // GPT's picture description, kept so a missing picture could be redrawn
    @Attribute(.externalStorage) var imageData: Data?   // the picture, stored as a file next to the database
    var imageURL: String = ""               // the picture's link in Storage — sent with a report from the review

    static let learnedMinCorrect = 2        // "learned" = right at least twice…
    static let learnedMinAccuracy = 0.75    // …and right at least 75% of the time

    // MARK: - init
    // A new record for a word answered for the first time; counters start at 0 unless given.
    init(
        concept: String,
        correct: Int = 0,
        targetLanguage: String,
        incorrect: Int = 0,
        lastSeen: Date = .now
    ) {
        self.concept = concept
        self.correct = correct
        self.targetLanguage = targetLanguage
        self.incorrect = incorrect
        self.lastSeen = lastSeen
    }

    var attempts: Int {                     // all answers for this word
        correct + incorrect
    }

    var accuracy: Double {                  // 0...1 share of right answers
        guard attempts > 0 else { return 0 }   // never answered: 0, avoids dividing by zero
        return Double(correct) / Double(attempts)
    }

    var isLearned: Bool {                   // counts toward the job's "words learned"
        correct >= Self.learnedMinCorrect && accuracy >= Self.learnedMinAccuracy
    }

    var hasWord: Bool {                     // saved with the whole word (not an old counters-only record)
        !targetWord.isEmpty && !profession.isEmpty
    }

    var image: UIImage? {                   // the stored picture, for the word list and review
        imageData.flatMap(UIImage.init(data:))
    }

    var hasPicture: Bool { imageData != nil }   // a review word needs its picture

    // MARK: - asQuestion
    // The saved word as a playable question for review — no server call, the picture is already here.
    var asQuestion: QuestionModel {
        QuestionModel(id: UUID().uuidString,
                      word: WordModel(toolName: concept, originWord: originWord, targetWord: targetWord, imagePrompt: imagePrompt),
                      imageData: imageData,
                      imageURL: imageURL.isEmpty ? nil : imageURL)
    }
}
