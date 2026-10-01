//
//  LineCat.swift
//  LearnScrumble
//

import SwiftUI

/// A cat drawn with lines, facing right, feet at the bottom.
/// Reusable anywhere: set its width, color, and whether it walks.
///
///     LineCat()                                   // 64pt wide, white, walking
///     LineCat(width: 120, color: .orange)         // bigger, orange
///     LineCat(isWalking: false)                   // sitting still
struct LineCat: View {
  var width: CGFloat = 64
  var color: Color = .white
  var lineWidth: CGFloat = 2
  var isWalking: Bool = true
  var stepSpeed: Double = 9                       // how fast the legs move
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private static let drawingSize = CGSize(width: 64, height: 44)
  
  var body: some View {
    TimelineView(.animation(paused: !isWalking || reduceMotion)) { timeline in
      let t = timeline.date.timeIntervalSinceReferenceDate
      let step = (isWalking && !reduceMotion) ? t.truncatingRemainder(dividingBy: 100) * stepSpeed : 0
      
      Canvas { context, size in
        context.scaleBy(x: size.width / Self.drawingSize.width,
                        y: size.height / Self.drawingSize.height)
        draw(in: context, step: step)
      }
    }
    .frame(width: width, height: width * Self.drawingSize.height / Self.drawingSize.width)
    .accessibilityHidden(true)                  // decorative — the parent view should describe what's happening
  }
  
  private func draw(in context: GraphicsContext, step: Double) {
    let swing = sin(step) * 5                   // how far the legs reach
    let bob = abs(sin(step)) * 1.2              // slight body bounce while walking
    
    var cat = Path()
    
    // body and head
    cat.addEllipse(in: CGRect(x: 12, y: 16 - bob, width: 32, height: 16))
    cat.addEllipse(in: CGRect(x: 40, y: 5 - bob, width: 17, height: 16))
    
    // ears
    cat.move(to: CGPoint(x: 42, y: 9 - bob))
    cat.addLine(to: CGPoint(x: 43, y: 0 - bob))
    cat.addLine(to: CGPoint(x: 48, y: 6 - bob))
    cat.move(to: CGPoint(x: 51, y: 6 - bob))
    cat.addLine(to: CGPoint(x: 55, y: 0 - bob))
    cat.addLine(to: CGPoint(x: 56, y: 10 - bob))
    
    // whiskers
    cat.move(to: CGPoint(x: 56, y: 15 - bob))
    cat.addLine(to: CGPoint(x: 63, y: 14 - bob))
    cat.move(to: CGPoint(x: 56, y: 17 - bob))
    cat.addLine(to: CGPoint(x: 63, y: 19 - bob))
    // whiskers — left side of the face
    cat.move(to: CGPoint(x: 41, y: 15 - bob))
    cat.addLine(to: CGPoint(x: 34, y: 13 - bob))
    cat.move(to: CGPoint(x: 43, y: 18 - bob))
    cat.addLine(to: CGPoint(x: 35, y: 22 - bob))
    // tail, swaying with each step
    cat.move(to: CGPoint(x: 13, y: 22 - bob))
    cat.addQuadCurve(to: CGPoint(x: 3 + swing * 0.6, y: 4 - bob),
                     control: CGPoint(x: 0, y: 22 - bob))
    
    // legs — two segments each, so they bend like knees and elbows.
    // Diagonal pairs move together; each paw lifts a little while it swings forward.
    let legs: [(x: Double, direction: Double, bend: Double)] = [
      (18, 1, -3),   // back legs — hock bends backward
      (23, -1, -3),
      (35, -1, -2),  // front legs — elbow bends backward too
      (40, 1, -2),
    ]
    for leg in legs {
      let reach = swing * leg.direction
      let lift = max(0, cos(step) * leg.direction) * 2.5      // paw rises only on the forward swing
      let top = CGPoint(x: leg.x, y: 30 - bob)
      let paw = CGPoint(x: leg.x + reach, y: 42 - lift)
      let joint = CGPoint(x: (top.x + paw.x) / 2 + leg.bend * (1 + lift / 2.5),
                          y: (top.y + paw.y) / 2)
      cat.move(to: top)
      cat.addLine(to: joint)
      cat.addLine(to: paw)
    }
    
    context.stroke(cat, with: .color(color),
                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    
    // eyes
    for x in [46.0, 52.0] {
      context.fill(Path(ellipseIn: CGRect(x: x - 1, y: 11.5 - bob, width: 2, height: 2)),
                   with: .color(color))
    }
  }
}

#Preview {
  VStack(spacing: 30) {
    LineCat()
    LineCat(width: 120, color: .orange)
    LineCat(isWalking: true)
  }
  .padding()
  .background(.black)
}
