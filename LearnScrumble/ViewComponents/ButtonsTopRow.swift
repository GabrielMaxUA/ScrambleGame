import SwiftUI

// MARK: - Flow of this file
// The round glass buttons along the top of the game screen.
//   RootView.topRow picks `buttons` (.back) and passes the current word
//   -> back arrow (left): onBack() -> AppManager.exitToWelcome() — the round ends (every answer is already saved),
//      WelcomeBackView's cards show; Settings is the gear there
//   -> speaker (right side): SpeechManager reads the current word in the target language.

struct ButtonsTopRow: View {
    let speechManager: SpeechManager                   // reads the word aloud
    let requestModel: RequestModel                     // gives the target language for the voice
    let word: String?                                  // current word; nil = no speaker button
    let onBack: () -> Void                             // back to WelcomeBackView (was the gear -> Settings)
    let buttons: MenuButtonsEnum                       // which buttons to show
    var buttonSize: CGFloat = 50                       // 40 on the folded iPhone Duo (FoldLayout.swift)
    
    var body: some View {
        row
    }

    // MARK: - row
    // Back arrow left, speaker right.
    private var row: some View {
        HStack {
            GlassContainer {                           // left group: their glass can blend on iOS 26
                HStack {
                    switch buttons {
                    case .back:
                        backButton
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
    
    private var backButton: some View {
        glassButton("chevron.backward", action: onBack)   // mirrors itself in right-to-left languages
            .accessibilityLabel(Text("Back"))
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
        onBack: {},
        buttons: .back)
    .background(.black)
    .environment(\.layoutDirection, .leftToRight)
}
