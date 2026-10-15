//
//  Pointer-up.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-14.
//
import SwiftUI

struct PointerUp: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let width = rect.size.width
    let height = rect.size.height
    var transformPath3 = Path()
    var strokePath2 = Path()
    strokePath2.move(to: CGPoint(x: 0.02203*width, y: 0.0291*height))
    strokePath2.addLine(to: CGPoint(x: 0.02203*width, y: 0.02559*height))
    strokePath2.addLine(to: CGPoint(x: 0.02214*width, y: 0.02537*height))
    strokePath2.addCurve(to: CGPoint(x: 0.02438*width, y: 0.0159*height), control1: CGPoint(x: 0.02361*width, y: 0.02243*height), control2: CGPoint(x: 0.02438*width, y: 0.01919*height))
    strokePath2.addLine(to: CGPoint(x: 0.02438*width, y: 0.0159*height))
    strokePath2.addCurve(to: CGPoint(x: 0.02236*width, y: 0.01357*height), control1: CGPoint(x: 0.02437*width, y: 0.01473*height), control2: CGPoint(x: 0.02351*width, y: 0.01375*height))
    strokePath2.addLine(to: CGPoint(x: 0.01611*width, y: 0.0127*height))
    strokePath2.addLine(to: CGPoint(x: 0.01611*width, y: 0.00449*height))
    strokePath2.addCurve(to: CGPoint(x: 0.01541*width, y: 0.00284*height), control1: CGPoint(x: 0.01611*width, y: 0.00387*height), control2: CGPoint(x: 0.01586*width, y: 0.00327*height))
    strokePath2.addCurve(to: CGPoint(x: 0.01356*width, y: 0.00216*height), control1: CGPoint(x: 0.01493*width, y: 0.00234*height), control2: CGPoint(x: 0.01425*width, y: 0.0021*height))
    strokePath2.addCurve(to: CGPoint(x: 0.01143*width, y: 0.00466*height), control1: CGPoint(x: 0.01231*width, y: 0.00231*height), control2: CGPoint(x: 0.01138*width, y: 0.0034*height))
    strokePath2.addLine(to: CGPoint(x: 0.01143*width, y: 0.01739*height))
    strokePath2.addLine(to: CGPoint(x: 0.0098*width, y: 0.01576*height))
    strokePath2.addCurve(to: CGPoint(x: 0.00811*width, y: 0.015*height), control1: CGPoint(x: 0.00936*width, y: 0.0153*height), control2: CGPoint(x: 0.00875*width, y: 0.01503*height))
    strokePath2.addCurve(to: CGPoint(x: 0.00635*width, y: 0.01572*height), control1: CGPoint(x: 0.00745*width, y: 0.015*height), control2: CGPoint(x: 0.00682*width, y: 0.01526*height))
    strokePath2.addCurve(to: CGPoint(x: 0.00635*width, y: 0.01924*height), control1: CGPoint(x: 0.00539*width, y: 0.0167*height), control2: CGPoint(x: 0.00539*width, y: 0.01826*height))
    strokePath2.addLine(to: CGPoint(x: 0.0126*width, y: 0.02549*height))
    strokePath2.addLine(to: CGPoint(x: 0.0126*width, y: 0.029*height))
    transformPath3.addPath(strokePath2.strokedPath(StrokeStyle(lineWidth: 0.00235*width, lineCap: .butt, lineJoin: .miter, miterLimit: 10)))
    path.addPath(transformPath3.applying(CGAffineTransform(a: 33.33333, b: 0, c: 0, d: 33.33333, tx: 0, ty: 0)))
    return path
  }
}
