//
//  ButtonModifier.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import SwiftUI

// MARK: - Flow of this file
// One glass look for buttons on every iOS version.
//   Any view: .glassCompat(in: .circle / .capsule / RoundedRectangle(...))
//   -> ButtonModifier -> iOS 26+: real Liquid Glass; iOS 18–25: translucent material + thin border.
//   GlassContainer wraps groups of glass buttons (ButtonsTopRow) so iOS 26 can merge their glass.

/// Real glass on iOS 26+, a translucent shape with a thin border on iOS 18–25.
struct ButtonModifier<S: Shape>: ViewModifier {
  let shape: S                                                   // circle, capsule, rounded rect — whatever the button uses
  var interactive = false                                        // NEW — true for glass that reacts to touch (iOS 26 only)

  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content.glassEffect(interactive ? .clear.interactive() : .clear, in: shape)   // CHANGED
    } else {
      content                                                    // older iOS: imitate glass
        .background(.ultraThinMaterial, in: shape)
        .overlay { shape.stroke(.white.opacity(0.2), lineWidth: 1) }
    }
  }
}

extension View {
  // MARK: - glassCompat(in:interactive:)
  // CHANGED — full form: pass interactive: true for glass that reacts to touch on iOS 26.
  func glassCompat<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
    modifier(ButtonModifier(shape: shape, interactive: interactive))
  }
}

/// GlassEffectContainer on iOS 26+, just the content on older versions (there is no glass to merge).
struct GlassContainer<Content: View>: View {
  private let content: Content                                   // the glass buttons inside

  // MARK: - init
  // Builds the content once from the @ViewBuilder closure.
  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    if #available(iOS 26, *) {
      GlassEffectContainer { content }                           // lets neighbouring glass shapes blend together
    } else {
      content
    }
  }
}

extension View {
  // MARK: - glassCompat(in:)
  // Short form: .glassCompat(in: .circle) — same as above with interactive: false.
  func glassCompat<S: Shape>(in shape: S) -> some View {
    modifier(ButtonModifier(shape: shape))
  }
}

#Preview {
  VStack(spacing: 20) {
    Image(systemName: "gear")
      .frame(width: 50, height: 50)
      .glassCompat(in: .circle)

    Text("Play more!")
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
      .glassCompat(in: .capsule)
  }
  .foregroundStyle(.white)
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(.black)
}
