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
  //                           right, outside the app's safe area (safe area top 0) (.sideColumn): settings in the
  //                           top-left corner, in from the edge; sound in that column below the Wi-Fi ring (nothing
  //                           can go above the clock: the camera is there). The game starts just below the gear.
  //   phones               -> nil: as before (16 / 0 in RootView's top row, 20 / 8 for WelcomeBackView's gear)
  static func topButtonsPadding(_ layout: FoldLayout?, safeTop: CGFloat) -> TopButtonsPadding? {
    switch layout {
    case .sideBySide: TopButtonsPadding(horizontal: 36, top: 52)
    case .stacked: TopButtonsPadding(horizontal: 36, top: 12)
    case nil: safeTop < 20 ? .sideColumn : nil
    }
  }
}

struct TopButtonsPadding: Equatable {
  var horizontal: CGFloat
  var top: CGFloat
  var isSideColumn = false

  // The folded Duo, measured on the iPhone Duo simulator (Xcode 27.1): the side column's centre is 48 pt from the right
  // edge; the camera is at its top, the clock about 85–99 pt down, the Wi-Fi ring 110–151 pt. Settings: 28 pt in from
  // the left, 20 pt down. Sound (50 pt): centred in the column (23 pt from the right), its top at 166 pt, below the
  // ring. Used with .ignoresSafeArea().
  static let sideColumn = TopButtonsPadding(horizontal: 28, top: 20, isSideColumn: true)
  static let sideColumnSpeakerTrailing: CGFloat = 23
  static let sideColumnSpeakerTop: CGFloat = 166
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
