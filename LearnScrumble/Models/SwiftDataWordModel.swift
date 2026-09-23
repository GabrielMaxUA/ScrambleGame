


import SwiftData
import SwiftUI

@Model
final class SwiftDataWordModel {
  var concept: String
  var correct: Int
  var incorrect: Int
  var lastSeen: Date
  
  init(
    concept: String,
    correct: Int = 0,
    incorrect: Int = 0,
    lastSeen: Date = .now
  ) {
    self.concept = concept
    self.correct = correct
    self.incorrect = incorrect
    self.lastSeen = lastSeen
  }
  
  var attempts: Int {
    correct + incorrect
  }
  
  var accuracy: Double {
    guard attempts > 0 else { return 0 }
    return Double(correct) / Double(attempts)
  }
  
  var isStruggle: Bool {
    attempts >= 3 && accuracy < 0.75
  }
}
