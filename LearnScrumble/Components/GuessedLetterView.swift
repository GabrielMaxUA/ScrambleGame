// GuessedLetterView.swift
import SwiftUI

struct GuessedLetterView: View {
  let letter: LetterModel?
  let onTap: (LetterModel) -> Void
  
  var body: some View {
    Text(letter?.letter ?? "")
      .font(.title3)
      .foregroundColor(.white)
      .frame(width: 30, height: 45)
      .onTapGesture { if let letter { onTap(letter) } }
      .overlay(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.white)
          .frame(height: 1)
      }//lets see if this would work as intended
  }
}

#Preview {
  VStack {
    GuessedLetterView(letter: LetterModel(id: 1, letter: "W", isUsed: false)) { _ in }
    GuessedLetterView(letter: nil) { _ in }   // empty slot, for comparison
  }
  .frame(width: 100, height: 310)
  .background(Color.blue)
}
