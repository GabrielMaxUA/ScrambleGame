//
//  FoldLayout.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-30.
//

import SwiftUI

// MARK: - Flow of this file
// The opened iPhone Duo (iOS 27.1+): its big inner screen folds across the middle, so pop-ups go on one half instead
// of across the fold. RootView reads the screen size (onGeometryChange) and passes FoldLayout down the environment:
//   nil         -> any phone, or the Duo folded: everything as usual, system alerts
//   .sideBySide -> opened and wider than tall: pop-ups on the RIGHT half (where the main hand is)
//   .stacked    -> opened and taller than wide: pop-ups on the TOP half (over the picture)
// UIHinge (iOS 27.1) says whether the hinge is open, not where the fold is, so the size decides: both sides at least
// 600 pt, which no single iPhone screen is.
//   .foldAlert(...)  -> the app's alerts: a system alert on phones; on the opened Duo our own card on that half
//                       (FoldAlertCenter -> RootView shows FoldAlertCard)
//   PopupHalf        -> full-screen pop-ups (AnswerResultView, ErrorView): the whole screen dims, the content sits on
//                       that half
// MainView.splitLayout uses the same FoldLayout for the game itself (picture on one half, letters on the other).

enum FoldLayout {
  case sideBySide                                                  // opened, wider than tall: left | right
  case stacked                                                     // opened, taller than wide: top / bottom

  static func from(_ size: CGSize) -> FoldLayout? {                // nil = not an opened iPhone Duo
    guard min(size.width, size.height) >= 600 else { return nil }
    return size.width > size.height ? .sideBySide : .stacked
  }

  // MARK: - topButtonsPadding(_:safeTop:)
  // The round top buttons (settings, sound): RootView works this out once and passes it down (\.topButtonsPadding).
  //   opened, side by side -> a row, in from the big round corners, level with the system's clock and Wi-Fi ring in
  //                           the top right (its centre is about 77 pt down; the buttons are 50 pt)
  //   opened, stacked      -> a row, in from the corners, just under the status bar
  //   folded Duo           -> its outer screen shows the front camera, the clock and the Wi-Fi ring in a column on the
  //                           right, outside the app's safe area (safe area top 0) (.folded): a row like a phone's,
  //                           in from the top edge, with smaller 40 pt buttons so the short screen keeps more room
  //                           for the picture; the side column stays empty (no taps near the camera or the Wi-Fi
  //                           ring, and none where the thumb rests). MainView shows the "unfold" card for answers
  //                           that don't fit this screen.
  //   phones               -> nil: as before (16 / 0 in RootView's top row, 20 / 8 for WelcomeBackView's gear)
  static func topButtonsPadding(_ layout: FoldLayout?, safeTop: CGFloat) -> TopButtonsPadding? {
    switch layout {
    case .sideBySide: TopButtonsPadding(horizontal: 36, top: 52)
    case .stacked: TopButtonsPadding(horizontal: 36, top: 12)
    case nil: safeTop < 20 ? .folded : nil
    }
  }
}

struct TopButtonsPadding: Equatable {
  var horizontal: CGFloat
  var top: CGFloat
  var isFolded = false                                             // the folded Duo's outer screen
  var buttonSize: CGFloat = 50                                     // round buttons; 40 on the folded Duo

  static let folded = TopButtonsPadding(horizontal: 16, top: 12, isFolded: true, buttonSize: 40)
}

private struct FoldLayoutKey: EnvironmentKey {
  static let defaultValue: FoldLayout? = nil
}

private struct TopButtonsPaddingKey: EnvironmentKey {
  static let defaultValue: TopButtonsPadding? = nil
}

extension EnvironmentValues {
  var foldLayout: FoldLayout? {                                    // set by RootView from the screen size
    get { self[FoldLayoutKey.self] }
    set { self[FoldLayoutKey.self] = newValue }
  }
  var topButtonsPadding: TopButtonsPadding? {                      // set by RootView (FoldLayout.topButtonsPadding)
    get { self[TopButtonsPaddingKey.self] }
    set { self[TopButtonsPaddingKey.self] = newValue }
  }
}

