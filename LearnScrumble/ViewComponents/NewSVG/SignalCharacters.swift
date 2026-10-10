//
//  SignalCharacters.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import SwiftUI

// MARK: - Flow of this file
// Rigged versions of the NewSVG owl, raccoon and spider for OfflineView. Same line-art look —
// thick white rounded strokes, traced on a 100×100 grid from Owl.swift / Racoon.swift / Spider.swift —
// but drawn piece by piece so wings, legs, arms and tails move, and each one HOLDS its phone:
// the phone is drawn first and the wing / paw / leg on top, so the limb grips it.
//
// Each view takes a time value `t` from the parent's TimelineView, so one timeline drives all three.
// The parent should pause that timeline for Reduce Motion; on top of that, every character reads
// accessibilityReduceMotion itself and draws a settled pose (wings folded, legs at rest, marks visible).
// Every view draws in its own "space": the 100×100 character box plus room around it for the raised
// phone, so nothing gets clipped when a limb lifts it up.

// MARK: - Shared rig helpers

enum Rig {
  /// Rotates a point around a joint. Positive degrees = clockwise on screen.
  static func rotate(_ p: CGPoint, around c: CGPoint, by degrees: Double) -> CGPoint {
    let r = degrees * .pi / 180
    let dx = p.x - c.x, dy = p.y - c.y
    return CGPoint(x: c.x + dx * cos(r) - dy * sin(r), y: c.y + dx * sin(r) + dy * cos(r))
  }
  
  /// Rotates a whole limb around its joint.
  static func rotated(_ path: Path, by degrees: Double, around c: CGPoint) -> Path {
    path.applying(CGAffineTransform(translationX: c.x, y: c.y)
      .rotated(by: degrees * .pi / 180)
      .translatedBy(x: -c.x, y: -c.y))
  }
  
  static func lerp(_ a: CGPoint, _ b: CGPoint, _ f: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
  }
  
  /// Searching: flickers between no bars and one. Celebrating: full bars.
  static func bars(t: Double, seed: Double, celebrating: Bool) -> Int {
    celebrating ? 4 : (sin(t * 3 + seed) > 0.7 ? 1 : 0)
  }
  
  /// A phone standing on `bottomCenter`, with its signal bars floating above it.
  /// Filled black first so lines behind it don't show through the screen.
  static func drawPhone(in ctx: GraphicsContext, bottomCenter: CGPoint, height: CGFloat, bars: Int, lineWidth: CGFloat) {
    let width = height * 0.6
    let rect = CGRect(x: bottomCenter.x - width / 2, y: bottomCenter.y - height, width: width, height: height)
    let phone = Path(roundedRect: rect, cornerRadius: width * 0.22)
    ctx.fill(phone, with: .color(.black))
    ctx.stroke(phone, with: .color(.white), style: StrokeStyle(lineWidth: lineWidth * 0.8, lineJoin: .round))
    
    var homeBar = Path()
    homeBar.move(to: CGPoint(x: rect.midX - width * 0.15, y: rect.maxY - height * 0.13))
    homeBar.addLine(to: CGPoint(x: rect.midX + width * 0.15, y: rect.maxY - height * 0.13))
    ctx.stroke(homeBar, with: .color(.white), style: StrokeStyle(lineWidth: lineWidth * 0.5, lineCap: .round))
    
    let barWidth = width * 0.16, gap = width * 0.09
    let total = barWidth * 4 + gap * 3
    let barColor: Color = bars == 4 ? .green.opacity(0.7) : .red  // red while searching, green once the signal is back
    for i in 0..<4 {
      let barHeight = height * (0.12 + 0.08 * CGFloat(i))
      let bar = CGRect(x: rect.midX - total / 2 + CGFloat(i) * (barWidth + gap),
                       y: rect.minY - height * 0.08 - barHeight,
                       width: barWidth, height: barHeight)
      ctx.fill(Path(roundedRect: bar, cornerRadius: barWidth * 0.3),
               with: .color(i < bars ? barColor : barColor.opacity(0.3)))
    }
  }
  
