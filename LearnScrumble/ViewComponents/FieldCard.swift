//
//  FieldCard.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI

/// Titled card used across the app's forms — same look as EntryView's fieldCard.
struct FieldCard<Content: View>: View {
  let title: LocalizedStringKey
  let icon: String
  let content: Content
  
  init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.icon = icon
    self.content = content()
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: icon)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))
      content
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
          RoundedRectangle(cornerRadius: 14)
            .stroke(.white.opacity(0.2), lineWidth: 1)
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
