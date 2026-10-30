//
//  ImageComponent.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

// MARK: - Flow of this file
// The square picture card in MainView, with a lightbulb button for the hint and a flag to report a wrong picture.
//   MainView passes WordVM.image (the current word's picture) and WordVM.hintWord (word in the native language)
//   -> no picture yet: a placeholder icon
//   -> lightbulb tap -> popover with the hint; it closes by itself when the word changes.
//   -> flag tap (top-left, only when onReport is set) -> "Report this picture?" -> onReport -> WordVM.reportPicture()
//      report = WordVM.pictureReport: .sending dims the picture with a spinner; the outcome shows as a note
//      at the bottom of the card until the word changes. A failed report shows the flag again.
//   Tutorial (OnboardingView): onHintToggled reports the hint opening/closing; the lightbulb reports its place for the pointer.

struct ImageComponent: View {
    let image: UIImage?                         // current word's picture; nil = not loaded / failed
    let hint: String                            // the word in the user's native language
    var onHintToggled: (Bool) -> Void = { _ in }   // tutorial only: tells OnboardingService the hint opened (true) / closed (false)
    var report: PictureReport = .idle           // where this word's picture report stands
    var onReport: (() -> Void)? = nil           // sends the report; nil = no flag (tutorial)
    var maxSide: CGFloat = 280                  // the card's biggest size; larger on an opened iPhone Duo (MainView.splitLayout)
    @State private var showHint = false         // is the hint popover open
    @State private var confirmReport = false    // the "Report this picture?" alert is open

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .accessibilityLabel("Picture of the word to spell")
                    .opacity(report == .sending ? 0.3 : 1)
            } else {                                                    // placeholder while there's no picture
                Image(systemName: "person")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.3))
                    .accessibilityLabel("Picture unavailable")
            }
        }
        .frame(maxWidth: maxSide, maxHeight: maxSide)
        .aspectRatio(1, contentMode: .fit)                              // always a square card, shrinks on small screens
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {                             // lightbulb in the top-right corner
            hintButton.padding(10)
        }
        .overlay(alignment: .topLeading) {                              // flag in the top-left corner
            if onReport != nil, report == .idle || report == .failed {
                reportButton.padding(10)
            }
        }
        .overlay {                                                      // waiting for a new picture
            if report == .sending {
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Drawing a new picture…")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .overlay(alignment: .bottom) {                                  // what happened with the report
            if let note = reportNote {
                Text(note)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.7), in: .capsule)
                    .padding(10)
            }
        }
        .foldAlert("Report this picture?", isPresented: $confirmReport,
                   message: "If the picture doesn't show this word, we'll draw a new one for you and check it for everyone.",
                   confirmTitle: "Report") { onReport?() }
        .onChange(of: hint) { showHint = false }                        // close a leftover popover when the word changes
        .onChange(of: showHint) { _, shown in onHintToggled(shown) }    // tutorial: hint opened / closed
    }

    private var reportNote: LocalizedStringKey? {                       // the note under the picture for each outcome
        switch report {
        case .redrawn:  "Thanks! Here's a new picture. We'll check it for everyone."
        case .received: "Thanks! We'll check this picture."
        case .tooMany:  "Thanks! You've sent many reports today. Try again tomorrow."
        case .failed:   "Couldn't send the report. Please try again."
        case .idle, .sending: nil
        }
    }

    private var reportButton: some View {                               // flag button, asks first
        Button {
            confirmReport = true
        } label: {
            Image(systemName: "flag.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)                                 // same as the lightbulb, so it's easy to spot
                .frame(width: 44, height: 44)                           // Apple's minimum tap size
        }
        .accessibilityLabel("Report a wrong picture")
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