  /// "?" / "!" popping over a head while searching, a heart once the signal is back.
  /// `still` (Reduce Motion): always fully visible instead of fading in and out.
  static func drawMark(in ctx: GraphicsContext, at p: CGPoint, t: Double, seed: Double, celebrating: Bool, size: CGFloat, still: Bool = false) {
    let phase = still ? 0 : t * 1.6 + seed * 2.1
    var ctx = ctx
    ctx.opacity = celebrating || still ? 1 : max(0, sin(phase * .pi))     // fades in and out
    if celebrating {
      var heart = ctx.resolve(Image(systemName: "heart.fill"))
      heart.shading = .color(.red)
      ctx.draw(heart, in: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size))
    } else {
      ctx.draw(Text(Int(phase).isMultiple(of: 2) ? "?" : "!")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(.white),
               at: p)
    }
  }
}

/// Lays out a character's drawing space and scales it to the requested size. Shared by every rigged character.
struct RigCanvas: View {
  let space: CGSize          // full drawing space, in character units
  let origin: CGPoint        // where the 100×100 character box sits inside that space
  let size: CGFloat          // on-screen width of the 100×100 character box
  let draw: (GraphicsContext) -> Void
  
  var body: some View {
    Canvas { ctx, canvasSize in
      ctx.scaleBy(x: canvasSize.width / space.width, y: canvasSize.height / space.height)
      ctx.translateBy(x: origin.x, y: origin.y)
      draw(ctx)
    }
    .frame(width: size * space.width / 100, height: size * space.height / 100)
    .accessibilityHidden(true)                                    // decoration only
  }
}

// MARK: - Owl

/// Flaps its free wing and holds the phone up high with the other one, eyes on the screen.
struct PhoneOwl: View {
  var t: Double
  var celebrating = false
  var facing: CGFloat = 1        // 1 = phone on the right, -1 = mirrored
  var size: CGFloat = 64         // width of the owl itself
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  var body: some View {
    RigCanvas(space: CGSize(width: 155, height: 150), origin: CGPoint(x: 27, y: 45), size: size, draw: draw)
  }
  
