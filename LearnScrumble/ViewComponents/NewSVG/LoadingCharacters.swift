//
//  LoadingCharacters.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import SwiftUI

// MARK: - Flow of this file
// Rigged versions of the NewSVG cat-on-wheels and mouse for LoadingView's chase around the ring.
// Traced on the same 100×100 grid as CatOnWheels.swift / Mouse.swift (both face left there, and here),
// drawn piece by piece so parts can move:
//   WheelCat     — hubs spin inside the wheel rims, the striped belly ball rolls, tail wags, body bobs
//   RunningMouse — tiny feet scurry, body bounces, tail whips
// Both take `t` from the parent's TimelineView and fall back to a still pose with Reduce Motion.

// MARK: - Cat on wheels

struct WheelCat: View {
  var t: Double
  var size: CGFloat = 54
  var isMoving = true            // false: parked — wheels, ball and tail stop (e.g. sad in AnswerResultView)
  var sad = false                // droopy eyes and a frown instead of the drawing's big smile
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  var body: some View {
    RigCanvas(space: CGSize(width: 104, height: 100), origin: CGPoint(x: 2, y: 0), size: size, draw: draw)
  }
  
  private func draw(_ ctx: GraphicsContext) {
    let still = reduceMotion || !isMoving
    let w: CGFloat = 3.4
    let style = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    let thin = StrokeStyle(lineWidth: w * 0.6, lineCap: .round)
    let ink = GraphicsContext.Shading.color(.white)
    let bob = still ? 0 : abs(sin(t * 10)) * 1.2                     // rides a little bumpy on its wheels
    let spin = still ? 0 : -t * 420                                  // degrees — rolls toward its head (left)
    let wag = still ? 0 : sin(t * 6) * 12
    
    var upper = ctx                                                  // everything above the wheels bobs
    upper.translateBy(x: 0, y: -bob)
    
    // ears
    var ears = Path()
    ears.move(to: CGPoint(x: 5, y: 18))
    ears.addLine(to: CGPoint(x: 2.5, y: 2.5))
    ears.addQuadCurve(to: CGPoint(x: 19, y: 11), control: CGPoint(x: 11, y: 4))
    ears.move(to: CGPoint(x: 41, y: 12))
    ears.addQuadCurve(to: CGPoint(x: 57, y: 6), control: CGPoint(x: 50, y: 10))
    ears.addQuadCurve(to: CGPoint(x: 54, y: 22), control: CGPoint(x: 57.5, y: 15))
    upper.stroke(ears, with: ink, style: style)
    
    // head with its striped forehead patch, happy closed eyes, nose and mouth
    upper.stroke(Path(ellipseIn: CGRect(x: 5, y: 13, width: 46.5, height: 40.5)), with: ink, style: style)
    var face = Path()
    face.move(to: CGPoint(x: 19.5, y: 12.5))
    face.addQuadCurve(to: CGPoint(x: 37, y: 12), control: CGPoint(x: 27, y: 27))
    for (x, top, bottom) in [(24.0, 13.0, 17.5), (28.5, 12.0, 18.5), (32.5, 12.0, 16.0)] {
      face.move(to: CGPoint(x: x, y: top))
      face.addLine(to: CGPoint(x: x, y: bottom))
    }
    if sad {                                                         // droopy eyes, sloping down to the outside
      face.move(to: CGPoint(x: 13.5, y: 29))
      face.addLine(to: CGPoint(x: 22.5, y: 25.5))
      face.move(to: CGPoint(x: 35, y: 25.5))
      face.addLine(to: CGPoint(x: 44, y: 29))
    } else {                                                         // the drawing's happy closed eyes
      face.move(to: CGPoint(x: 13, y: 28.5))
      face.addQuadCurve(to: CGPoint(x: 23, y: 28.5), control: CGPoint(x: 18, y: 20))
      face.move(to: CGPoint(x: 34.5, y: 28.5))
      face.addQuadCurve(to: CGPoint(x: 44.5, y: 28.5), control: CGPoint(x: 39.5, y: 20))
    }
    face.move(to: CGPoint(x: 25, y: 34.5))
    face.addQuadCurve(to: CGPoint(x: 30.5, y: 34.5), control: CGPoint(x: 28, y: 38))
    face.move(to: CGPoint(x: 28, y: 37))
    face.addLine(to: CGPoint(x: 28, y: 40.5))
    if sad {                                                         // frown
      face.move(to: CGPoint(x: 19, y: 47))
      face.addQuadCurve(to: CGPoint(x: 37, y: 47), control: CGPoint(x: 28, y: 37.5))
    } else {                                                         // big "w" smile
      face.move(to: CGPoint(x: 14, y: 41.5))
      face.addQuadCurve(to: CGPoint(x: 28, y: 40.5), control: CGPoint(x: 20, y: 50))
      face.addQuadCurve(to: CGPoint(x: 40, y: 41.5), control: CGPoint(x: 35, y: 50))
    }
    upper.stroke(face, with: ink, style: style)
    
    // striped body and back
    var body = Path(ellipseIn: CGRect(x: 46, y: 36.5, width: 29, height: 18.5))
    body.move(to: CGPoint(x: 63.5, y: 39.5)); body.addLine(to: CGPoint(x: 63.5, y: 51.5))
    body.move(to: CGPoint(x: 69.5, y: 40.5)); body.addLine(to: CGPoint(x: 68.5, y: 50))
    body.move(to: CGPoint(x: 60, y: 36.8))
    body.addQuadCurve(to: CGPoint(x: 87, y: 53), control: CGPoint(x: 80, y: 37))
    upper.stroke(body, with: ink, style: style)
    
    // curly tail — wags around its base
    var tail = Path()
    tail.move(to: CGPoint(x: 85, y: 46.5))
    tail.addQuadCurve(to: CGPoint(x: 97, y: 51), control: CGPoint(x: 92, y: 42.5))
    tail.addQuadCurve(to: CGPoint(x: 88.5, y: 58.5), control: CGPoint(x: 98, y: 57))
    upper.stroke(Rig.rotated(tail, by: wag, around: CGPoint(x: 86, y: 52)), with: ink, style: style)
    
    // legs: striped back leg and front leg, reaching down to the wheels
    var legs = Path(ellipseIn: CGRect(x: 78, y: 54, width: 12, height: 15))
    legs.move(to: CGPoint(x: 81.5, y: 57.5)); legs.addLine(to: CGPoint(x: 81.5, y: 66))
    legs.move(to: CGPoint(x: 85.5, y: 56.5)); legs.addLine(to: CGPoint(x: 86.3, y: 67))
    legs.move(to: CGPoint(x: 19.5, y: 54))
    legs.addQuadCurve(to: CGPoint(x: 21.5, y: 70), control: CGPoint(x: 17, y: 62))
    legs.move(to: CGPoint(x: 31, y: 53.5))
    legs.addQuadCurve(to: CGPoint(x: 30, y: 70), control: CGPoint(x: 34, y: 62))
    legs.move(to: CGPoint(x: 23.5, y: 57)); legs.addLine(to: CGPoint(x: 23.5, y: 66))
    legs.move(to: CGPoint(x: 28.5, y: 57)); legs.addLine(to: CGPoint(x: 28.8, y: 66.5))
    upper.stroke(legs, with: ink, style: style)
    
    // wheels — rims stay on the ground, hubs + spokes spin
    ctx.stroke(Path(ellipseIn: CGRect(x: 17.2, y: 70.2, width: 18.6, height: 18.6)), with: ink, style: style)
    ctx.stroke(Path(ellipseIn: CGRect(x: 73.4, y: 70.4, width: 16.2, height: 21.8)), with: ink, style: style)
    for (center, reach) in [(CGPoint(x: 26.5, y: 79.5), 6.2), (CGPoint(x: 81.5, y: 81.3), 5.8)] {
      ctx.fill(Path(ellipseIn: CGRect(x: center.x - 2.4, y: center.y - 2.4, width: 4.8, height: 4.8)), with: ink)
      var spokes = Path()
      for k in 0..<3 {
        let a = (spin + Double(k) * 120) * .pi / 180
        spokes.move(to: center)
        spokes.addLine(to: CGPoint(x: center.x + cos(a) * reach, y: center.y + sin(a) * reach))
      }
      ctx.stroke(spokes, with: ink, style: thin)
    }
    
    // bar between the wheels
    var bar = Path()
    bar.move(to: CGPoint(x: 35.5, y: 84.5))
    bar.addQuadCurve(to: CGPoint(x: 68, y: 86.5), control: CGPoint(x: 50, y: 87))
    ctx.stroke(bar, with: ink, style: style)
    
    // striped belly ball — rolls; stripes clipped inside the ball so they never poke out
    let ball = CGRect(x: 49.2, y: 64.3, width: 16.8, height: 15)
    let ballCenter = CGPoint(x: ball.midX, y: ball.midY)
    upper.stroke(Path(ellipseIn: ball), with: ink, style: style)
    var inside = upper
    inside.clip(to: Path(ellipseIn: ball.insetBy(dx: w / 2, dy: w / 2)))
    var stripes = Path()
    for dx in [-6.0, -2.0, 2.0, 6.0] {
      stripes.move(to: CGPoint(x: ballCenter.x + dx, y: ballCenter.y - 12))
      stripes.addLine(to: CGPoint(x: ballCenter.x + dx, y: ballCenter.y + 12))
    }
    inside.stroke(Rig.rotated(stripes, by: spin * 0.8, around: ballCenter), with: ink, style: thin)
  }
}