// MARK: - PopupHalf
// Puts a pop-up on the half of the opened Duo where people look and tap: the right half side by side (the physical
// right, also in right-to-left languages), the top half stacked. Without a fold it's just the content.
struct PopupHalf<Content: View>: View {
  let layout: FoldLayout?
  @ViewBuilder var content: Content
  @Environment(\.layoutDirection) private var layoutDirection

  var body: some View {
    if let layout {
      GeometryReader { geo in
        let sideBySide = layout == .sideBySide
        content
          .frame(width: sideBySide ? geo.size.width / 2 : geo.size.width,
                 height: sideBySide ? geo.size.height : geo.size.height / 2)
          .frame(maxWidth: .infinity, maxHeight: .infinity,
                 alignment: sideBySide ? (layoutDirection == .rightToLeft ? .leading : .trailing) : .top)
      }
    } else {
      content
    }
  }
}

// MARK: - FoldAlertCenter
// The one alert card on screen on the opened Duo. .foldAlert puts it here; RootView shows it; a button tap runs the
// action and clears it.
@Observable
final class FoldAlertCenter {
  static let shared = FoldAlertCenter()

  struct Alert {
    let token: UUID                                                // which .foldAlert showed it
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let confirmTitle: LocalizedStringKey
    let confirmRole: ButtonRole?
    let hasCancel: Bool
    let onConfirm: () -> Void
    let onClose: () -> Void                                        // sets the caller's isPresented back to false
  }

  var current: Alert?
}

// MARK: - foldAlert
// Every alert in the app: a title, an optional message, one main button and usually Cancel.
// No fold: the normal system alert. Opened Duo: FoldAlertCard on the right / top half (the system would put it anywhere,
// sometimes across the fold). Both are always attached, so turning or folding the phone keeps the alert open.
private struct FoldAlert: ViewModifier {
  let title: LocalizedStringKey
  let message: LocalizedStringKey?
  let confirmTitle: LocalizedStringKey
  let confirmRole: ButtonRole?
  let hasCancel: Bool
  @Binding var isPresented: Bool
  let action: () -> Void
  @Environment(\.foldLayout) private var layout
  @State private var token = UUID()

  func body(content: Content) -> some View {
    content
      .alert(title, isPresented: layout == nil ? $isPresented : .constant(false)) {
        Button(confirmTitle, role: confirmRole, action: action)
        if hasCancel { Button("Cancel", role: .cancel) { } }
      } message: {
        if let message { Text(message) }
      }
      .onChange(of: isPresented) { _, shown in showCard(shown) }
      .onChange(of: layout == nil) { _, _ in showCard(isPresented) }   // opened or folded while the alert is up
  }

  private func showCard(_ shown: Bool) {
    let center = FoldAlertCenter.shared
    if shown, layout != nil {
      center.current = .init(token: token, title: title, message: message, confirmTitle: confirmTitle,
                             confirmRole: confirmRole, hasCancel: hasCancel, onConfirm: action,
                             onClose: { isPresented = false })
    } else if center.current?.token == token {
      center.current = nil
    }
  }
}

extension View {
  func foldAlert(_ title: LocalizedStringKey, isPresented: Binding<Bool>, message: LocalizedStringKey? = nil,
                 confirmTitle: LocalizedStringKey, confirmRole: ButtonRole? = nil, hasCancel: Bool = true,
                 action: @escaping () -> Void) -> some View {
    modifier(FoldAlert(title: title, message: message, confirmTitle: confirmTitle, confirmRole: confirmRole,
                       hasCancel: hasCancel, isPresented: isPresented, action: action))
  }
}

// MARK: - FoldAlertCard
// Our alert on the opened Duo: dims the whole screen, the card on the right / top half. Cancel or the main button
// close it (onClose), the main button runs its action first.
struct FoldAlertCard: View {
  let alert: FoldAlertCenter.Alert
  let layout: FoldLayout

