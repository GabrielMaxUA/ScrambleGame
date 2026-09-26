//
//  LetterBoxView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI

struct LetterBoxView: View {
  var letter: LetterModel
  @State private var color: Color = .clear
  let onTap:(LetterModel) -> Void
  
  var body: some View {
    Button {
      guard !letter.isUsed else { return }
      color = .white
      onTap(letter)
      Task {
        try? await Task.sleep(for: .seconds(0.1))
        withAnimation { color = .clear }
      }
    } label: {
      Text(letter.isUsed ? " " : letter.letter)
        .font(.system(size: 20, weight: .semibold))
        .frame(width: 40, height: 45)
        .overlay {
          RoundedRectangle(cornerRadius: 14)
            .stroke(lineWidth: 1)
            .shadow(color: color, radius: 10, x: 10, y: 10)
            .shadow(color: color, radius: 10, x: -10, y: -10)
            .opacity(letter.isUsed ? 0.3 : 1)
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
