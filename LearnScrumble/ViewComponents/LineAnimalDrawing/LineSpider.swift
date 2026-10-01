//
//  LineSpider.swift
//  LearnScrumble
//

import SwiftUI

/// A spider drawn with lines, wearing a construction hard hat.
/// Reusable anywhere: set its width, colors, whether its legs wiggle,
/// and optionally a silk thread going up from the top of its hat.
///
///     LineSpider()                                 // 56pt wide, wiggling
///     LineSpider(threadLength: 300)                // hanging on a thread
///     LineSpider(width: 90, isWiggling: false)     // bigger, standing still
struct LineSpider: View {
  var width: CGFloat = 56
  var color: Color = .white
  var hatColor: Color = .yellow
  var lineWidth: CGFloat = 1.8
  var isWiggling: Bool = true
  var threadLength: CGFloat = 0                    // 0 = no thread
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private static let drawingSize = CGSize(width: 72, height: 60)
  private static let hatTopY: CGFloat = 11.5       // where the thread attaches, in drawing coordinates
  
  private var scale: CGFloat { width / Self.drawingSize.width }
  
  var body: some View {
    TimelineView(.animation(paused: !isWiggling || reduceMotion)) { timeline in
      let moving = isWiggling && !reduceMotion
      let t = moving ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100) : 0
      
      Canvas { context, size in
        context.scaleBy(x: size.width / Self.drawingSize.width,
                        y: size.height / Self.drawingSize.height)
        draw(in: context, time: t, wiggle: moving ? 1.6 : 0)
      }
    }
    .frame(width: width, height: width * Self.drawingSize.height / Self.drawingSize.width)
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
    
    // legs — 4 per side, each bending up at the knee and down to the foot (left side; right side is mirrored)
    let hips:  [CGPoint] = [.init(x: 27, y: 31), .init(x: 26, y: 35), .init(x: 26, y: 40), .init(x: 27, y: 44)]
    let knees: [CGPoint] = [.init(x: 12, y: 18), .init(x: 14, y: 22), .init(x: 16, y: 27), .init(x: 19, y: 32)]
    let feet:  [CGPoint] = [.init(x: 2, y: 58),  .init(x: 7, y: 58),  .init(x: 13, y: 58), .init(x: 19, y: 58)]
    
    var legs = Path()
    for i in 0..<4 {
      for isLeft in [true, false] {
        let phase = time * 7 + Double(i) + (isLeft ? 0 : .pi)
        let kneeLift = sin(phase) * wiggle
        let footShift = sin(phase + 1) * wiggle * 0.5
        
        func place(_ p: CGPoint, dx: Double = 0, dy: Double = 0) -> CGPoint {
          let x = p.x + dx
          return CGPoint(x: isLeft ? x : Self.drawingSize.width - x, y: p.y + dy)
        }
        legs.move(to: place(hips[i]))
        legs.addLine(to: place(knees[i], dy: kneeLift))
        legs.addLine(to: place(feet[i], dx: footShift))
      }
    }
    context.stroke(legs, with: .color(color), style: style)
    
    // abdomen and head
    var torso = Path()
    torso.addEllipse(in: CGRect(x: 24, y: 28, width: 24, height: 22))
    torso.addEllipse(in: CGRect(x: 28, y: 16, width: 16, height: 14))
    context.stroke(torso, with: .color(color), style: style)
    
    // hard hat — dome, brim, and a center ridge
    var dome = Path()
    dome.move(to: CGPoint(x: 28, y: 19))
    dome.addQuadCurve(to: CGPoint(x: 44, y: 19), control: CGPoint(x: 36, y: 4))
    dome.closeSubpath()
    context.fill(dome, with: .color(hatColor))
    context.fill(Path(roundedRect: CGRect(x: 25, y: 18, width: 22, height: 3), cornerRadius: 1.5),
                 with: .color(hatColor))
    var ridge = Path()
    ridge.move(to: CGPoint(x: 36, y: 12.5))
    ridge.addLine(to: CGPoint(x: 36, y: 18))
    context.stroke(ridge, with: .color(.orange), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
    
    // eyes
    for x in [32.5, 39.5] {
      context.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: 22.4, width: 3.2, height: 3.2)),
                   with: .color(color))
    }
  }
}

#Preview {
  VStack(spacing: 40) {
    LineSpider()
    LineSpider(threadLength: 120)
    LineSpider(width: 90, isWiggling: false)
  }
  .padding(.top, 140)
  .padding()
  .background(.black)
}
