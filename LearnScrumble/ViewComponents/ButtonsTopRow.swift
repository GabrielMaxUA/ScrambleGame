import SwiftUI

// MARK: - Flow of this file
// The round glass buttons along the top of the game screen.
//   RootView.topRow picks `buttons` (.settings) and passes the current word
//   -> gear: "Open Settings?" alert -> onOpenSettings() -> AppManager.openSettings()
//   -> speaker (right side): SpeechManager reads the current word in the target language.

struct ButtonsTopRow: View {
    @State private var showAlert: Bool = false         // is the confirmation / paywall alert open
    @State private var type: MenuAlert = .settings     // which alert texts to show
    
    let speechManager: SpeechManager                   // reads the word aloud
    let requestModel: RequestModel                     // gives the target language for the voice
    let word: String?                                  // current word; nil = no speaker button
    let onShowPaywall: () -> Void                      // "Unlock" in a paywall alert
    let onOpenSettings: () -> Void                     // was onExitToSettings
    let buttons: MenuButtonsEnum                       // which buttons to show
    var buttonSize: CGFloat = 50                       // 40 on the folded iPhone Duo (FoldLayout.swift)
    
    var body: some View {
        row
        .foldAlert(type.title, isPresented: $showAlert, message: type.message, confirmTitle: type.confirmTitle) {
            switch type {                              // main button: do what the alert asked
            case .settings: onOpenSettings()
            case .wordListLocked, .settingsLocked, .freeWordsDone: onShowPaywall()
            }
        }
        .alertSound(isPresented: showAlert)            // notification sound when the alert opens
    }

    // MARK: - row
    // Gear left, speaker right.
    private var row: some View {
        HStack {
            GlassContainer {                           // left group: their glass can blend on iOS 26
                HStack {
                    switch buttons {
                    case .settings:
                        settingsButton
                    }
                }//hs
            }//glass Container
            Spacer()
            speakerButton                              // speaker on the right, only while a word is on screen
        }
    }

    @ViewBuilder
    private var speakerButton: some View {
        if let word {
            glassButton("speaker.wave.2.fill") {
                speechManager.speak(word, language: requestModel.selectedLanguage.id)
            }
        }
    }
    
    private var settingsButton: some View {
        glassButton("gear") { type = .settings; showAlert = true }   // open for everyone; SettingsView will replace this later
    }
    
    // MARK: - glassButton
    // One round glass button (50×50, 40×40 on the folded Duo) with an SF Symbol icon; runs `action` on tap.
    // Used for every button in this row.
    private func glassButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: buttonSize, height: buttonSize)
                .foregroundStyle(.white)
        }
        .glassCompat(in: .circle)
    }
}

#Preview {
    ButtonsTopRow(
        speechManager: SpeechManager(),
        requestModel: RequestModel(),
        word: "Hummer",
        onShowPaywall: {},
        onOpenSettings: {},
        buttons: .settings)
    .background(.black)
    .environment(\.layoutDirection, .leftToRight)
}
