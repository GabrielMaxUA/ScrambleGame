//
//  LoadingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

struct ResultView: View {
  let vm: WordVM
  var onContinue: () -> Void
  var onRetry: () -> Void
  var exitToSettings: () -> Void
  private func percentText(_ stat: (correct: Int, total: Int)) -> String {
    guard stat.total > 0 else { return "—" }
    return "\(Int((Double(stat.correct) / Double(stat.total) * 100).rounded()))%"
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.7).ignoresSafeArea()
      VStack(spacing: 24) {
        if !vm.hasStruggleWords {
          Spacer()
          Text("Congratulations!")
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundColor(.white)
          Text("You have learned everything!")
            .font(.title2)
            .foregroundColor(.white.opacity(0.7))
        }
        Spacer()
        HStack(alignment: .top){
          Spacer()
          VStack(spacing: 4) {
            Text("This set")
              .font(.title3)
              .fontWeight(.semibold)
              .foregroundColor(.white.opacity(0.7))
            Text(percentText(vm.batchAccuracy()))
              .font(.system(size: 44))
              .foregroundColor(.white)
          }
          Spacer()
          VStack(spacing: 4) {
            Text("Overall")
              .font(.title3)
              .fontWeight(.semibold)
              .foregroundColor(.white.opacity(0.7))
            Text(percentText(vm.overallAccuracy()))
              .font(.system(size: 44))
              .foregroundColor(.white)
          }
          Spacer()
        }//hs scores
        .padding(.horizontal, 20)
        Spacer()
        VStack(spacing: 20){
          HStack{
            Button(action: onContinue) {
              Text(vm.isFinished ? "Play again!" : "Learn more words!")
                .foregroundStyle(Color.white)
                .font(.title3)
                .fontWeight(.semibold)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .glassEffect(.clear, in: .capsule)
            Button(action: exitToSettings) {
              Text("Exit")
                .foregroundStyle(Color.white)
                .font(.title3)
                .fontWeight(.semibold)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .glassEffect(.clear, in: .capsule)
          }
          if vm.hasStruggleWords {
            Button(action: onRetry) {
              Text("Improve previous!")
                .foregroundStyle(Color.white)
                .font(.title3)
                .fontWeight(.semibold)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .glassEffect(.clear, in: .capsule)
          }
        }//vs buttons
        Spacer()
      }
      .padding()
      .multilineTextAlignment(.center)
    }
  }
}

#Preview {
  ResultView(vm: WordVM(questions: [], targetLanguage: "uk-UA"), onContinue: {}, onRetry: {}, exitToSettings: {})
}
