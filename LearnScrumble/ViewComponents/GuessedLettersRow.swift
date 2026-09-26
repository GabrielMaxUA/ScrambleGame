//
//  GuessedLettersRow.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

struct GuessedLettersRow: View {
  let segment: Range<Int>          // one entry from vm.segmentRanges
  let guessedWord: [LetterModel?]
  let width: CGFloat               // geo.size.width from MainView
  let isDimmed: Bool               // vm.overlayShown
  let onDeselect: (LetterModel) -> Void // vm.deselectLetter
  
  var body: some View {
    let segIndices = Array(segment)
    let segCount = segIndices.count
    let availableWidth = width - 32 // side padding
    let letterSpacing: CGFloat = segCount > 12 ? 4 : 16
    let spacingTotal = CGFloat(max(segCount - 1, 0)) * letterSpacing
    let rawSize = (availableWidth - spacingTotal) / CGFloat(max(segCount, 1))
    let slotSize = min(30, max(rawSize, 12)) // never bigger than default, floor so it stays tappable
    
    HStack(spacing: letterSpacing) {
      ForEach(segIndices, id: \.self) { slotIndex in
        let letter = slotIndex < guessedWord.count ? guessedWord[slotIndex] : nil
        GuessedLetterView(letter: letter, size: slotSize) { onDeselect($0) }
          .foregroundStyle(isDimmed ? .white.opacity(0.05) : .white)
      }
    }
  }
}

#Preview {
  VStack{
    GuessedLettersRow(
      segment: 0..<5,
      guessedWord: [LetterModel(id: 1, letter: "n", isUsed: true), nil, nil, nil],
      width: 400,
      isDimmed: false,
      onDeselect: {_ in}
    )
  }
  .padding()
  .background(.black)
}
