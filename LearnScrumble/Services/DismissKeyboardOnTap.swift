//
//  DismissKeyboardOnTap.swift
//  LearnScrumble
//

import SwiftUI
import UIKit

/// Tapping anywhere on the view (outside a text field) dismisses the keyboard.
/// Buttons, pickers and text fields inside still get their taps first.
///
///     ScrollView { ... }
///         .dismissKeyboardOnTap()
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
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}
