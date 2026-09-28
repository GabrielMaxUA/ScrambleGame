//
//  LoadingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

struct ErrorView: View {
  var message: String
  var onRetry: () async -> Void
  var onExit: () -> Void
  var body: some View {
      ZStack(alignment: .topLeading){
      Color.black.opacity(0.7)
        .ignoresSafeArea()
          HStack{
              Button {
                 onExit()
              } label: {
                  Image(systemName: "chevron.left")
                      .frame(width: 50, height: 50)
                      .foregroundStyle(.white)
              }
              .glassEffect(.clear, in: .circle)
              Spacer()
          }
          .padding(.horizontal)
      VStack {
        Spacer()
        Text(message)
          .font(.largeTitle)
          .foregroundColor(.white)
        Spacer()
              Button {
                  Task {
                      await onRetry()
                  }
              } label: {
                  Text("Retry!")
                      .foregroundStyle(Color.white)
                      .font(.title3)
                      .fontWeight(.semibold)
              }
              .padding(.vertical, 10)
              .padding(.horizontal, 20)
              .glassEffect(.clear, in: .capsule)
              Spacer()
      }//vs
      .padding()
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
    }//zs
  }
}

#Preview {
  ErrorView(message: "Something went wront here", onRetry: {}, onExit: {})
}
