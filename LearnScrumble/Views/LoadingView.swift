//
//  LoadingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

struct LoadingView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let groundRadius: CGFloat = 50        // the ring the cat walks on
  private let lapDuration: Double = 8           // seconds for one full lap

  var body: some View {
    ZStack {
      Color.black.opacity(0.7)
        .ignoresSafeArea()

      TimelineView(.animation(paused: reduceMotion)) { timeline in
        let t = timeline.date.timeIntervalSinceReferenceDate
        let lap = reduceMotion ? 0 : t.truncatingRemainder(dividingBy: lapDuration) / lapDuration
        let angle = -Double.pi / 2 + lap * 2 * .pi                     // starts at the top, walks clockwise

        ZStack {
          Circle()
            .fill(.black)
            .stroke(.gray.opacity(0.95), lineWidth: 1)
            .frame(width: groundRadius * 2, height: groundRadius * 2)

          LineMouse(width: 34)                                            // nibbling cheese in the middle of the ring

          LineCat(width: 60)                                                       // legs animate on their own
            .rotationEffect(.radians(angle + .pi / 2))                   // feet toward the ring, head in walking direction
            .offset(x: cos(angle) * (groundRadius + 20),
                    y: sin(angle) * (groundRadius + 20))
        }
      }
      .frame(width: 240, height: 240)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Loading")
    }
  }
}

#Preview {
  LoadingView()
}
