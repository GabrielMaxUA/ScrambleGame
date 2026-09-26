// GuessedLetterView.swift
import SwiftUI

struct GuessedLetterView: View {
  let letter: LetterModel?
  var size: CGFloat = 30
  let onTap: (LetterModel) -> Void
  
  var body: some View {
    Button {
      if let letter { onTap(letter) }
    } label: {
      Text(letter?.letter.capitalized(with: .none) ?? "")
        .font(.system(size: size * 0.6))
        .frame(width: size, height: size * 1.5)
        .overlay(alignment: .bottom) {
          RoundedRectangle(cornerRadius: 14)
            .frame(height: 1)
        }
        .contentShape(Rectangle()) // whole slot is tappable
    }
    .buttonStyle(.plain)
    .disabled(letter == nil)
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
