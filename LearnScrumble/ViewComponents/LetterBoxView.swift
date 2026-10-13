//
//  LetterBoxView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI

// MARK: - Flow of this file
// One scrambled letter tile in MainView's letter rows.
//   MainView draws one per LetterModel from WordVM
//   -> tap -> short white glow + "tapScrumbled" sound -> onTap(letter) -> WordVM places it in the next empty slot.
//   A used tile shows blank and faded, and ignores taps.

struct LetterBoxView: View {
  var letter: LetterModel                                   // the tile's letter and whether it's already placed
  var size: CGFloat = 40                                    // tile width, MainView shrinks/grows it with the letter count
  @State private var color: Color = .clear                  // glow color — flashes white on tap, then fades back to clear
  let onTap:(LetterModel) -> Void                           // hands the tapped letter to WordVM
  
  var body: some View {
    Button {
      guard !letter.isUsed else { return }                  // already placed: ignore
      color = .white                                        // start the glow
      SoundManager.shared.play("tapScrumbled")
      onTap(letter)
      Task {                                                // fade the glow out after 0.1s
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation { color = .clear }
      }
    } label: {
      Text(letter.isUsed ? " " : letter.letter)             // used tile shows empty
        .font(.system(size: size * 0.5, weight: .semibold))
        .frame(width: size, height: size * 1.125)
        .overlay {
          RoundedRectangle(cornerRadius: 14)
            .stroke(lineWidth: 1)
            .shadow(color: color, radius: 10, x: 10, y: 10)   // two shadows = glow on both sides
            .shadow(color: color, radius: 10, x: -10, y: -10)
            .opacity(letter.isUsed ? 0.3 : 1)               // used tile's border fades
        }
        .contentShape(RoundedRectangle(cornerRadius: 14)) // whole box is tappable
    }
    .buttonStyle(.plain)

  }
}

#Preview {
  VStack{
    LetterBoxView(letter: LetterModel(id: 1, letter: "μ", isUsed: false)) { _ in }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.blue)
}
