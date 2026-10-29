//
//  JobProgressCard.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import SwiftUI

// MARK: - Flow of this file
// The progress card for the current job: the streak, words learned, all right and all wrong answers.
//   WelcomeBackView and ResultView pass PersistenceController.jobProgress() and Streak.shared.current.
//   No "of 100": the job's word bank keeps growing, so there's no fixed goal to show.

struct JobProgressCard: View {
  let job: Occupation?                                   // the job's name in the header (nil: no header name)
  let progress: JobProgress                              // learned / right / wrong for this job and language
  let streak: Int                                        // days in a row; the flame only shows from 1 day up

  var body: some View {
    VStack(spacing: 14) {
      HStack {
        if let job {
          Label { Text(job.displayName) } icon: { Image(systemName: "briefcase") }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
            .singleLine()
        }
        Spacer(minLength: 8)
        if streak > 0 {
          Label { Text(streak, format: .number) } icon: { Image(systemName: "flame.fill") }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.orange.opacity(0.15), in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Days in a row: \(streak)"))
        }
      }

      HStack(spacing: 0) {
        number(progress.learned, title: "Learned", icon: "star.fill", tint: .yellow)
        number(progress.correct, title: "Right", icon: "checkmark.circle.fill", tint: .green)
        number(progress.incorrect, title: "Wrong", icon: "xmark.circle.fill", tint: .red)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity)
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(.white.opacity(0.2), lineWidth: 1)
    }
  }

  // MARK: - number(_:title:icon:tint:)
  // One column: a coloured icon, the big number, its title. VoiceOver reads it as one element, e.g. "Learned, 42".
  private func number(_ value: Int, title: LocalizedStringKey, icon: String, tint: Color) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .foregroundStyle(tint)
      Text(value, format: .number)
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .monospacedDigit()
      Text(title)
        .font(.caption.weight(.semibold))
        .singleLine()
        .foregroundStyle(.white.opacity(0.6))
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  JobProgressCard(job: .plumber, progress: JobProgress(learned: 42, played: 57, correct: 180, incorrect: 35), streak: 5)
    .padding()
    .frame(maxHeight: .infinity)
    .background(.black)
}
