//
//  SingleLine.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-29.
//

import SwiftUI

// MARK: - Flow of this file
// One rule for labels in cards and rows (Settings, FieldCard, the setup screen, the progress card):
// stay on ONE line, and shrink down to 80% of the font before cutting off with "…".
// Some translations are much longer than English and used to wrap onto a second line and push the layout apart.
// Explanation texts (footnotes, consent text) don't use it — they're meant to wrap.

extension View {
  // MARK: - singleLine
  // One line, text may shrink to 80% to fit.
  func singleLine() -> some View {
    lineLimit(1).minimumScaleFactor(0.8)
  }
}
