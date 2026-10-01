//
//  LineOwl.swift
//  LearnScrumble
//

import SwiftUI

/// A wise owl drawn with lines, wearing a graduation cap — the class's examiner.
/// Idle: slow head tilt and blinking. Celebrating: hops and flaps its wings.
///
///     LineOwl()                          // idle, blinking
///     LineOwl(isCelebrating: true)       // hopping and flapping
///     LineOwl(width: 120)                // bigger
struct LineOwl: View {
    var width: CGFloat = 76
    var color: Color = .white
    var beakColor: Color = .orange
    var capFill: Color = .black
    var tasselColor: Color = .yellow
    var lineWidth: CGFloat = 1.8
    var isCelebrating: Bool = false
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let drawingSize = CGSize(width: 60, height: 66)

    var body: some View {
        TimelineView(.animation(paused: !isAnimating || reduceMotion)) { timeline in
            let moving = isAnimating && !reduceMotion
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
        var context = context
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        let celebrating = moving && isCelebrating

        let hop = celebrating ? abs(sin(time * 5)) * 4 : 0                    // little jumps for joy
        let flap = celebrating ? (sin(time * 12) + 1) / 2 : 0                 // 0 = wings down, 1 = wings up
        let tilt = (moving && !isCelebrating) ? sin(time * 0.8) * 5 : 0       // curious head tilt while idle
        let blinking = moving && !celebrating && time.truncatingRemainder(dividingBy: 3.5) < 0.15
        let tasselSwing = celebrating ? sin(time * 8) * 2.5 : sin(time * 1.5) * 0.8

        // hop and tilt the whole owl around its middle
        context.translateBy(x: 30, y: 40 - hop)
        context.rotate(by: .degrees(tilt))
        context.translateBy(x: -30, y: -40)

        func lerp(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * flap, y: a.y + (b.y - a.y) * flap)
        }
        func mirror(_ p: CGPoint) -> CGPoint { CGPoint(x: Self.drawingSize.width - p.x, y: p.y) }

        var owl = Path()

        // wings — folded at the sides, raised when flapping
        for side in [false, true] {
            let place: (CGPoint) -> CGPoint = side ? mirror : { $0 }
            let tip = lerp(CGPoint(x: 12, y: 54), CGPoint(x: 1, y: 28))
            let control = lerp(CGPoint(x: 5, y: 42), CGPoint(x: 2, y: 40))
            owl.move(to: place(CGPoint(x: 15, y: 31)))
            owl.addQuadCurve(to: place(tip), control: place(control))
            owl.addQuadCurve(to: place(CGPoint(x: 17, y: 50)), control: place(CGPoint(x: 13, y: 46)))
        }

        // round body
        owl.addEllipse(in: CGRect(x: 12, y: 18, width: 36, height: 42))

        // ear tufts
        owl.move(to: CGPoint(x: 15, y: 22))
        owl.addLine(to: CGPoint(x: 13, y: 12))
        owl.addLine(to: CGPoint(x: 21, y: 18))
        owl.move(to: mirror(CGPoint(x: 15, y: 22)))
        owl.addLine(to: mirror(CGPoint(x: 13, y: 12)))
        owl.addLine(to: mirror(CGPoint(x: 21, y: 18)))

        // big round eyes
        owl.addEllipse(in: CGRect(x: 16, y: 24, width: 13, height: 13))
        owl.addEllipse(in: CGRect(x: 31, y: 24, width: 13, height: 13))

        // belly feathers
        for (x, y) in [(24.0, 44.0), (32.0, 44.0), (28.0, 49.0)] {
            owl.move(to: CGPoint(x: x, y: y))
            owl.addLine(to: CGPoint(x: x + 2, y: y + 2))
            owl.addLine(to: CGPoint(x: x + 4, y: y))
        }

        // feet — three little toes each
        for x in [23.0, 37.0] {
            for toe in [-2.0, 0, 2] {
                owl.move(to: CGPoint(x: x, y: 59))
                owl.addLine(to: CGPoint(x: x + toe, y: 63))
            }
        }
        context.stroke(owl, with: .color(color), style: style)

        // pupils, or closed eyelids mid-blink
        for x in [22.5, 37.5] {
            if blinking {
                var lid = Path()
                lid.move(to: CGPoint(x: x - 5, y: 30.5))
                lid.addLine(to: CGPoint(x: x + 5, y: 30.5))
                context.stroke(lid, with: .color(color), style: style)
            } else {
                context.fill(Path(ellipseIn: CGRect(x: x - 2.8, y: 27.7, width: 5.6, height: 5.6)), with: .color(color))
            }
        }

        // beak
        var beak = Path()
        beak.move(to: CGPoint(x: 28, y: 35))
        beak.addLine(to: CGPoint(x: 32, y: 35))
        beak.addLine(to: CGPoint(x: 30, y: 39.5))
        beak.closeSubpath()
        context.fill(beak, with: .color(beakColor))

        // graduation cap — board, then the tassel hanging off one corner
        var board = Path()
        board.move(to: CGPoint(x: 17, y: 15))
        board.addLine(to: CGPoint(x: 30, y: 9))
        board.addLine(to: CGPoint(x: 43, y: 15))
        board.addLine(to: CGPoint(x: 30, y: 21))
        board.closeSubpath()
        context.fill(board, with: .color(capFill))
        context.stroke(board, with: .color(color), style: style)

        var tassel = Path()
        tassel.move(to: CGPoint(x: 30, y: 15))
        tassel.addLine(to: CGPoint(x: 42, y: 15))
        tassel.addLine(to: CGPoint(x: 42 + tasselSwing, y: 22))
        context.stroke(tassel, with: .color(tasselColor), style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round))
        context.fill(Path(roundedRect: CGRect(x: 40.5 + tasselSwing, y: 21.5, width: 3, height: 5), cornerRadius: 1.2),
                     with: .color(tasselColor))
    }
}

#Preview {
    HStack(spacing: 40) {
        LineOwl()
        LineOwl(isCelebrating: true)
    }
    .padding()
    .background(.black)
}
