//
//  HardHatSpider.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import SwiftUI

/// The NewSVG spider (traced from Spider.swift — same thick rounded lines and eyes) wearing the
/// construction hard hat. Drop-in replacement for LineSpider: same parameters, same behaviour —
/// legs wiggle, and an optional silk thread goes up from the top of its hat.
///
///     HardHatSpider()                                 // 56pt wide, wiggling
///     HardHatSpider(threadLength: 300)                // hanging on a thread
///     HardHatSpider(width: 90, isWiggling: false)     // bigger, standing still
///
/// Reduce Motion: legs stay at rest and the timeline is paused (no redraws).
struct HardHatSpider: View {
  var width: CGFloat = 56
  var color: Color = .white
  var hatColor: Color = .yellow
  var lineWidth: CGFloat = 2.6                     // in drawing units (the spider is traced on a 100-wide grid)
  var isWiggling: Bool = true
  var threadLength: CGFloat = 0                    // 0 = no thread
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private static let space = CGSize(width: 108, height: 58)   // hat top to feet, legs tip to tip
  private static let offset = CGPoint(x: 7, y: -35)            // traced grid -> space: centers the hat, crops empty space above it
  private static let hatTopY: CGFloat = 40 + offset.y          // where the thread attaches, in space coordinates
  
  private var scale: CGFloat { width / Self.space.width }
  
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isWiggling || reduceMotion)) { timeline in
      let moving = isWiggling && !reduceMotion
      let t = moving ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100) : 0
      
      Canvas { context, size in
        context.scaleBy(x: size.width / Self.space.width, y: size.height / Self.space.height)
        context.translateBy(x: Self.offset.x, y: Self.offset.y)
        draw(in: context, time: t, wiggle: moving ? 1 : 0)
      }
    }
    .frame(width: width, height: width * Self.space.height / Self.space.width)
    .overlay(alignment: .top) {
      if threadLength > 0 {
        Rectangle()
          .fill(color.opacity(0.6))
          .frame(width: 1, height: threadLength)
          .offset(y: -threadLength + Self.hatTopY * scale)   // thread ends exactly at the top of the hat
          .transition(.opacity)                              // fades when the thread is removed inside withAnimation
      }
    }
    .accessibilityHidden(true)                   // decorative — the parent view says what's happening
  }
  
  private func draw(in context: GraphicsContext, time: Double, wiggle: Double) {
    let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    let ink = GraphicsContext.Shading.color(color)
    
    // legs — three per side, each swinging a little around its hip (right side half a beat behind)
    let legs: [(hip: CGPoint, knee: CGPoint, foot: CGPoint, isLeft: Bool)] = [
      (CGPoint(x: 28, y: 52),   CGPoint(x: 12, y: 40), CGPoint(x: 1, y: 55),    true),
      (CGPoint(x: 25, y: 61),   CGPoint(x: 5, y: 55),  CGPoint(x: 3, y: 79),    true),
      (CGPoint(x: 26, y: 68.5), CGPoint(x: 10, y: 67), CGPoint(x: 17, y: 85.5), true),
      (CGPoint(x: 67, y: 51),   CGPoint(x: 84, y: 38), CGPoint(x: 99, y: 51),   false),
      (CGPoint(x: 68, y: 60),   CGPoint(x: 88, y: 52), CGPoint(x: 96, y: 72),   false),
      (CGPoint(x: 67.5, y: 68.5), CGPoint(x: 84, y: 66), CGPoint(x: 78, y: 89), false),
    ]
    for (i, leg) in legs.enumerated() {
      var path = Path()
      path.move(to: leg.hip)
      path.addQuadCurve(to: leg.foot, control: leg.knee)
      let phase = time * 7 + Double(i % 3) + (leg.isLeft ? 0 : .pi)
      let swing = sin(phase) * 6 * wiggle * (leg.isLeft ? 1 : -1)      // mirrored so both sides "walk"
      context.stroke(Rig.rotated(path, by: swing, around: leg.hip), with: ink, style: style)
    }
    
    // round body
    context.stroke(Path(ellipseIn: CGRect(x: 27, y: 46.2, width: 40, height: 33)), with: ink, style: style)
    
    // eyes
    var eyes = Path()
    eyes.move(to: CGPoint(x: 34, y: 55.5))
    eyes.addLine(to: CGPoint(x: 41, y: 64))
    eyes.addQuadCurve(to: CGPoint(x: 37, y: 54), control: CGPoint(x: 48, y: 57))
    eyes.move(to: CGPoint(x: 61.5, y: 56.5))
    eyes.addLine(to: CGPoint(x: 52, y: 64.3))
    eyes.addQuadCurve(to: CGPoint(x: 60.5, y: 56), control: CGPoint(x: 47, y: 54.5))
    context.stroke(eyes, with: ink, style: style)
    
    // hard hat — dome, brim, and a center ridge, sitting on top of the body
    var dome = Path()
    dome.move(to: CGPoint(x: 31, y: 50))
    dome.addQuadCurve(to: CGPoint(x: 63, y: 50), control: CGPoint(x: 47, y: 30))
    dome.closeSubpath()
    context.fill(dome, with: .color(hatColor))
    context.fill(Path(roundedRect: CGRect(x: 26, y: 48, width: 42, height: 4.5), cornerRadius: 2.25),
                 with: .color(hatColor))
    var ridge = Path()
    ridge.move(to: CGPoint(x: 47, y: 41))
    ridge.addLine(to: CGPoint(x: 47, y: 48))
    context.stroke(ridge, with: .color(.orange), style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))
  }
}

#Preview {
  VStack(spacing: 40) {
    HardHatSpider()
    HardHatSpider(threadLength: 120)
    HardHatSpider(width: 90, isWiggling: false)
    HStack(spacing: 30) {                        // side by side with the old one, same settings
      HardHatSpider(width: 90)
    }
  }
  .padding(.top, 140)
  .padding()
  .background(.black)
}
