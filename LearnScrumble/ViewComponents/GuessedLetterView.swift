// GuessedLetterView.swift
import SwiftUI

struct GuessedLetterView: View {
  let letter: LetterModel?
  var size: CGFloat = 30
  let onTap: (LetterModel) -> Void
  
  var body: some View {
    Text(letter?.letter ?? "")
      .font(.system(size: size * 0.6))
      .foregroundColor(.white)
      .frame(width: size, height: size * 1.5)
      .onTapGesture { if let letter { onTap(letter) } }
      .overlay(alignment: .bottom) {
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.white)
          .frame(height: 1)
      }
  }
}

#Preview {
  VStack {
    GuessedLetterView(letter: LetterModel(id: 1, letter: "μ", isUsed: false)) { _ in }
    GuessedLetterView(letter: nil) { _ in }   // empty slot, for comparison
  }
  .frame(width: 100, height: 310)
  .background(Color.blue)
}
