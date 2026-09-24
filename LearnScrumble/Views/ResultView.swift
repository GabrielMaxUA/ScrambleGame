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

  private func percentText(_ stat: (correct: Int, total: Int)) -> String {
    guard stat.total > 0 else { return "—" }
    return "\(Int((Double(stat.correct) / Double(stat.total) * 100).rounded()))%"
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.7).ignoresSafeArea()
      VStack(spacing: 24) {
        Spacer()
        VStack(spacing: 4) {
          Text("This set").font(.headline).foregroundColor(.white.opacity(0.7))
          Text(percentText(vm.batchAccuracy())).font(.system(size: 48, weight: .bold)).foregroundColor(.white)
        }
        VStack(spacing: 4) {
          Text("Overall").font(.headline).foregroundColor(.white.opacity(0.7))
          Text(percentText(vm.overallAccuracy())).font(.title2).foregroundColor(.white)
        }
        Spacer()
        Button(action: onContinue) {
          Text("Play more!")
            .foregroundStyle(Color.white)
            .font(.title3)
            .fontWeight(.semibold)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(Color.blue)
        .clipShape(Capsule())
        Spacer()
      }
      .padding()
      .multilineTextAlignment(.center)
    }
  }
}

#Preview {
    ResultView(vm: WordVM(questions: [], targetLanguage: "uk-UA"), onContinue: {})
}
