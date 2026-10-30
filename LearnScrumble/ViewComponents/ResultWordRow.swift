//
//  ResultWordRow.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

// MARK: - Flow of this file
// The line above the letters in MainView: shows a word/result text with a small reset button on the right.
//   MainView passes the text and resetGuess -> tap the arrow -> resetGuess() -> WordVM clears the placed letters.
//   Tutorial (OnboardingView): reports where ↻ is through TutorialAnchorKey, so the pointer can find it (ignored by the real game).

struct ResultWordRow: View {
  let result: String                       // text shown in the middle
  @State private var overlay: Bool = false // true would fade the text almost invisible (currently never switched on)
  let resetGuess: () -> Void               // MainView's action: send every placed letter back
    // The text keeps one line between two equal side columns (the right one holds ↻), so a long answer shrinks
    // instead of running under the button (30 Oct 2026: a 31-letter, three-word answer used to overlap it).
    var body: some View {
      HStack(alignment: .top, spacing: 0) {
        Color.clear
          .frame(width: buttonColumn, height: 1)  // mirrors the button column, keeps the text centred
        Text(result)
          .font(.title)
          .fontWeight(.bold)
          .foregroundStyle(overlay ? .white.opacity(0.05) : .white)
          .lineLimit(1)
          .minimumScaleFactor(0.4)         // long answers shrink to fit the line
          .frame(maxWidth: .infinity)
          .padding(.bottom)
          .frame(height: 35)
        Button {
          resetGuess()
        } label: {
          Image(systemName: "arrow.clockwise")
            .scaleEffect(0.7)
            .padding(3)
            .foregroundStyle(.white)
            .glassCompat(in: .circle)
            .anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [.reset: $0] }   // where ↻ is, for the tutorial's pointer
        }
        .frame(width: buttonColumn, alignment: .trailing)
        .padding(.trailing)
      }//hs reset
    }

    private let buttonColumn: CGFloat = 36   // room for ↻ on the right (and the same empty room on the left)
}

#Preview {
  VStack{
    ResultWordRow(result: "Word", resetGuess: {})
  }
  .background(.green)
}
