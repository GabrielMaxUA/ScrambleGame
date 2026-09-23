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
  
  var body: some View {
    ZStack{
      Color.black.opacity(0.7)
        .ignoresSafeArea()
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
        .background(Color.blue)
        .clipShape(Capsule())
        Spacer()
      }//vs
      .padding()
      .multilineTextAlignment(.center)
    }//zs
  }
}

#Preview {
  ErrorView(message: "Something went wront here", onRetry: {})
}