  var body: some View {
    ZStack {
      Color.black.opacity(0.55)
        .ignoresSafeArea()
        .onTapGesture { }                                          // blocks taps behind, like a system alert
      PopupHalf(layout: layout) {
        VStack(spacing: 14) {
          Text(alert.title)
            .font(.headline)
          if let message = alert.message {
            Text(message)
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.75))
          }
          HStack(spacing: 12) {
            if alert.hasCancel {
              button("Cancel", role: .cancel) { }
            }
            button(alert.confirmTitle, role: alert.confirmRole, action: alert.onConfirm)
          }
          .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: 340)
        .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.15), lineWidth: 1) }
        .padding(24)
      }
    }
    .transition(.opacity)
  }

  private func button(_ title: LocalizedStringKey, role: ButtonRole?, action: @escaping () -> Void) -> some View {
    Button {
      alert.onClose()
      FoldAlertCenter.shared.current = nil
      action()
    } label: {
      Text(title)
        .font(.body.weight(role == .cancel ? .regular : .semibold))
        .foregroundStyle(role == .destructive ? .red : .white)
        .singleLine()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
    .glassCompat(in: .capsule, interactive: true)
  }
}

// MARK: - FoldedDuo
// The folded iPhone Duo's outer screen (TopButtonsPadding.isFolded). iOS keeps its camera, clock and Wi-Fi ring in a
// column on the physical right and reserves that side as safe area; the app uses the full width anyway (RootView) and
// follows one layout on every screen:
//   - the screen's round buttons (back, speaker, settings, close) go in that column, under the Wi-Fi ring, one below
//     the other (SideButtons)
//   - the screen's title sits on the line of the first button: its middle level with the button's middle (titleTop)
//   - what runs the full width starts below the column's top part (clock, ring and buttons), so nothing runs under it
enum FoldedDuo {
  static let buttonSize: CGFloat = 40              // as TopButtonsPadding.folded
  static let columnTop: CGFloat = 162              // the first button's top: the Wi-Fi ring ends about 150 pt down
  static let columnInset: CGFloat = 28             // from the physical right edge: centred under the ring (48 − 40 / 2)
  static let buttonGap: CGFloat = 10

  static var firstButtonMid: CGFloat { columnTop + buttonSize / 2 }
  // How far a title stays from each edge: the column and its gap (as the cards, columnRoom), on both sides so a
  // centred title stays centred. Counted from inside the screens' usual 20 pt margin.
  static let titleSideRoom: CGFloat = columnInset + buttonSize + columnInset - 20
  // How much narrower something beside the column gets: the column plus a gap as wide as the column's own gap to the
  // screen edge (columnInset), counted from inside the screens' usual 20 pt margin.
  static let columnRoom: CGFloat = columnInset + buttonSize + columnInset - 20
  // Where the column ends: the Wi-Fi ring (about 150 pt down) or the screen's lowest button, plus a small gap.
  static func columnBottom(buttons: Int) -> CGFloat {
    (buttons == 0 ? 150 : buttonsBottom(buttons)) + 8
  }

  // The bottom of `count` side buttons: full-width content starts below it.
  static func buttonsBottom(_ count: Int) -> CGFloat {
    columnTop + CGFloat(count) * buttonSize + CGFloat(max(0, count - 1)) * buttonGap
  }

  // The top padding for a header whose title (in `style`, at the user's text size) comes after `above` points of other
  // header content (an owl, an icon…): the title's middle lands on the first button's middle. Worked out, not
  // measured — measuring and moving a header made it redraw in a loop.
  static func titleTop(above: CGFloat = 0, style: UIFont.TextStyle = .largeTitle) -> CGFloat {
    max(0, firstButtonMid - above - UIFont.preferredFont(forTextStyle: style).lineHeight / 2)
  }
}

// MARK: - SideButtons
// The folded Duo's side column: the buttons one below the other, under the Wi-Fi ring, on the physical right in every
// language (the stack itself still follows the language, so a back chevron keeps pointing the right way).
struct SideButtons<Content: View>: View {
  @ViewBuilder var content: Content
  @Environment(\.layoutDirection) private var layoutDirection

