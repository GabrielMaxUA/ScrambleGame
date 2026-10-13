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

struct ResultWordRow: View {
  let result: String                       // text shown in the middle
  @State private var overlay: Bool = false // true would fade the text almost invisible (currently never switched on)
  let resetGuess: () -> Void               // MainView's action: send every placed letter back
    var body: some View {
      HStack(alignment: .top){
        Spacer()
        Text(result)
          .font(.title)
          .fontWeight(.bold)
          .foregroundStyle(overlay ? .white.opacity(0.05) : .white)
          .padding(.bottom)
          .frame(height: 35)
          .minimumScaleFactor(0.8)         // long words shrink a little instead of being cut
        Spacer()
          .overlay(alignment: .topTrailing) {   // reset button pinned to the right edge
            Button {
              resetGuess()
            } label: {
              Image(systemName: "arrow.clockwise")
                .scaleEffect(0.7)
                .padding(3)
                .foregroundStyle(.white)
                .glassCompat(in: .circle)
            }
            .padding(.trailing)
          }
      }//hs reset
    }
}

#Preview {
  VStack{
    ResultWordRow(result: "Word", resetGuess: {})
  }
  .background(.green)
}
