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
    Group{
      Text(letter.isUsed ? " " : letter.letter)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 40, height: 45)
        .overlay{
          RoundedRectangle(cornerRadius: 14)
            .stroke(lineWidth: 1)
            .fill(.white)
            .frame(width: 40, height: 45)
            .shadow(color: color, radius: 10, x: 10, y: 10)
            .shadow(color: color, radius: 10, x: -10, y: -10)
            .opacity(letter.isUsed ? 0.3 : 1)
            
        }
    }
    .onTapGesture {
      guard !letter.isUsed else { return }
      color = .white
      onTap(letter)
      Task {
        try await Task.sleep(for: .seconds(0.1))
        withAnimation {
          color = .clear
        }
      }
    }
  }
}

#Preview {
  VStack{
    LetterBoxView(letter: LetterModel(id: 1, letter: "μ", isUsed: false)) { _ in }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.blue)
}