  private func draw(_ base: GraphicsContext) {
    let w: CGFloat = 3.3
    let style = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    let ink = GraphicsContext.Shading.color(.white)
    let flip = facing < 0
    var ctx = base                                                  // the owl itself, mirrored when flying left
    if flip { ctx.translateBy(x: 100, y: 0); ctx.scaleBy(x: -1, y: 1) }
    func mirror(_ p: CGPoint) -> CGPoint { flip ? CGPoint(x: 100 - p.x, y: p.y) : p } // for props drawn un-mirrored
    
    // head and ear tufts
    var head = Path()
    head.move(to: CGPoint(x: 16.5, y: 41))
    head.addQuadCurve(to: CGPoint(x: 12.5, y: 19), control: CGPoint(x: 17, y: 27))
    head.addQuadCurve(to: CGPoint(x: 11, y: 1.5), control: CGPoint(x: 10.5, y: 12))
    head.addLine(to: CGPoint(x: 25, y: 12))
    head.addQuadCurve(to: CGPoint(x: 75, y: 12), control: CGPoint(x: 50, y: 3))
    head.addLine(to: CGPoint(x: 89, y: 1.5))
    head.addQuadCurve(to: CGPoint(x: 87.5, y: 19), control: CGPoint(x: 89.5, y: 12))
    head.addQuadCurve(to: CGPoint(x: 83.5, y: 41), control: CGPoint(x: 83, y: 27))
    ctx.stroke(head, with: ink, style: style)
    
    // eyes — pupils glance up at the phone, with a blink now and then
    let still = reduceMotion
    let blinking = !still && !celebrating && t.truncatingRemainder(dividingBy: 3.2) < 0.12
    for c in [CGPoint(x: 35, y: 35), CGPoint(x: 65, y: 35)] {
      ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 10, y: c.y - 10, width: 20, height: 20)), with: ink, style: style)
      if blinking {
        var lid = Path()
        lid.move(to: CGPoint(x: c.x - 5, y: c.y))
        lid.addLine(to: CGPoint(x: c.x + 5, y: c.y))
        ctx.stroke(lid, with: ink, style: style)
      } else {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x + 2.2 - 3.3, y: c.y - 2 - 3.3, width: 6.6, height: 6.6)), with: ink)
      }
    }
    
    // beak
    var beak = Path()
    beak.move(to: CGPoint(x: 42.5, y: 48))
    beak.addLine(to: CGPoint(x: 50, y: 58.5))
    beak.addLine(to: CGPoint(x: 57.5, y: 48))
    ctx.stroke(beak, with: ink, style: style)
    
    // belly feathers
    var belly = Path()
    for (x, y) in [(36.7, 66.5), (50.0, 66.5), (63.3, 66.5), (41.7, 74.5), (56.7, 74.5), (50.0, 83.0)] {
      belly.move(to: CGPoint(x: x - 3.5, y: y - 0.5))
      belly.addQuadCurve(to: CGPoint(x: x + 3.5, y: y - 0.5), control: CGPoint(x: x, y: y + 4))
    }
    ctx.stroke(belly, with: ink, style: style)
    
    // body sides, base and feet
    var lower = Path()
    lower.move(to: CGPoint(x: 15, y: 48))
    lower.addCurve(to: CGPoint(x: 31, y: 94.5), control1: CGPoint(x: 8, y: 68), control2: CGPoint(x: 16, y: 90))
    lower.move(to: CGPoint(x: 85, y: 48))
    lower.addCurve(to: CGPoint(x: 69, y: 94.5), control1: CGPoint(x: 92, y: 68), control2: CGPoint(x: 84, y: 90))
    lower.move(to: CGPoint(x: 42, y: 94.5))
    lower.addLine(to: CGPoint(x: 58, y: 94.5))
    for x in [37.0, 63.0] {                                         // little dome feet
      lower.move(to: CGPoint(x: x - 4.8, y: 96.5))
      lower.addQuadCurve(to: CGPoint(x: x + 4.8, y: 96.5), control: CGPoint(x: x, y: 87))
      lower.closeSubpath()
    }
    ctx.stroke(lower, with: ink, style: style)
    
    // free wing — flaps
    let flap = still ? 0 : (celebrating ? (sin(t * 16) + 1) / 2 * 75 : (sin(t * 11) + 1) / 2 * 50)
    var leftWing = Path()
    leftWing.move(to: CGPoint(x: 15, y: 48))
    leftWing.addQuadCurve(to: CGPoint(x: 25, y: 81.5), control: CGPoint(x: 31, y: 53))
    ctx.stroke(Rig.rotated(leftWing, by: flap, around: CGPoint(x: 15, y: 48)), with: ink, style: style)
    
    // phone wing — raised high, wobbling; phone first so the wing tip grips it
    let shoulder = CGPoint(x: 85, y: 48)
    let raise = still ? -140 : -140 + sin(t * (celebrating ? 14 : 5)) * (celebrating ? 18 : 10)
    let tip = Rig.rotate(CGPoint(x: 75, y: 81.5), around: shoulder, by: raise)
    Rig.drawPhone(in: base, bottomCenter: mirror(CGPoint(x: tip.x, y: tip.y + 5)), height: 27,
                  bars: Rig.bars(t: t, seed: 0, celebrating: celebrating), lineWidth: w)
    var phoneWing = Path()
    phoneWing.move(to: shoulder)
    phoneWing.addQuadCurve(to: CGPoint(x: 75, y: 81.5), control: CGPoint(x: 69, y: 53))
    ctx.stroke(Rig.rotated(phoneWing, by: raise, around: shoulder), with: ink, style: style)
    
    Rig.drawMark(in: base, at: mirror(CGPoint(x: 6, y: -10)), t: t, seed: 0, celebrating: celebrating, size: 20, still: still)
  }
}

// MARK: - Raccoon

/// Runs on three legs with the fourth stretched out holding the phone; lifts it high when it stops.
/// `arm` swaps the phone for a happy wave, or puts the fourth leg back on the ground (AnswerResultView).
struct PhoneRaccoon: View {
  enum Arm {
    case phone      // OfflineView: holding the phone up
    case wave       // waving its paw high, no phone
    case scratch    // scratching behind its ear (EntryView)
    case leg        // just a fourth leg, walking like the others
  }
  
  var t: Double
  var celebrating = false
  var facing: CGFloat = 1        // the drawing faces right; -1 runs left
  var running = true
  var raise: Double = 0          // 0 = phone held out in front, 1 = held up high
  var arm: Arm = .phone
  var sad = false                // tail hangs down, eyes look at the floor
  var size: CGFloat = 86
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  var body: some View {
    RigCanvas(space: CGSize(width: 146, height: 100), origin: CGPoint(x: 23, y: 8), size: size, draw: draw) // room for the arm both ways
  }
  
