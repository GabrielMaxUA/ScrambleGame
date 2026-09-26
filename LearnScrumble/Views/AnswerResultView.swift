//
//  AnswerResultView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

struct AnswerResultView: View {
  let result: GuessResult
  let correctAnswer: String
  let onNext: () -> Void
    var body: some View {
      VStack {
        Spacer()
        Text(result == .correct ? "Correct!" : "Incorrect")
          .font(.largeTitle)
          .fontWeight(.bold)
          .foregroundStyle(result == .correct ? .green : .red)
          .padding(.bottom)
        if result == .incorrect{
          Text("Correct answer was: \(correctAnswer)")
            .font(.title2)
            .foregroundStyle(.white.opacity(0.8))
            .padding(.bottom)
        } else {
          Spacer().frame(height: 8)
        }
        Spacer()
        Button {
          onNext()
        } label: {
          Text("Next")
            .padding()
            .foregroundStyle(.white)
            .glassEffect(.clear, in: .buttonBorder)
        }
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black.opacity(0.7))
    }
}

#Preview("Correct") {
  AnswerResultView(result: .correct, correctAnswer: "hammer", onNext: {})
}

#Preview("Incorrect") {
  AnswerResultView(result: .incorrect, correctAnswer: "hammer", onNext: {})
}
