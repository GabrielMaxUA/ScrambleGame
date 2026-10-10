//
//  LoadingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

struct LoadingView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var progress: Double                          // 0...1, passed in from RequestModel.progress
  private let groundRadius: CGFloat = 50        // the ring the cat and mouse run on
  private let lapDuration: Double = 8           // seconds for one full lap
  private let catSize: CGFloat = 62
  private let mouseSize: CGFloat = 36

  var body: some View {
    ZStack {
      Color.black.opacity(0.7)
        .ignoresSafeArea()

      // Reduce Motion: paused — one still frame. Otherwise capped at 30fps to spare the battery.
      TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
        let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
        let lap = t.truncatingRemainder(dividingBy: lapDuration) / lapDuration
        let catAngle = -Double.pi / 2 + lap * 2 * .pi                  // starts at the top, rolls clockwise
        let lead = reduceMotion ? 0.95 : 0.85 + 0.3 * sin(t * 0.9)      // the mouse dashes away whenever the cat closes in
        let mouseAngle = catAngle + lead

        ZStack {
          Circle()
            .fill(.black)
            .stroke(.gray.opacity(0.95), lineWidth: 1)
            .frame(width: groundRadius * 2, height: groundRadius * 2)
            .overlay {
              Circle()
                .trim(from: 0, to: progress)                           // only draw the finished share of the ring
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))                         // start at the top, same as the chase
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: progress)
            }

          Text(progress, format: .percent.precision(.fractionLength(0))) // "40 %" style follows the app's locale
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(reduceMotion ? .identity : .numericText(value: progress))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: progress)

          onRing(RunningMouse(t: t, size: mouseSize), angle: mouseAngle,
                 distance: groundRadius + mouseSize * 0.5)
          onRing(WheelCat(t: t, size: catSize), angle: catAngle,
                 distance: groundRadius + catSize * 0.44)              // wheels sit right on the ring
        }
      }
      .frame(width: 240, height: 240)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Loading")
      .accessibilityValue("\(Int(progress * 100)) percent")
    }
  }

  /// Stands a character on the outside of the ring: feet toward the ring, facing the way it's running.
  /// Both drawings face left, so they're mirrored to run clockwise.
  private func onRing(_ character: some View, angle: Double, distance: CGFloat) -> some View {
    character
      .scaleEffect(x: -1, y: 1)
      .rotationEffect(.radians(angle + .pi / 2))
      .offset(x: cos(angle) * distance, y: sin(angle) * distance)
      .environment(\.layoutDirection, .leftToRight)
  }
}

#Preview {
    LoadingView(progress: 0.4)
}
