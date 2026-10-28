//
//  JobProgress.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import Foundation

// MARK: - Flow of this file
// The user's numbers for one job in one target language.
//   PersistenceController.jobProgress() adds them up from the saved words
//   -> JobProgressCard shows them on WelcomeBackView and ResultView.

struct JobProgress {
  let learned: Int        // words right at least twice and at least 75% of the time (SwiftDataWordModel.isLearned)
  let played: Int         // words of this job answered at least once — the length of "My words"
  let correct: Int        // all right answers for these words
  let incorrect: Int      // all wrong answers for these words
}
