//
//  ButtonModifier.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import SwiftUI

/// Real glass on iOS 26+, a translucent shape with a thin border on iOS 18–25.
struct ButtonModifier<S: Shape>: ViewModifier {
  let shape: S                                                   // circle, capsule, rounded rect — whatever the button uses
  var interactive = false                                        // NEW — true for glass that reacts to touch (iOS 26 only)

  func body(content: Content) -> some View {
    if #available(iOS 26, *) {
      content.glassEffect(interactive ? .clear.interactive() : .clear, in: shape)   // CHANGED
    } else {
      content
        .background(.ultraThinMaterial, in: shape)
        .overlay { shape.stroke(.white.opacity(0.2), lineWidth: 1) }
    }
  }
}

extension View {
  func glassCompat<S: Shape>(in shape: S, interactive: Bool = false) -> some View {   // CHANGED
    modifier(ButtonModifier(shape: shape, interactive: interactive))
  }
}

/// GlassEffectContainer on iOS 26+, just the content on older versions (there is no glass to merge).
struct GlassContainer<Content: View>: View {
  private let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    if #available(iOS 26, *) {
      GlassEffectContainer { content }
    } else {
      content
    }
  }
}

extension View {
  func glassCompat<S: Shape>(in shape: S) -> some View {         // short form: .glassCompat(in: .circle)
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