  private func draw(_ base: GraphicsContext) {
    let w: CGFloat = 3
    let style = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    let ink = GraphicsContext.Shading.color(.white)
    let flip = facing < 0
    var ctx = base
    if flip { ctx.translateBy(x: 100, y: 0); ctx.scaleBy(x: -1, y: 1) }
    func mirror(_ p: CGPoint) -> CGPoint { flip ? CGPoint(x: 100 - p.x, y: p.y) : p }
    
    // striped tail — wags around its base
    var tail = Path()
    tail.move(to: CGPoint(x: 20, y: 45))
    tail.addLine(to: CGPoint(x: 20, y: 18))
    tail.addQuadCurve(to: CGPoint(x: 12.4, y: 10.4), control: CGPoint(x: 20, y: 10.4))
    tail.addQuadCurve(to: CGPoint(x: 4.8, y: 18), control: CGPoint(x: 4.8, y: 10.4))
    tail.addLine(to: CGPoint(x: 4.8, y: 52))
    tail.addQuadCurve(to: CGPoint(x: 16, y: 58), control: CGPoint(x: 5.5, y: 58))
    for y in [23.3, 33.3, 43.3] {
      tail.move(to: CGPoint(x: 4.8, y: y))
      tail.addLine(to: CGPoint(x: 20, y: y))
    }
    let still = reduceMotion
    let wag = sad ? 28 + (still || !running ? 0 : sin(t * 6) * 4)      // sad: tail hangs down behind
                  : (still ? 0 : sin(t * (running ? 10 : 4)) * 10)
    ctx.stroke(Rig.rotated(tail, by: wag, around: CGPoint(x: 17, y: 56)), with: ink, style: style)
    
    // back and belly
    var body = Path()
    body.move(to: CGPoint(x: 11.5, y: 73.5))
    body.addQuadCurve(to: CGPoint(x: 45, y: 38.5), control: CGPoint(x: 13, y: 40))
    body.addQuadCurve(to: CGPoint(x: 56, y: 41), control: CGPoint(x: 52, y: 38.5))
    body.move(to: CGPoint(x: 11.5, y: 73.5))
    body.addLine(to: CGPoint(x: 68, y: 73.5))
    ctx.stroke(body, with: ink, style: style)
    
    // running legs — boots swinging from the hips (a fourth one when the front paw isn't busy)
    for (i, x) in (arm == .leg ? [11.5, 27.0, 48.0, 63.0] : [11.5, 27.0, 48.0]).enumerated() {
      let hip = CGPoint(x: x, y: 73.5)
      var leg = Path()
      leg.move(to: hip)
      leg.addLine(to: CGPoint(x: x, y: 86.5))
      leg.addLine(to: CGPoint(x: x + 10, y: 86.5))
      let swing = running && !still ? sin(t * 12 + (i.isMultiple(of: 2) ? 0 : .pi)) * 24 : 0
      ctx.stroke(Rig.rotated(leg, by: swing, around: hip), with: ink, style: style)
    }
    
    // head, ears and mask
    var head = Path()
    head.move(to: CGPoint(x: 56, y: 40))
    head.addLine(to: CGPoint(x: 62, y: 28.5))
    head.addLine(to: CGPoint(x: 68, y: 38.5))
    head.addLine(to: CGPoint(x: 79, y: 38.5))
    head.addLine(to: CGPoint(x: 85.5, y: 28.5))
    head.addLine(to: CGPoint(x: 91.5, y: 40))
    head.addQuadCurve(to: CGPoint(x: 95, y: 54), control: CGPoint(x: 98, y: 46))
    head.addLine(to: CGPoint(x: 80, y: 69))
    head.addQuadCurve(to: CGPoint(x: 68, y: 69), control: CGPoint(x: 74, y: 74))
    head.addLine(to: CGPoint(x: 54, y: 54))
    head.addQuadCurve(to: CGPoint(x: 56, y: 40), control: CGPoint(x: 50, y: 46))
    for x in [62.0, 85.5] {                                         // inner ears
      head.move(to: CGPoint(x: x - 3.5, y: 40.5))
      head.addLine(to: CGPoint(x: x, y: 35))
      head.addLine(to: CGPoint(x: x + 3.5, y: 40.5))
    }
    ctx.stroke(head, with: ink, style: style)
    
    var mask = Path()                                                // left mask, then mirrored for the right
    mask.move(to: CGPoint(x: 53.5, y: 57))
    mask.addQuadCurve(to: CGPoint(x: 64, y: 50.6), control: CGPoint(x: 57, y: 50.6))
    mask.addQuadCurve(to: CGPoint(x: 64, y: 57.4), control: CGPoint(x: 68.2, y: 54))
    mask.addQuadCurve(to: CGPoint(x: 57.5, y: 59.5), control: CGPoint(x: 59.5, y: 57.4))
    ctx.stroke(mask, with: ink, style: style)
    ctx.stroke(mask.applying(CGAffineTransform(translationX: 148.2, y: 0).scaledBy(x: -1, y: 1)), with: ink, style: style)
    let look = sad ? CGPoint(x: 0, y: 1.2) : CGPoint(x: 0.8, y: -0.8) // at the phone/up, or down at the floor
    for x in [64.0, 84.2] {
      ctx.fill(Path(ellipseIn: CGRect(x: x + look.x - 1.9, y: 53 + look.y - 1.9, width: 3.8, height: 3.8)), with: ink)
    }
    var nose = Path()
    nose.move(to: CGPoint(x: 71.2, y: 61.5))
    nose.addLine(to: CGPoint(x: 77, y: 61.5))
    nose.addLine(to: CGPoint(x: 74.1, y: 65))
    nose.closeSubpath()
    ctx.stroke(nose, with: ink, style: style)
    
    guard arm != .leg else { return }                                 // fourth leg already drawn with the others
    
    // front arm — phone: out in front, lifted high when it stops (phone first so the paw grips it);
    // wave: paw up high, swinging side to side
    let shoulder = CGPoint(x: 66, y: 71)
    let waving = arm == .wave
    let scratching = arm == .scratch
    let wobble = still ? .zero
      : (waving ? CGPoint(x: sin(t * 8) * 7, y: abs(cos(t * 8)) * 3)
       : scratching ? CGPoint(x: sin(t * 22) * 2.5, y: cos(t * 22) * 2)  // quick little scritch-scratch
                : CGPoint(x: sin(t * 9) * 1.5 + (celebrating ? sin(t * 14) * 4 : 0), y: cos(t * 7) * 1.5))
    let lift = waving ? 1 : raise
    let handBase = scratching ? CGPoint(x: 93, y: 33)                 // right behind the ear
                              : Rig.lerp(CGPoint(x: 109, y: 70), CGPoint(x: 108, y: 28), lift) // always clear of the face
    let hand = CGPoint(x: handBase.x + wobble.x, y: handBase.y + wobble.y)
    let elbow = scratching ? CGPoint(x: 108, y: 58) : Rig.lerp(CGPoint(x: 90, y: 82), CGPoint(x: 110, y: 66), lift)
    let holdsPhone = arm == .phone
    if holdsPhone {
      Rig.drawPhone(in: base, bottomCenter: mirror(CGPoint(x: hand.x, y: hand.y + 3)), height: 23,
                    bars: Rig.bars(t: t, seed: 2, celebrating: celebrating), lineWidth: w)
    }
    var armPath = Path()
    armPath.move(to: shoulder)
    armPath.addQuadCurve(to: hand, control: elbow)
    armPath.addEllipse(in: CGRect(x: hand.x - 2.6, y: hand.y - 2.6, width: 5.2, height: 5.2)) // paw
    ctx.stroke(armPath, with: ink, style: style)
    
    if holdsPhone {                                                  // the "?" / "!" belong to the signal hunt
      Rig.drawMark(in: base, at: mirror(CGPoint(x: 72, y: 18)), t: t, seed: 2, celebrating: celebrating, size: 15, still: still)
    }
  }
}

