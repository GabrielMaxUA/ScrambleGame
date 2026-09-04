//
//  LoadingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

struct LoadingView: View {
  var loadingPhrases: [String] = ["Loading...", "Fetching...", "Processing...", "Generating images...", "Translating the words...", "Compiling the images...", "Almost there..."]
    var body: some View {
      ZStack{
        Color.black.opacity(0.7)
          .ignoresSafeArea()
        VStack{
          Spacer()
          Text("Loading...")
            .font(.largeTitle)
            .foregroundColor(.white)
        }
        VStack{
          Spacer()
          ProgressView()
            .tint(.white)
            .scaleEffect(2)
          Spacer()
        }//vs
      }
    }
}

#Preview {
    LoadingView()
}
