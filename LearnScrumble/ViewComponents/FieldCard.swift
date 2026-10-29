//
//  FieldCard.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI

// MARK: - Flow of this file
// Titled card used across the app's forms — same look as EntryView's fieldCard.
//   EntryView / SettingsView: FieldCard(title:, icon:) { any content }
//   -> label with icon on top, the content inside a rounded translucent box below.

struct FieldCard<Content: View>: View {
  let title: LocalizedStringKey            // card heading, translated through the string catalog
  let icon: String                         // SF Symbol name shown before the title
  let content: Content                     // whatever the screen puts inside (picker, slider, text…)
  
  // MARK: - init
  // Takes the title, icon and a @ViewBuilder closure, and builds the content once from that closure.
  init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.icon = icon
    self.content = content()
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon)                       // heading above the box
        .font(.subheadline.weight(.semibold))
        .singleLine()                                       // long translations shrink instead of wrapping
        .foregroundStyle(.white.opacity(0.7))
      content                                               // the box itself
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
          RoundedRectangle(cornerRadius: 14)
            .stroke(.white.opacity(0.2), lineWidth: 1)      // thin border
        }
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    FieldCard(title: "I speak", icon: "person.wave.2") {
      Text(verbatim: "English")                        // any content works inside the card
        .foregroundStyle(.white)
    }
    FieldCard(title: "Audio", icon: "speaker.wave.2") {
      Text(verbatim: "Speech speed")
        .foregroundStyle(.white)
    }
  }
  .padding()
  .frame(maxHeight: .infinity)
  .background(.black)
}