// MARK: - Mouse

struct RunningMouse: View {
  var t: Double
  var size: CGFloat = 30
  var isMoving = true            // false: sitting still — no pattering feet, no tail whip
  var sad = false                // tail hangs low and limp
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  var body: some View {
    RigCanvas(space: CGSize(width: 104, height: 104), origin: CGPoint(x: 2, y: 2), size: size, draw: draw)
  }
  
  private func draw(_ ctx: GraphicsContext) {
    let still = reduceMotion || !isMoving
    let w: CGFloat = 4.2
    let style = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    let ink = GraphicsContext.Shading.color(.white)
    let bounce = still ? 0 : abs(sin(t * 16)) * 2.5                   // quick little scurry bounce
    let whip = (sad ? 38 : 0) + (still ? 0 : sin(t * 9) * (sad ? 4 : 10))   // sad: tail drooped down behind
    
    // tiny feet pattering on the ground (added — the drawing has none), under the bouncing body
    var feet = Path()
    for (i, x) in [24.0, 38.0, 54.0, 68.0].enumerated() {
      let kick = still ? 0 : sin(t * 16 + Double(i) * .pi) * 3.5
      feet.move(to: CGPoint(x: x, y: 94))
      feet.addLine(to: CGPoint(x: x + kick, y: 99.5))
    }
    ctx.stroke(feet, with: ink, style: StrokeStyle(lineWidth: w * 0.7, lineCap: .round))
    
    var body = ctx
    body.translateBy(x: 0, y: -bounce)
    
    // body outline with its ear, nose to the left
    var outline = Path()
    outline.move(to: CGPoint(x: 17, y: 67))
    outline.addQuadCurve(to: CGPoint(x: 3, y: 84), control: CGPoint(x: 5, y: 74))
    outline.addQuadCurve(to: CGPoint(x: 25, y: 95.5), control: CGPoint(x: 2, y: 95))
    outline.addLine(to: CGPoint(x: 62, y: 95.5))
    outline.addQuadCurve(to: CGPoint(x: 83, y: 80), control: CGPoint(x: 83, y: 95))
    outline.addQuadCurve(to: CGPoint(x: 34, y: 59.5), control: CGPoint(x: 78, y: 52))
    outline.move(to: CGPoint(x: 17, y: 67))                           // ear
    outline.addQuadCurve(to: CGPoint(x: 25, y: 51), control: CGPoint(x: 13, y: 52))
    outline.addQuadCurve(to: CGPoint(x: 34, y: 59.5), control: CGPoint(x: 31, y: 52))
    body.stroke(outline, with: ink, style: style)
    body.stroke(Path(ellipseIn: CGRect(x: 15.4, y: 76.8, width: 8.4, height: 8.4)), with: ink, style: style) // eye
    
    // tail — whips from its base
    var tail = Path()
    tail.move(to: CGPoint(x: 83, y: 70))
    tail.addQuadCurve(to: CGPoint(x: 96, y: 58), control: CGPoint(x: 97, y: 67))
    tail.addQuadCurve(to: CGPoint(x: 80, y: 30), control: CGPoint(x: 95, y: 45))
    tail.addQuadCurve(to: CGPoint(x: 93, y: 2), control: CGPoint(x: 73, y: 8))
    body.stroke(Rig.rotated(tail, by: whip, around: CGPoint(x: 83, y: 70)), with: ink, style: style)
  }
}

#Preview {
  TimelineView(.animation) { context in
    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100)
    HStack(spacing: 30) {
      WheelCat(t: t, size: 150)
      RunningMouse(t: t, size: 110)
    }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(.black)
}
