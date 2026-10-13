import SwiftUI

// MARK: - Flow of this file
// The round glass buttons along the top of the game screen.
//   RootView.topRow picks `buttons` (.struggle / .settings / .menu) and passes the current word
//   -> gear: "Open Settings?" alert -> onOpenSettings() -> AppManager.openSettings()
//   -> review: paid -> "Review Problematic Words" alert -> onReviewStruggle(); free -> paywall alert -> onShowPaywall()
//   -> .menu: a chevron folds the gear + review buttons in and out
//   -> speaker (right side): SpeechManager reads the current word in the target language.

struct ButtonsTopRow: View {
    @State private var showMenu: Bool = false          // .menu only: are gear + review unfolded
    @State private var showAlert: Bool = false         // is the confirmation / paywall alert open
    @State private var type: MenuAlert = .settings     // which alert texts to show
    
    let speechManager: SpeechManager                   // reads the word aloud
    let requestModel: RequestModel                     // gives the target language for the voice
    let word: String?                                  // current word; nil = no speaker button
    let direction: Bool                                // true = left-to-right language (decides chevron direction)
    let hasAccess: Bool                    // NEW
    let onShowPaywall: () -> Void          // NEW
    let onOpenSettings: () -> Void          // was onExitToSettings
    let onReviewStruggle: () -> Void                   // starts a struggle review (AppManager)
    let buttons: MenuButtonsEnum                       // which buttons to show
    
    var body: some View {
        HStack {
            GlassContainer {                           // left group: their glass can blend on iOS 26
                HStack {
                    switch buttons {
                    case .struggle:
                        struggleButton
                    case .settings:
                        settingsButton
                    case .menu:
                        if showMenu{                   // unfolded: gear + review slide in next to the chevron
                            settingsButton
                            struggleButton
                                .offset(x: showMenu ? -7 : 0)
                        }
                        chevronButton
                            .offset(x: showMenu ? -14 : 0)
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
                case .reviewStruggle: onReviewStruggle()
                case .subscriptionRequired, .settingsLocked, .dailyLimitReached: onShowPaywall()   // NEW — added .dailyLimitReached
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
    
    private var struggleButton: some View {            // paid: review alert; free: paywall alert
        glassButton("10.arrow.trianglehead.counterclockwise.hi") { type = hasAccess ? .reviewStruggle : .subscriptionRequired; showAlert = true }
    }
    
    private var chevronButton: some View {             // arrow points the way the menu opens, mirrored for right-to-left languages
        if direction {
            glassButton(showMenu ? "chevron.left" : "chevron.right") {
                withAnimation { showMenu.toggle() }
            }
        }
        else {
            glassButton(showMenu ? "chevron.right" : "chevron.left") {
                withAnimation { showMenu.toggle() }
            }
        }
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
        direction: true,
        hasAccess: false,          // false = free user: gear and review show the "Premium feature" alert
        onShowPaywall: {},
        onOpenSettings: {},
        onReviewStruggle: {},
        buttons: .menu)
    .background(.black)
    .environment(\.layoutDirection, .leftToRight)
}
