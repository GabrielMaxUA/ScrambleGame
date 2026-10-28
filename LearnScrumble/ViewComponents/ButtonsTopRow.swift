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
    
    var body: some View {
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
            if let word {                              // speaker on the right, only while a word is on screen
                glassButton("speaker.wave.2.fill") {
                    speechManager.speak(word, language: requestModel.selectedLanguage.id)
                }
            }
        }
        .alert(type.title, isPresented: $showAlert) {
            Button(type.confirmTitle) {                // main button: do what the alert asked
                switch type {
                case .settings: onOpenSettings()
                case .wordListLocked, .settingsLocked, .freeWordsDone: onShowPaywall()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(type.message)
        }
        .alertSound(isPresented: showAlert)            // notification sound when the alert opens
    }
    
    private var settingsButton: some View {
        glassButton("gear") { type = .settings; showAlert = true }   // open for everyone; SettingsView will replace this later
    }
    
    // MARK: - glassButton
    // One round 50×50 glass button with an SF Symbol icon; runs `action` on tap.
    // Used for every button in this row.
    private func glassButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 50, height: 50)
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
