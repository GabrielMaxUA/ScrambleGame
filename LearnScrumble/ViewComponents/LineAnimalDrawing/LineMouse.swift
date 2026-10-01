//
//  LineMouse.swift
//  LearnScrumble
//

import SwiftUI

/// A small mouse drawn with lines, sitting and nibbling a wedge of cheese.
/// Reusable anywhere: set its width, colors, and whether it's eating.
///
///     LineMouse()                          // 56pt wide, nibbling
///     LineMouse(width: 100)                // bigger
///     LineMouse(isEating: false)           // just holding the cheese
struct LineMouse: View {
    var width: CGFloat = 56
    var color: Color = .white
    var cheeseColor: Color = .yellow
    var earColor: Color = .pink
    var lineWidth: CGFloat = 1.8
    var isEating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let drawingSize = CGSize(width: 64, height: 56)

    var body: some View {
        TimelineView(.animation(paused: !isEating || reduceMotion)) { timeline in
            let moving = isEating && !reduceMotion
            let t = moving ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100) : 0

            Canvas { context, size in
                context.scaleBy(x: size.width / Self.drawingSize.width,
                                y: size.height / Self.drawingSize.height)
                draw(in: context, time: t, moving: moving)
            }
        }
        .frame(width: width, height: width * Self.drawingSize.height / Self.drawingSize.width)
        .accessibilityHidden(true)                   // decorative — the parent view says what's happening
    }

    private func draw(in context: GraphicsContext, time: Double, moving: Bool) {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

        // nibbling: quick bites in bursts, with short pauses between them
        let isBiting = moving && sin(time * 1.6) > -0.2
        let bite = isBiting ? abs(sin(time * 14)) : 0
        let dx = bite * 1.0                          // head leans forward...
        let dy = bite * 2.5                          // ...and down into the cheese
        func head(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x + dx, y: y + dy) }

        // tail, curling along the ground and up
        var tail = Path()
        tail.move(to: CGPoint(x: 16, y: 48))
        tail.addQuadCurve(to: CGPoint(x: 5, y: 53), control: CGPoint(x: 10, y: 55))
        tail.addQuadCurve(to: CGPoint(x: 3, y: 42), control: CGPoint(x: -1, y: 51))
        context.stroke(tail, with: .color(color), style: style)

        // sitting body and feet
        var bodyShape = Path()
        bodyShape.addEllipse(in: CGRect(x: 14, y: 24, width: 30, height: 28))
        bodyShape.move(to: CGPoint(x: 26, y: 53))
        bodyShape.addLine(to: CGPoint(x: 34, y: 53))
        context.stroke(bodyShape, with: .color(color), style: style)

        // ear — outline with a pink inside
        let earRect = CGRect(x: 28 + dx, y: 3 + dy, width: 12, height: 13)
        context.fill(Path(ellipseIn: earRect.insetBy(dx: 2.5, dy: 2.5)), with: .color(earColor.opacity(0.7)))
        context.stroke(Path(ellipseIn: earRect), with: .color(color), style: style)

        // head — round at the back, pointed at the nose
        var headShape = Path()
        headShape.move(to: head(38, 12))
        headShape.addCurve(to: head(30, 20), control1: head(33.6, 12), control2: head(30, 15.6))
        headShape.addCurve(to: head(38, 28), control1: head(30, 24.4), control2: head(33.6, 28))
        headShape.addQuadCurve(to: head(55, 22), control: head(47, 28))
        headShape.addQuadCurve(to: head(38, 12), control: head(47, 13))
        headShape.closeSubpath()
        context.stroke(headShape, with: .color(color), style: style)

        // whiskers
        var whiskers = Path()
        whiskers.move(to: head(51, 21))
        whiskers.addLine(to: head(60, 18))
        whiskers.move(to: head(51, 23))
        whiskers.addLine(to: head(61, 25))
        context.stroke(whiskers, with: .color(color), style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round))

        // eye and nose
        let eye = head(45, 18)
        let nose = head(55, 22)
        context.fill(Path(ellipseIn: CGRect(x: eye.x - 1.4, y: eye.y - 1.4, width: 2.8, height: 2.8)), with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: nose.x - 1.5, y: nose.y - 1.5, width: 3, height: 3)), with: .color(earColor))

        // cheese wedge with holes (even-odd fill makes the holes see-through)
        var cheese = Path()
        cheese.move(to: CGPoint(x: 43, y: 41))
        cheese.addLine(to: CGPoint(x: 58, y: 41))
        cheese.addLine(to: CGPoint(x: 58, y: 30))
        cheese.closeSubpath()
        cheese.addEllipse(in: CGRect(x: 52, y: 35, width: 3.5, height: 3.5))
        cheese.addEllipse(in: CGRect(x: 48, y: 38, width: 2.2, height: 2.2))
        cheese.addEllipse(in: CGRect(x: 55.2, y: 32, width: 1.8, height: 1.8))
        context.fill(cheese, with: .color(cheeseColor), style: FillStyle(eoFill: true))

        // arm holding the cheese
        var arm = Path()
        arm.move(to: CGPoint(x: 37, y: 35))
        arm.addLine(to: CGPoint(x: 46, y: 37))
        context.stroke(arm, with: .color(color), style: style)
    }
}

#Preview {
    VStack(spacing: 40) {
        LineMouse()
        LineMouse(width: 100)
        LineMouse(isEating: false)
    }
    .padding()
    .background(.black)
}
