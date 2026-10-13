//
//  ErrorView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

// MARK: - Flow of this file
// Shows a GenerationError and only the action that can actually help:
//   .retry            -> "Retry!"            (temporary problem)
//   .changeProfession -> "Change profession" (no new words for this one — opens Settings)
//   .none             -> "Back to start"     (our side is broken, or nothing to review — no false Retry)
//   RootView shows it for phase .failed(error), set by AppManager.showFailure()
//   -> the button calls onRetry (AppManager.retry), onChangeProfession (openSettings) or onExit (exitToWelcome)
//   -> on appear, a hard-hat spider drops down on a thread and strolls on top of the button.
struct ErrorView: View {
  let error: GenerationError                       // what went wrong — decides message and button
  let direction: Bool                              // true = left-to-right (back chevron points left)
  var onRetry: () async -> Void                    // AppManager.retry — runs the last session kind again
  var onExit: () -> Void                           // back to the welcome screen
  var onChangeProfession: () -> Void               // opens Settings to pick another profession
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var spiderLanded = false          // drives the drop down the thread
  @State private var showThread = true             // the thread fades away after landing
  @State private var spiderPace: CGFloat = 0       // side-to-side stroll on top of the button
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.opacity(0.92)
        .ignoresSafeArea()
      HStack {                                     // back button, top corner
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
        Text(error.message)                        // translated explanation from GenerationError
          .font(.title2.weight(.semibold))
          .foregroundColor(.white)
        Spacer()
        Button {                                   // the one action that can help (see primaryAction)
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
    .onAppear(perform: dropSpider)                 // start the spider animation
  }
  
  private var primaryTitle: LocalizedStringKey {   // button text for the error's recovery
    switch error.recovery {
    case .retry:            "Retry!"
    case .changeProfession: "Change profession"
    case .none:             "Back to start"
    }
  }
  
  // MARK: - primaryAction
  // What the main button does, by the error's recovery:
  //   .retry -> onRetry() (async, so wrapped in a Task), .changeProfession -> onChangeProfession(), .none -> onExit().
  private func primaryAction() {
    switch error.recovery {
    case .retry:            Task { await onRetry() }
    case .changeProfession: onChangeProfession()
    case .none:             onExit()
    }
  }
  
  // MARK: - dropSpider
  // Reduce Motion: the spider is simply sitting there — no thread, no strolling — and nothing animates.
  // Otherwise, one step after another (each starts when the previous finishes):
  //   1. lower down the thread over 1.8s, slowing as it nears the button
  //   2. the thread fades away
  //   3. step to one side, then stroll back and forth forever
  private func dropSpider() {
    guard !reduceMotion else {
      spiderLanded = true
      showThread = false
      return
    }
    withAnimation(.easeOut(duration: 1.8).delay(0.3)) {
      spiderLanded = true
    } completion: {
      withAnimation(.easeOut(duration: 0.6)) {
        showThread = false
      } completion: {
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