// MARK: - Spider

/// Hangs on its thread, legs wiggling, one leg holding the phone up high.
struct PhoneSpider: View {
  var t: Double
  var celebrating = false
  var size: CGFloat = 64
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  /// Where the thread leaves the top of the drawing, as a fraction of its width — the parent lines its thread up with it.
  static let threadX: CGFloat = (8 + 47.5) / 124
  
  var body: some View {
    RigCanvas(space: CGSize(width: 124, height: 118), origin: CGPoint(x: 8, y: 18), size: size, draw: draw)
  }
  
  private func draw(_ ctx: GraphicsContext) {
    let w: CGFloat = 2.6
    let style = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
    let ink = GraphicsContext.Shading.color(.white)
    let still = reduceMotion
    
    // thread from the top of the drawing to the body
    var thread = Path()
    thread.move(to: CGPoint(x: 47.5, y: -18))
    thread.addLine(to: CGPoint(x: 47.5, y: 46))
    ctx.stroke(thread, with: .color(.white.opacity(0.5)), lineWidth: 1.6)
    
    // five wiggling legs: (hip, knee, foot)
    let legs: [(CGPoint, CGPoint, CGPoint)] = [
      (CGPoint(x: 28, y: 52), CGPoint(x: 12, y: 40), CGPoint(x: 1, y: 55)),
      (CGPoint(x: 25, y: 61), CGPoint(x: 5, y: 55), CGPoint(x: 3, y: 79)),
      (CGPoint(x: 26, y: 68.5), CGPoint(x: 10, y: 67), CGPoint(x: 17, y: 85.5)),
      (CGPoint(x: 68, y: 60), CGPoint(x: 88, y: 52), CGPoint(x: 96, y: 72)),
      (CGPoint(x: 67.5, y: 68.5), CGPoint(x: 84, y: 66), CGPoint(x: 78, y: 89)),
    ]
    for (i, leg) in legs.enumerated() {
      var path = Path()
      path.move(to: leg.0)
      path.addQuadCurve(to: leg.2, control: leg.1)
      let wiggle = still ? 0 : sin(t * (celebrating ? 15 : 9) + Double(i) * 1.3) * (celebrating ? 10 : 6)
      ctx.stroke(Rig.rotated(path, by: wiggle, around: leg.0), with: ink, style: style)
    }
    
    // body and eyes
    ctx.stroke(Path(ellipseIn: CGRect(x: 27, y: 46.2, width: 40, height: 33)), with: ink, style: style)
    var eyes = Path()
    eyes.move(to: CGPoint(x: 34, y: 55.5))
    eyes.addLine(to: CGPoint(x: 41, y: 64))
    eyes.addQuadCurve(to: CGPoint(x: 37, y: 54), control: CGPoint(x: 48, y: 57))
    eyes.move(to: CGPoint(x: 61.5, y: 56.5))
    eyes.addLine(to: CGPoint(x: 52, y: 64.3))
    eyes.addQuadCurve(to: CGPoint(x: 60.5, y: 56), control: CGPoint(x: 47, y: 54.5))
    ctx.stroke(eyes, with: ink, style: style)
    
    // phone leg — raised up and to the side, waving; phone first so the foot grips it
    let hip = CGPoint(x: 67, y: 51)
    let wave = still ? 0 : sin(t * (celebrating ? 14 : 6)) * (celebrating ? 15 : 8)
    let foot = Rig.rotate(CGPoint(x: 92, y: 25), around: hip, by: wave)
    Rig.drawPhone(in: ctx, bottomCenter: CGPoint(x: foot.x, y: foot.y + 4), height: 28,
                  bars: Rig.bars(t: t, seed: 1.3, celebrating: celebrating), lineWidth: w)
    var phoneLeg = Path()
    phoneLeg.move(to: hip)
    phoneLeg.addQuadCurve(to: CGPoint(x: 92, y: 25), control: CGPoint(x: 88, y: 48))
    ctx.stroke(Rig.rotated(phoneLeg, by: wave, around: hip), with: ink, style: style)
    
    Rig.drawMark(in: ctx, at: CGPoint(x: 14, y: 30), t: t, seed: 1, celebrating: celebrating, size: 18, still: still)
  }
}

#Preview {
  TimelineView(.animation) { context in
    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100)
    VStack(spacing: 24) {
      HStack(spacing: 0) {
        PhoneOwl(t: t, size: 110)
        PhoneOwl(t: t, celebrating: true, facing: -1, size: 110)
      }
      HStack(spacing: 0) {
        PhoneRaccoon(t: t, size: 120)
        PhoneRaccoon(t: t, running: false, raise: 1, size: 120)
      }
      HStack(spacing: 0) {
        PhoneSpider(t: t, size: 110)
        PhoneSpider(t: t, celebrating: true, size: 110)
      }
    }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(.black)
}
