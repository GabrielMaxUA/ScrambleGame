//
//  Mouse.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import SwiftUI

struct Mouse: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let width = rect.size.width
    let height = rect.size.height
    var transformPath3 = Path()
    transformPath3.move(to: CGPoint(x: 0.04851*width, y: 0.18448*height))
    transformPath3.addCurve(to: CGPoint(x: 0.06395*width, y: 0.19992*height), control1: CGPoint(x: 0.05702*width, y: 0.18448*height), control2: CGPoint(x: 0.06395*width, y: 0.19141*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04851*width, y: 0.21537*height), control1: CGPoint(x: 0.06395*width, y: 0.20844*height), control2: CGPoint(x: 0.05702*width, y: 0.21537*height))
    transformPath3.addCurve(to: CGPoint(x: 0.03307*width, y: 0.19992*height), control1: CGPoint(x: 0.04*width, y: 0.21537*height), control2: CGPoint(x: 0.03307*width, y: 0.20844*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04851*width, y: 0.18448*height), control1: CGPoint(x: 0.03307*width, y: 0.19141*height), control2: CGPoint(x: 0.04*width, y: 0.18448*height))
    transformPath3.closeSubpath()
    transformPath3.move(to: CGPoint(x: 0.04851*width, y: 0.20507*height))
    transformPath3.addCurve(to: CGPoint(x: 0.05366*width, y: 0.19992*height), control1: CGPoint(x: 0.05135*width, y: 0.20507*height), control2: CGPoint(x: 0.05366*width, y: 0.20276*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04851*width, y: 0.19478*height), control1: CGPoint(x: 0.05366*width, y: 0.19709*height), control2: CGPoint(x: 0.05135*width, y: 0.19478*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04336*width, y: 0.19992*height), control1: CGPoint(x: 0.04567*width, y: 0.19478*height), control2: CGPoint(x: 0.04336*width, y: 0.19709*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04851*width, y: 0.20507*height), control1: CGPoint(x: 0.04336*width, y: 0.20276*height), control2: CGPoint(x: 0.04567*width, y: 0.20507*height))
    transformPath3.closeSubpath()
    transformPath3.move(to: CGPoint(x: 0.21643*width, y: 0.09624*height))
    transformPath3.addCurve(to: CGPoint(x: 0.24312*width, y: 0.16117*height), control1: CGPoint(x: 0.24005*width, y: 0.12292*height), control2: CGPoint(x: 0.24903*width, y: 0.14476*height))
    transformPath3.addCurve(to: CGPoint(x: 0.2156*width, y: 0.18284*height), control1: CGPoint(x: 0.23766*width, y: 0.17633*height), control2: CGPoint(x: 0.22154*width, y: 0.18144*height))
    transformPath3.addCurve(to: CGPoint(x: 0.21835*width, y: 0.20493*height), control1: CGPoint(x: 0.21768*width, y: 0.19068*height), control2: CGPoint(x: 0.21835*width, y: 0.19836*height))
    transformPath3.addCurve(to: CGPoint(x: 0.11403*width, y: 0.24707*height), control1: CGPoint(x: 0.21835*width, y: 0.24707*height), control2: CGPoint(x: 0.17*width, y: 0.24707*height))
    transformPath3.addCurve(to: CGPoint(x: 0.00219*width, y: 0.21244*height), control1: CGPoint(x: 0.05594*width, y: 0.24707*height), control2: CGPoint(x: 0.00219*width, y: 0.24287*height))
    transformPath3.addCurve(to: CGPoint(x: 0.03795*width, y: 0.16802*height), control1: CGPoint(x: 0.00219*width, y: 0.19999*height), control2: CGPoint(x: 0.01548*width, y: 0.18354*height))
    transformPath3.addCurve(to: CGPoint(x: 0.03701*width, y: 0.16409*height), control1: CGPoint(x: 0.03758*width, y: 0.16673*height), control2: CGPoint(x: 0.03727*width, y: 0.16541*height))
    transformPath3.addCurve(to: CGPoint(x: 0.03983*width, y: 0.13819*height), control1: CGPoint(x: 0.03523*width, y: 0.15493*height), control2: CGPoint(x: 0.03623*width, y: 0.14572*height))
    transformPath3.addCurve(to: CGPoint(x: 0.05765*width, y: 0.12339*height), control1: CGPoint(x: 0.04368*width, y: 0.13012*height), control2: CGPoint(x: 0.05001*width, y: 0.12487*height))
    transformPath3.addCurve(to: CGPoint(x: 0.08849*width, y: 0.14254*height), control1: CGPoint(x: 0.0697*width, y: 0.12104*height), control2: CGPoint(x: 0.08206*width, y: 0.12894*height))
    transformPath3.addCurve(to: CGPoint(x: 0.13565*width, y: 0.13384*height), control1: CGPoint(x: 0.10511*width, y: 0.13684*height), control2: CGPoint(x: 0.12133*width, y: 0.13384*height))
    transformPath3.addCurve(to: CGPoint(x: 0.21219*width, y: 0.17306*height), control1: CGPoint(x: 0.18236*width, y: 0.13384*height), control2: CGPoint(x: 0.20326*width, y: 0.15262*height))
    transformPath3.addCurve(to: CGPoint(x: 0.23345*width, y: 0.15764*height), control1: CGPoint(x: 0.21475*width, y: 0.17254*height), control2: CGPoint(x: 0.22934*width, y: 0.16916*height))
    transformPath3.addCurve(to: CGPoint(x: 0.20872*width, y: 0.10307*height), control1: CGPoint(x: 0.23788*width, y: 0.14522*height), control2: CGPoint(x: 0.22933*width, y: 0.12635*height))
    transformPath3.addCurve(to: CGPoint(x: 0.18384*width, y: 0.02858*height), control1: CGPoint(x: 0.17672*width, y: 0.06691*height), control2: CGPoint(x: 0.17753*width, y: 0.04261*height))
    transformPath3.addCurve(to: CGPoint(x: 0.22894*width, y: 0), control1: CGPoint(x: 0.19262*width, y: 0.00908*height), control2: CGPoint(x: 0.21594*width, y: 0))
    transformPath3.addCurve(to: CGPoint(x: 0.23409*width, y: 0.00515*height), control1: CGPoint(x: 0.23178*width, y: 0), control2: CGPoint(x: 0.23409*width, y: 0.0023*height))
    transformPath3.addCurve(to: CGPoint(x: 0.22894*width, y: 0.01029*height), control1: CGPoint(x: 0.23409*width, y: 0.00799*height), control2: CGPoint(x: 0.23178*width, y: 0.01029*height))
    transformPath3.addCurve(to: CGPoint(x: 0.19323*width, y: 0.03281*height), control1: CGPoint(x: 0.2203*width, y: 0.01029*height), control2: CGPoint(x: 0.2003*width, y: 0.01709*height))
    transformPath3.addCurve(to: CGPoint(x: 0.21643*width, y: 0.09624*height), control1: CGPoint(x: 0.18596*width, y: 0.04895*height), control2: CGPoint(x: 0.19398*width, y: 0.07089*height))
    transformPath3.closeSubpath()
    transformPath3.move(to: CGPoint(x: 0.11403*width, y: 0.23677*height))
    transformPath3.addCurve(to: CGPoint(x: 0.20805*width, y: 0.20493*height), control1: CGPoint(x: 0.17408*width, y: 0.23677*height), control2: CGPoint(x: 0.20805*width, y: 0.2353*height))
    transformPath3.addCurve(to: CGPoint(x: 0.13565*width, y: 0.14413*height), control1: CGPoint(x: 0.20805*width, y: 0.1772*height), control2: CGPoint(x: 0.1955*width, y: 0.14414*height))
    transformPath3.addCurve(to: CGPoint(x: 0.08736*width, y: 0.15387*height), control1: CGPoint(x: 0.12119*width, y: 0.14413*height), control2: CGPoint(x: 0.10449*width, y: 0.1475*height))
    transformPath3.addLine(to: CGPoint(x: 0.08238*width, y: 0.15572*height))
    transformPath3.addLine(to: CGPoint(x: 0.08069*width, y: 0.15069*height))
    transformPath3.addCurve(to: CGPoint(x: 0.06186*width, y: 0.13327*height), control1: CGPoint(x: 0.0772*width, y: 0.14032*height), control2: CGPoint(x: 0.06939*width, y: 0.13327*height))
    transformPath3.addCurve(to: CGPoint(x: 0.05961*width, y: 0.13349*height), control1: CGPoint(x: 0.0611*width, y: 0.13327*height), control2: CGPoint(x: 0.06036*width, y: 0.13334*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04912*width, y: 0.14262*height), control1: CGPoint(x: 0.05525*width, y: 0.13433*height), control2: CGPoint(x: 0.05153*width, y: 0.13758*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04712*width, y: 0.16213*height), control1: CGPoint(x: 0.04647*width, y: 0.14818*height), control2: CGPoint(x: 0.04576*width, y: 0.15511*height))
    transformPath3.addCurve(to: CGPoint(x: 0.04887*width, y: 0.16826*height), control1: CGPoint(x: 0.04753*width, y: 0.16424*height), control2: CGPoint(x: 0.04812*width, y: 0.16629*height))
    transformPath3.addLine(to: CGPoint(x: 0.05036*width, y: 0.17212*height))
    transformPath3.addLine(to: CGPoint(x: 0.04691*width, y: 0.1744*height))
    transformPath3.addCurve(to: CGPoint(x: 0.01248*width, y: 0.21244*height), control1: CGPoint(x: 0.02313*width, y: 0.19011*height), control2: CGPoint(x: 0.01248*width, y: 0.20483*height))
    transformPath3.addCurve(to: CGPoint(x: 0.11403*width, y: 0.23677*height), control1: CGPoint(x: 0.01248*width, y: 0.23425*height), control2: CGPoint(x: 0.07044*width, y: 0.23677*height))
    transformPath3.closeSubpath()
    path.addPath(transformPath3.applying(CGAffineTransform(a: 4.04748, b: 0, c: 0, d: 4.04748, tx: 0, ty: 0)))
    return path
  }
}
