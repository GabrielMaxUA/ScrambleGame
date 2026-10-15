//
//  ImageComponent.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

// MARK: - Flow of this file
// The square picture card in MainView, with a lightbulb button for the hint.
//   MainView passes WordVM.image (the current word's picture) and WordVM.hintWord (word in the native language)
//   -> no picture yet: a placeholder icon
//   -> lightbulb tap -> popover with the hint; it closes by itself when the word changes.
//   Tutorial (OnboardingView): onHintToggled reports the hint opening/closing; the lightbulb reports its place for the pointer.

struct ImageComponent: View {
    let image: UIImage?                         // current word's picture; nil = not loaded / failed
    let hint: String                            // the word in the user's native language
    var onHintToggled: (Bool) -> Void = { _ in }   // tutorial only: tells OnboardingService the hint opened (true) / closed (false)
    @State private var showHint = false         // is the hint popover open

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .accessibilityLabel("Picture of the word to spell")
            } else {                                                    // placeholder while there's no picture
                Image(systemName: "person")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.3))
                    .accessibilityLabel("Picture unavailable")
            }
        }
        .frame(maxWidth: 280, maxHeight: 280)
        .aspectRatio(1, contentMode: .fit)                              // always a square card, shrinks on small screens
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {                             // lightbulb in the top-right corner
            hintButton.padding(10)
        }
        .onChange(of: hint) { showHint = false }                        // close a leftover popover when the word changes
        .onChange(of: showHint) { _, shown in onHintToggled(shown) }    // tutorial: hint opened / closed
    }

    private var hintButton: some View {                                 // lightbulb button + its hint popover
        Button {
            showHint = true
        } label: {
            Image(systemName: "lightbulb.max.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)                           // Apple's minimum tap size
        }
        
        .accessibilityLabel("Show hint")
        .anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [.hint: $0] }   // where the lightbulb is, for the tutorial's pointer
        .popover(isPresented: $showHint) {                              // small bubble: "Hint" + the native word
            VStack(spacing: 4) {
                Text("Hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(hint)
                    .font(.headline)
            }
            .padding()
            .presentationCompactAdaptation(.popover)                    // keeps it a small popover even on iPhone
        }
    }
}

#Preview {
    ImageComponent(image: nil, hint: "Word")
        .padding()
        .background(.black)
}
