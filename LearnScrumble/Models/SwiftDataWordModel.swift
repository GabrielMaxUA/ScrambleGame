


import SwiftData
import SwiftUI

// MARK: - Flow of this file
// The user's own history for one word in one target language, saved on the phone with SwiftData.
//   WordVM records every answer here (correct / incorrect, lastSeen)
//   PersistenceController reads it: seen words (not asked again), struggle words, accuracy
//   RootView's @Query reads it to know whether the struggle-review button should show.

@Model
final class SwiftDataWordModel {
    var concept: String                     // English toolName — same key as Firebase
    var correct: Int                        // times answered right
    var incorrect: Int                      // times answered wrong
    var targetLanguage: String              // language code it was practiced in, e.g. "fr-FR"
    var lastSeen: Date                      // last time it was answered
    
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
    
    var isStruggle: Bool {                  // goes to struggle review: missed at least once and under 75% right
      incorrect > 0 && accuracy < 0.75
    }
}
