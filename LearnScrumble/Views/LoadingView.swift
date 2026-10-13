//
//  LoadingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

// MARK: - Flow of this file
// The loading screen: a cat chasing a mouse around a ring that fills with the loading progress.
//
// Smooth progress:
// RequestModel.progress only moves in big steps (0 -> 20% word list -> +16% per finished image),
// and one image can take 10–30s. So the number shown here is not `progress` itself:
//   - when `progress` changes, the shown value eases from where it was to the new value (catch-up)
//   - while waiting, it keeps creeping toward a ceiling a bit above `progress`, slowing down as it
//     gets closer, so the screen never looks stuck but never runs far ahead of real progress
//   - it never goes backwards, except when a new load starts (progress drops back to 0)
// Reduce Motion: no creep, the real `progress` is shown as is.
//   RootView (phase .generating) and MainView (next word not ready) pass RequestModel.progress
//   -> TimelineView redraws up to 30 times a second: the cat chases the mouse around the ring
//   -> each frame: shownProgress() -> ring fill + percent text.

struct LoadingView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var progress: Double                          // 0...1, passed in from RequestModel.progress
  private let groundRadius: CGFloat = 50        // the ring the cat and mouse run on
  private let lapDuration: Double = 8           // seconds for one full lap
  private let catSize: CGFloat = 62            // cat drawing size
  private let mouseSize: CGFloat = 36          // mouse drawing size
  private let catchUpDuration: Double = 0.6     // seconds to glide to a new real progress value
  private let creepRoom: Double = 0.12          // how far past the real progress the creep may go (one image step is 0.16)
  private let creepPace: Double = 6             // seconds — after 6s the creep has covered ~63% of its room, after 12s ~86%

  @State private var stepFrom: Double           // shown value at the moment progress last changed — the catch-up starts here
  @State private var stepStart = Date()         // when progress last changed — catch-up and creep are timed from here

  // MARK: - init
  // Starts the shown value at the real progress, so the view appears at it — no glide from 0.
  init(progress: Double) {
    self.progress = progress
    _stepFrom = State(initialValue: progress)
  }

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
        let shown = reduceMotion ? progress : shownProgress(for: progress, at: timeline.date)   // smooth value for this frame — ring and number both use it

        ZStack {
          Circle()
            .fill(.black)
            .stroke(.gray.opacity(0.95), lineWidth: 1)
            .frame(width: groundRadius * 2, height: groundRadius * 2)
            .overlay {
              Circle()
                .trim(from: 0, to: shown)                              // only draw the finished share of the ring
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))                         // start at the top, same as the chase
            }

          Text(shown, format: .percent.precision(.fractionLength(0)))  // "40 %" style follows the app's locale
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)

          onRing(RunningMouse(t: t, size: mouseSize), angle: mouseAngle,
                 distance: groundRadius + mouseSize * 0.5)
          onRing(WheelCat(t: t, size: catSize), angle: catAngle,
                 distance: groundRadius + catSize * 0.44)              // wheels sit right on the ring
        }
      }
      .frame(width: 240, height: 240)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Loading")
      .accessibilityValue("\(Int(progress * 100)) percent")            // VoiceOver reads the real progress, not the creep
      .onChange(of: progress) { old, new in                            // RequestModel reached a new step (or a new load started)
        let now = Date()
        stepFrom = new < old ? new : shownProgress(for: old, at: now)  // dropped = new load: start over; otherwise glide on from what's on screen
        stepStart = now
      }
    }
  }

  // MARK: - shownProgress(for:at:)
  // The value on screen at `date`: glide from `stepFrom` to the real progress, plus a slow creep beyond it.
  // 1. elapsed = seconds since progress last changed.
  // 2. target = the real progress — but never lower than stepFrom, so it never goes backwards
  //    if the creep already passed the new step.
  // 3. Catch-up: over catchUpDuration (0.6s) glide from stepFrom to target — fast start, soft landing.
  // 4. Creep: room = up to creepRoom (0.12) past the target; nothing at 100%, and near the end it stays under 100%.
  //    It grows fast at first, then slows down and never quite reaches `room` (creepPace sets how fast).
  // 5. Catch-up + creep, never above 1.
  private func shownProgress(for real: Double, at date: Date) -> Double {
    let elapsed = max(0, date.timeIntervalSince(stepStart))
    let target = max(real, stepFrom)
    let glide = min(1, elapsed / catchUpDuration)
    let eased = 1 - pow(1 - glide, 3)
    let base = stepFrom + (target - stepFrom) * eased
    let room = target >= 1 ? 0 : min(creepRoom, (1 - target) * 0.9)
    let creep = room * (1 - exp(-elapsed / creepPace))
    return min(base + creep, 1)
  }

  // MARK: - onRing(_:angle:distance:)
  // Stands a character on the outside of the ring: feet toward the ring, facing the way it's running.
  // Both drawings face left, so they're mirrored to run clockwise; rotated so its feet point at the center,
  // moved out to `distance` along `angle`, and always drawn left-to-right (even in RTL languages).
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
