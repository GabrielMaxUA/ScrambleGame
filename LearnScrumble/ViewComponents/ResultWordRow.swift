//
//  ResultWordRow.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

struct ResultWordRow: View {
  let result: String
  @State private var overlay: Bool = false
  let resetGuess: () -> Void
    var body: some View {
      HStack(alignment: .top){
        Spacer()
        Text(result)
          .font(.title)
          .fontWeight(.bold)
          .foregroundStyle(overlay ? .white.opacity(0.05) : .white)
          .padding(.bottom)
          .frame(height: 35)
          .minimumScaleFactor(0.8)
        Spacer()
          .overlay(alignment: .topTrailing) {
            Button {
              resetGuess()
            } label: {
              Image(systemName: "arrow.clockwise")
                .scaleEffect(0.7)
                .padding(3)
                .foregroundStyle(.white)
                .glassEffect(.clear, in: .circle)
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