  var body: some View {
    let rtl = layoutDirection == .rightToLeft
    VStack(spacing: FoldedDuo.buttonGap) { content }
      .padding(rtl ? .leading : .trailing, FoldedDuo.columnInset)
      .padding(.top, FoldedDuo.columnTop)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: rtl ? .topLeading : .topTrailing)
      .ignoresSafeArea()
  }
}

// MARK: - Flowing around the side column
// Folded Duo: what scrolls past the side column flows around it like water, instead of jumping narrower: the closer
// a point is to the lowest button, the more it gives way, up to the column's full width (FoldedDuo.columnRoom) beside
// it. Worked out from the scroll position every frame (no timed animation), so it moves exactly with the finger.
extension FoldedDuo {
  static let flowFillet: CGFloat = 24              // the small rounding where the curve meets the card's own edge

  // How far a point at screen height `y` gives way around the side column. The edge keeps the same gap (columnInset,
  // as the column to the screen edge) everywhere: straight beside the column, then around the lowest button (or the
  // Wi-Fi ring) on a circle with the button's centre, then a small fillet where that circle meets the card's own
  // edge. Measured from the card's usual trailing edge (the screen's 20 pt margin). No corners anywhere.
  static func flowIndent(at y: CGFloat, buttons: Int) -> CGFloat {
    let c = columnInset + buttonSize / 2 - 20                     // the button's centre, inside the card's usual edge
    let R = buttonSize / 2 + columnInset                           // the curve: the button plus the gap
    let f = flowFillet
    let d = y - ((buttons == 0 ? 150 : buttonsBottom(buttons)) - buttonSize / 2)   // below the button's centre
    let filletMid = ((R + f) * (R + f) - (c - f) * (c - f)).squareRoot()   // the fillet's centre (and the curve's end)
    let touch = filletMid * R / (R + f)                            // where the circle hands over to the fillet
    if d <= 0 { return c + R }                                     // beside the column: columnRoom
    if d < touch { return c + (R * R - d * d).squareRoot() }
    if d < filletMid { let e = d - filletMid; return f - (f * f - e * e).squareRoot() }
    return 0
  }
}

// A rounded card whose trailing edge bends around the side column (FoldedDuo.flowIndent). `top` is the card's top in
// screen coordinates; nil = a plain rounded rectangle (not the folded Duo). The bend is on the physical right in
// every language (`rtl` mirrors it).
struct FlowCardShape: Shape {
  var top: CGFloat?
  var buttons: Int
  var rtl: Bool
  var radius: CGFloat = 14

  func path(in rect: CGRect) -> Path {
    let w = rect.width, h = rect.height, r = min(radius, h / 2)
    guard let top, FoldedDuo.flowIndent(at: top, buttons: buttons) > 0.5 else {
      return RoundedRectangle(cornerRadius: radius).path(in: rect)
    }
    let edge = { (y: CGFloat) in w - FoldedDuo.flowIndent(at: top + y, buttons: buttons) }   // the trailing edge at height y
    let slope = { (y: CGFloat) in min(max(edge(y + 1) - edge(y), -2), 2) }   // sideways per point down (kept gentle for the corners)
    let k: CGFloat = 0.5523                                        // a quarter circle from a cubic curve
    // The corners keep the usual rounding and meet the curve in its own direction: no point where they join.
    let tr = r
    var p = Path()
    p.move(to: CGPoint(x: r, y: 0))
    p.addLine(to: CGPoint(x: edge(tr) - tr, y: 0))
    p.addCurve(to: CGPoint(x: edge(tr), y: tr),
               control1: CGPoint(x: edge(tr) - tr + tr * k, y: 0),
               control2: CGPoint(x: edge(tr) - slope(tr) * tr * k, y: tr - tr * k))
    var y = tr
    while y < h - r {                                              // the bend, a point every 2 pt
      y = min(y + 2, h - r)
      p.addLine(to: CGPoint(x: edge(y), y: y))
    }
    p.addCurve(to: CGPoint(x: edge(h - r) - r, y: h),              // the bottom trailing corner, in the bend's direction too
               control1: CGPoint(x: edge(h - r) + slope(h - r) * r * k, y: h - r + r * k),
               control2: CGPoint(x: edge(h - r) - r + r * k, y: h))
    p.addLine(to: CGPoint(x: r, y: h))
    p.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
    p.addLine(to: CGPoint(x: 0, y: r))
    p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
    p.closeSubpath()
    let place = rtl ? CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: rect.maxX, ty: rect.minY)
                    : CGAffineTransform(translationX: rect.minX, y: rect.minY)
    return p.applying(place)
  }
}

