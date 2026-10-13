//
//  DismissKeyboardOnTap.swift
//  LearnScrumble
//

import SwiftUI
import UIKit

// MARK: - Flow of this file
// A modifier that hides the keyboard when the user taps outside a text field.
//   EntryView: ScrollView { ... }.dismissKeyboardOnTap()
//   -> tap on empty space -> UIKit asks the active field to give up the keyboard.
// Buttons, pickers and text fields inside still get their taps first.
//
//     ScrollView { ... }
//         .dismissKeyboardOnTap()

struct DismissKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())              // makes empty space tappable too
            .onTapGesture {
                UIApplication.shared.sendAction(    // asks whichever field is active to give up the keyboard
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
    }
}

extension View {
    // MARK: - dismissKeyboardOnTap
    // Shortcut so views can write .dismissKeyboardOnTap() instead of .modifier(DismissKeyboardOnTap()).
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}
