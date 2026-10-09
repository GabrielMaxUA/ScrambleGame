//
//  ImageComponent.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

struct ImageComponent: View {
    let image: UIImage?
    let hint: String
    @State private var showHint = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .accessibilityLabel("Picture of the word to spell")
            } else {
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
        .overlay(alignment: .topTrailing) {
            hintButton.padding(10)
        }
        .onChange(of: hint) { showHint = false }                        // close a leftover popover when the word changes
    }

    private var hintButton: some View {
        Button {
            showHint = true
        } label: {
            Image(systemName: "lightbulb.max.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)                           // Apple's minimum tap size
        }
        
        .accessibilityLabel("Show hint")
        .popover(isPresented: $showHint) {
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