// Folded Duo: text (or anything without a card outline) gives way around the side column the same way: trailing
// padding of FoldedDuo.flowIndent at its own top edge. Watches only its own top and changes only its width, so it
// can't move itself. The screen says how many buttons its column has (\.foldedSideButtons). Elsewhere it does nothing.
private struct ClearsSideColumn: ViewModifier {
  @Environment(\.topButtonsPadding) private var topButtons
  @Environment(\.foldedSideButtons) private var buttons
  @Environment(\.layoutDirection) private var layoutDirection
  @State private var top: CGFloat = .greatestFiniteMagnitude

  func body(content: Content) -> some View {
    if topButtons?.isFolded == true {
      content
        .padding(layoutDirection == .rightToLeft ? .leading : .trailing, FoldedDuo.flowIndent(at: top, buttons: buttons))   // the physical right
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top = $0 }
    } else {
      content
    }
  }
}

private struct FoldedSideButtonsKey: EnvironmentKey {
  static let defaultValue = 0
}

extension EnvironmentValues {
  var foldedSideButtons: Int {                                     // how many buttons the folded Duo's side column has
    get { self[FoldedSideButtonsKey.self] }
    set { self[FoldedSideButtonsKey.self] = newValue }
  }
}

// MARK: - FlowCard
// A card's fill and border in FlowCardShape, so on the folded Duo its trailing edge flows around the side column as it
// scrolls past. What's inside flows row by row: each row gives way at its own height (clearsSideColumn on the rows),
// so the card's content follows its outline. Elsewhere a plain rounded rectangle, exactly as before.
private struct FlowCard<Fill: ShapeStyle>: ViewModifier {
  let fill: Fill
  let radius: CGFloat
  let stroke: Color?
  let lineWidth: CGFloat
  @Environment(\.topButtonsPadding) private var topButtons
  @Environment(\.foldedSideButtons) private var buttons
  @Environment(\.layoutDirection) private var layoutDirection
  @State private var top: CGFloat = .greatestFiniteMagnitude

  func body(content: Content) -> some View {
    let folded = topButtons?.isFolded == true
    let shape = FlowCardShape(top: folded ? top : nil, buttons: buttons, rtl: layoutDirection == .rightToLeft, radius: radius)
    content
      .background(fill, in: shape)
      .overlay { if let stroke { shape.stroke(stroke, lineWidth: lineWidth) } }
      .contentShape(shape)
      .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { if folded { top = $0 } }
  }
}

extension View {
  // A card background that flows around the folded Duo's side column (FlowCard).
  func flowCard<Fill: ShapeStyle>(_ fill: Fill, radius: CGFloat, stroke: Color? = nil, lineWidth: CGFloat = 1) -> some View {
    modifier(FlowCard(fill: fill, radius: radius, stroke: stroke, lineWidth: lineWidth))
  }

  // Folded Duo: gives way around the side column as it scrolls past (ClearsSideColumn).
  func clearsSideColumn() -> some View {
    modifier(ClearsSideColumn())
  }

  // Folded Duo: keeps a title clear of the side column. `edges` .horizontal for a centred title, .trailing for one
  // that starts at the leading edge.
  func foldedTitle(_ folded: Bool, edges: Edge.Set = .horizontal) -> some View {
    padding(edges, folded ? FoldedDuo.titleSideRoom : 0)
  }

  // Folded Duo: under the side column too (RootView does this for every screen).
  func foldedFullWidth(_ folded: Bool) -> some View {
    ignoresSafeArea(.container, edges: folded ? .horizontal : [])
  }
}
