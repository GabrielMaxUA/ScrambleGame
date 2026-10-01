//
//  LineDog.swift
//  LearnScrumble
//

import SwiftUI

/// A dog drawn with lines, facing right, wearing rectangular glasses.
/// Two poses: running (galloping legs, flapping ear) and sitting
/// (wagging tail, tongue out, panting happily).
///
///     LineDog(pose: .running)
///     LineDog(pose: .sitting, width: 120)
///     LineDog(pose: .sitting, isAnimating: false)   // still
struct LineDog: View {
    enum Pose { case running, sitting }

    var pose: Pose = .sitting
    var width: CGFloat = 80
    var color: Color = .white
    var tongueColor: Color = .pink
    var lineWidth: CGFloat = 1.8
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let drawingSize = CGSize(width: 80, height: 60)

    var body: some View {
        TimelineView(.animation(paused: !isAnimating || reduceMotion)) { timeline in
            let moving = isAnimating && !reduceMotion
            let t = moving ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100) : 0

            Canvas { context, size in
                context.scaleBy(x: size.width / Self.drawingSize.width,
                                y: size.height / Self.drawingSize.height)
                switch pose {
                case .running: drawRunning(in: context, time: t)
                case .sitting: drawSitting(in: context, time: t, moving: moving)
                }
            }
        }
        .frame(width: width, height: width * Self.drawingSize.height / Self.drawingSize.width)
        .accessibilityHidden(true)                   // decorative — the parent view says what's happening
    }

    private var style: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }

    // MARK: - Running

    private func drawRunning(in context: GraphicsContext, time: Double) {
        let step = time * 12
        let bob = abs(sin(step)) * 1.5               // body bounces with each stride
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y - bob) }

        var dog = Path()

        // tail streaming out behind
        dog.move(to: p(19, 28))
        dog.addQuadCurve(to: p(7, 18 + sin(step) * 2), control: p(10, 28))

        // body
        dog.addEllipse(in: CGRect(x: 18, y: 24 - bob, width: 40, height: 16))

        // legs — gallop: back pair and front pair swing opposite each other, joints bend backward
        let legs: [(x: Double, phase: Double, bend: Double)] = [
            (22, .pi, -3), (26, .pi + 0.6, -3),      // back legs
            (50, 0, -2), (54, 0.6, -2),              // front legs
        ]
        for leg in legs {
            let reach = sin(step + leg.phase) * 7
            let lift = max(0, cos(step + leg.phase)) * 3
            let top = p(leg.x, 37)
            let paw = CGPoint(x: leg.x + reach, y: 57 - lift)
            let joint = CGPoint(x: (top.x + paw.x) / 2 + leg.bend, y: (top.y + paw.y) / 2)
            dog.move(to: top)
            dog.addLine(to: joint)
            dog.addLine(to: paw)
        }
        context.stroke(dog, with: .color(color), style: style)

        drawTongue(in: context, dx: 0, dy: -bob, length: 3)
        drawFace(in: context, dx: 0, dy: -bob, earFlap: sin(step) * 2)
    }

    // MARK: - Sitting

    private func drawSitting(in context: GraphicsContext, time: Double, moving: Bool) {
        let breath = moving ? sin(time * 9) : 0      // quick happy panting
        let wag = moving ? sin(time * 14) : 0        // tail sweeping side to side
        let headBob = breath * 0.4

        var dog = Path()

        // tail, wagging along the ground
        dog.move(to: CGPoint(x: 25, y: 50))
        dog.addQuadCurve(to: CGPoint(x: 9, y: 46 + wag * 5), control: CGPoint(x: 15, y: 55))

        // back thigh, and upright body that swells a little with each breath
        dog.addEllipse(in: CGRect(x: 22, y: 34, width: 22, height: 20))
        let chest = breath * 0.6
        dog.addEllipse(in: CGRect(x: 28 - chest / 2, y: 20, width: 26 + chest, height: 34))

        // back paw, front legs and paws
        dog.move(to: CGPoint(x: 30, y: 57))
        dog.addLine(to: CGPoint(x: 41, y: 57))
        dog.move(to: CGPoint(x: 47, y: 46))
        dog.addLine(to: CGPoint(x: 47, y: 57))
        dog.addLine(to: CGPoint(x: 50, y: 57))
        dog.move(to: CGPoint(x: 51, y: 46))
        dog.addLine(to: CGPoint(x: 52, y: 57))
        dog.addLine(to: CGPoint(x: 55, y: 57))
        context.stroke(dog, with: .color(color), style: style)

        // head sits higher and further back than when running
        let dx = -5.5
        let dy = -6 + headBob
        drawTongue(in: context, dx: dx, dy: dy, length: 4 + (breath + 1) * 1.2)
        drawFace(in: context, dx: dx, dy: dy, earFlap: 0)
    }

    // MARK: - Shared face (drawn in running-pose coordinates, shifted by dx/dy)

    private func drawFace(in context: GraphicsContext, dx: Double, dy: Double, earFlap: Double) {
        func f(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x + dx, y: y + dy) }

        var face = Path()

        // head and snout
        face.addEllipse(in: CGRect(x: 54 + dx, y: 8 + dy, width: 16, height: 15))
        face.move(to: f(68, 14))
        face.addLine(to: f(75, 15))
        face.addQuadCurve(to: f(75, 21), control: f(78, 18))
        face.addLine(to: f(67, 22))

        // floppy ear
        face.move(to: f(57, 10))
        face.addQuadCurve(to: f(55 - earFlap, 22), control: f(51, 14))
        face.addQuadCurve(to: f(60, 12), control: f(59, 20))

        // rectangular glasses — lens and the arm going back to the ear
        face.addRoundedRect(in: CGRect(x: 63 + dx, y: 11.5 + dy, width: 8, height: 6),
                            cornerSize: CGSize(width: 1, height: 1))
        face.move(to: f(63, 13.5))
        face.addLine(to: f(57.5, 12.5))

        context.stroke(face, with: .color(color), style: style)

        // eye and nose
        let eye = f(67, 14.5)
        let nose = f(76, 15.5)
        context.fill(Path(ellipseIn: CGRect(x: eye.x - 1.3, y: eye.y - 1.3, width: 2.6, height: 2.6)), with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: nose.x - 1.7, y: nose.y - 1.7, width: 3.4, height: 3.4)), with: .color(color))
    }

    private func drawTongue(in context: GraphicsContext, dx: Double, dy: Double, length: Double) {
        let tongue = Path(roundedRect: CGRect(x: 70 + dx, y: 21 + dy, width: 4, height: length), cornerRadius: 2)
        context.fill(tongue, with: .color(tongueColor))
    }
}

#Preview {
    VStack(spacing: 40) {
        LineDog(pose: .running)
        LineDog(pose: .sitting)
        LineDog(pose: .sitting, width: 140)
    }
    .padding()
    .background(.black)
}
