//
//  ErrorView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

// Shows a GenerationError and only the action that can actually help:
//   .retry            -> "Retry!"            (temporary problem)
//   .changeProfession -> "Change profession" (no new words for this one — opens Settings)
//   .none             -> "Back to start"     (our side is broken, or nothing to review — no false Retry)
struct ErrorView: View {
  let error: GenerationError
  let direction: Bool
  var onRetry: () async -> Void
  var onExit: () -> Void
  var onChangeProfession: () -> Void
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var spiderLanded = false          // drives the drop down the thread
  @State private var showThread = true             // the thread fades away after landing
  @State private var spiderPace: CGFloat = 0       // side-to-side stroll on top of the button
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.opacity(0.92)
        .ignoresSafeArea()
      HStack {
        Button {
          onExit()
        } label: {
          Image(systemName: direction ? "chevron.left" : "chevron.right")
            .frame(width: 50, height: 50)
            .foregroundStyle(.white)
        }
        .glassCompat(in: .circle)
        Spacer()
      }
      .padding(.horizontal)
      VStack {
        Spacer()
        Text(error.message)
          .font(.title2.weight(.semibold))
          .foregroundColor(.white)
        Spacer()
        Button {
          primaryAction()
        } label: {
          Text(primaryTitle)
            .foregroundStyle(Color.white)
            .font(.title3)
            .fontWeight(.semibold)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .glassCompat(in : .capsule)
        .overlay(alignment: .top) {
          HardHatSpider(width: 76, threadLength: showThread ? 1200 : 0)   // wider than LineSpider's 56 — the new one is flatter
            .alignmentGuide(.top) { $0[.bottom] - 2 }   // feet rest on top of the button
            .offset(x: spiderPace, y: spiderLanded ? 0 : -900)   // starts far above the screen
            .allowsHitTesting(false)                    // never blocks the Retry tap
        }
        Spacer()
      }//vs
      .padding()
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
    }//zs
    .onAppear(perform: dropSpider)
  }
  
  private var primaryTitle: LocalizedStringKey {
    switch error.recovery {
    case .retry:            "Retry!"
    case .changeProfession: "Change profession"
    case .none:             "Back to start"
    }
  }
  
  private func primaryAction() {
    switch error.recovery {
    case .retry:            Task { await onRetry() }
    case .changeProfession: onChangeProfession()
    case .none:             onExit()
    }
  }
  
  private func dropSpider() {
    guard !reduceMotion else {                      // Reduce Motion: spider is simply sitting there, no thread, no strolling
      spiderLanded = true
      showThread = false
      return
    }
    // 1. lower down the thread, slowing as it nears the button
    withAnimation(.easeOut(duration: 1.8).delay(0.3)) {
      spiderLanded = true
    } completion: {
      // 2. the thread fades away
      withAnimation(.easeOut(duration: 0.6)) {
        showThread = false
      } completion: {
        // 3. step to one side, then stroll back and forth forever
        withAnimation(.easeInOut(duration: 0.9)) {
          spiderPace = -14
        } completion: {
          withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            spiderPace = 14
          }
        }
      }
    }
  }
}

#Preview("Our problem — no retry") {
  ErrorView(error: .serviceUnavailable, direction: true, onRetry: {}, onExit: {}, onChangeProfession: {})
}

#Preview("Temporary — retry") {
  ErrorView(error: .serverBusy, direction: true, onRetry: {}, onExit: {}, onChangeProfession: {})
}

#Preview("No words — change profession") {
  ErrorView(error: .noWordsAvailable, direction: true, onRetry: {}, onExit: {}, onChangeProfession: {})
}
