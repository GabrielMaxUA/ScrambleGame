//
//  AnswerResultView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

struct AnswerResultView: View {
  let result: GuessResult
  let correctAnswer: String
  let onNext: () -> Void
  
  private var isCorrect: Bool { result == .correct }
  
  var body: some View {
    VStack(spacing: 24) {
      Spacer(minLength: 72)                                    // room for RootView's top button row
      
      AnimalStage(isCorrect: isCorrect)
      
      VStack(spacing: 14) {
        Text(isCorrect ? "Correct!" : "Incorrect")
          .font(.largeTitle.bold())
          .foregroundStyle(isCorrect ? .green : .red)
        
        if !isCorrect {
          Text("Correct answer was: \(correctAnswer)")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
              RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.2), lineWidth: 1)
            }
        }
      }
      .multilineTextAlignment(.center)
      
      Spacer()
      
      Button(action: onNext) {
        Text("Next")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .glassEffect(.clear.interactive(), in: .capsule)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.92))
  }
}

/// The checkmark or X in the middle, with the cat, dog, mouse and spider around it.
/// Correct: they dance. Incorrect: they droop for a moment, then sadly walk off the screen.
private struct AnimalStage: View {
  let isCorrect: Bool
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var bounce = false
  @State private var leaving = false                   // turned around and walking (switches poses instantly)
  @State private var away = false                      // drives the slide off the screen (animated)
  
  private let distance: CGFloat = 320                  // far enough to leave any iPhone screen
  
  var body: some View {
    ZStack {
      Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.system(size: 88))
        .symbolRenderingMode(.palette)
        .foregroundStyle(.white, isCorrect ? .green : .red)
        .symbolEffect(.bounce, value: bounce)
        .onAppear { bounce.toggle() }
      
      TimelineView(.animation(paused: reduceMotion)) { timeline in
        let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100)
        
        ZStack {
          // spider — yo-yos when happy; when sad, climbs back up its thread and out of sight
          LineSpider(width: 44, isWiggling: isCorrect || leaving, threadLength: 70)
            .offset(y: (isCorrect ? -118 + sin(t * 4) * 8 : -104 + sin(t * 1.2) * 1.5)
                    - (away ? distance + 120 : 0))
            .opacity(isCorrect ? 1 : 0.7)
          
          // cat on the left — dances; when sad, turns around and walks off to the left
          LineCat(width: 70, isWalking: isCorrect || leaving)
            .scaleEffect(x: leaving ? -1 : 1)
            .rotationEffect(.degrees(tilt(t, phase: 0, droop: leaving ? -4 : 8)))
            .offset(x: -118 - (away ? distance : 0), y: 20 + lift(t, phase: 0))
            .opacity(isCorrect ? 1 : 0.7)
          
          // dog on the right — prances; when sad, sits without its tongue, then gets up and leaves to the right
          LineDog(pose: (isCorrect || leaving) ? .running : .sitting,
                  width: 80,
                  tongueColor: isCorrect ? .pink : .clear,
                  isAnimating: isCorrect || leaving)
          .scaleEffect(x: leaving ? 1 : -1)                 // faces the icon, then turns away
          .rotationEffect(.degrees(tilt(t, phase: 1.2, droop: leaving ? 4 : -8)))
          .offset(x: 116 + (away ? distance : 0), y: 16 + lift(t, phase: 1.2))
          .opacity(isCorrect ? 1 : 0.7)
          
          // mouse below — hops with its cheese; when sad, trudges off to the right carrying it
          LineMouse(width: 56, isEating: isCorrect)
            .rotationEffect(.degrees(tilt(t, phase: 2.4, droop: 6)))
            .offset(x: away ? distance : 0, y: 112 + lift(t, phase: 2.4) * 0.6)
            .opacity(isCorrect ? 1 : 0.7)
        }
      }
    }
    .frame(width: 320, height: 280)
    .accessibilityHidden(true)                                   // decorative — the title says correct/incorrect
    .task {
      guard !isCorrect, !reduceMotion else { return }          // Reduce Motion: they just stay, drooping
      try? await Task.sleep(for: .seconds(0.9))                // a sad moment looking at the X first
      leaving = true
      withAnimation(.easeIn(duration: 2.8)) {                  // slow start, like dragging their feet
        away = true
      }
    }
  }
  
  /// Happy: hops. Sad: sunk a little lower with a slow sigh; trudging bob while walking away.
  private func lift(_ t: Double, phase: Double) -> Double {
    if isCorrect { return -abs(sin(t * 5 + phase)) * 12 }
    if leaving { return 4 - abs(sin(t * 3 + phase)) * 3 }
    return 4 + sin(t * 1.2 + phase) * 1.2
  }
  
  /// Happy: sways to the beat. Sad: head hangs down.
  private func tilt(_ t: Double, phase: Double, droop: Double) -> Double {
    isCorrect ? sin(t * 2.5 + phase) * 10 : droop
  }
}

#Preview("Correct") {
  AnswerResultView(result: .correct, correctAnswer: "hammer", onNext: {})
}

#Preview("Incorrect") {
  AnswerResultView(result: .incorrect, correctAnswer: "hammer", onNext: {})
}
