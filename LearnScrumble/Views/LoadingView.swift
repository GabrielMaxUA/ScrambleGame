//
//  LoadingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI
public import Combine

struct LoadingView: View {
  var loadingPhrases: [String] = ["Loading", "Fetching", "Processing", "Generating images", "Translating the words", "Compiling the images", "Almost there"]
  @State private var currentIndex = 0
  let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
  
  var body: some View {
    ZStack{
      Color.black.opacity(0.7)
        .ignoresSafeArea()
      VStack {
        Spacer()
        Text(loadingPhrases[currentIndex] + "...")
          .font(.largeTitle)
          .foregroundColor(.white)
          .transition(.opacity)
          .id(currentIndex) // forces the transition to re-trigger on change
        Spacer()
        ProgressView()
          .tint(.white)
          .scaleEffect(2)
        Spacer()
      }//vs
      
    }//zs
    .onReceive(timer) { _ in
      currentIndex = (currentIndex + 1) % loadingPhrases.count
    }
  }
}

#Preview {
  LoadingView()
}
