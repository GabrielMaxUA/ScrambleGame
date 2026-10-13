// GuessedLetterView.swift
import SwiftUI

// MARK: - Flow of this file
// One answer slot under the picture: shows a placed letter, or an empty underline.
//   GuessedLettersRow draws one per letter of the target word
//   -> tap on a filled slot -> plays "tapGuessed" -> onTap(letter) -> WordVM puts the letter back into the scrambled row.

struct GuessedLetterView: View {
  let letter: LetterModel?                 // nil = empty slot
  var size: CGFloat = 30                   // slot width, GuessedLettersRow shrinks it for long words
  let onTap: (LetterModel) -> Void         // hands the tapped letter back to the row / WordVM
  
  var body: some View {
    Button {
      if let letter {                      // empty slots do nothing
        SoundManager.shared.play("tapGuessed")
        onTap(letter) }
    } label: {
      Text(letter?.letter.capitalized(with: .none) ?? "")
        .font(.system(size: size * 0.75)) // larger share of the slot so letters stay legible when slots shrink
        .frame(width: size, height: size * 1.5)
        .overlay(alignment: .bottom) {     // the underline every slot shows
          RoundedRectangle(cornerRadius: 14)
            .frame(height: 1)
        }
        .contentShape(Rectangle()) // whole slot is tappable
    }
    .buttonStyle(.plain)
    .disabled(letter == nil)               // empty slot: not tappable, not announced as a button
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
