import SwiftUI

struct ButtonsTopRow: View {
    @State private var showMenu: Bool = false
    @State private var showAlert: Bool = false
    @State private var type: MenuAlert = .settings
    
    let speechManager: SpeechManager
    let requestModel: RequestModel
    let word: String?
    let direction: Bool
    let hasAccess: Bool                    // NEW
    let onShowPaywall: () -> Void          // NEW
    let onOpenSettings: () -> Void          // was onExitToSettings
    let onReviewStruggle: () -> Void
    let buttons: MenuButtonsEnum
    
    var body: some View {
        HStack {
            GlassContainer {
                HStack {
                    switch buttons {
                    case .struggle:
                        struggleButton
                    case .settings:
                        settingsButton
                    case .menu:
                        if showMenu{
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
            if let word {
                glassButton("speaker.wave.2.fill") {
                    speechManager.speak(word, language: requestModel.selectedLanguage.id)
                }
            }
        }
        .alert(type.title, isPresented: $showAlert) {
            Button(type.confirmTitle) {
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
        .alertSound(isPresented: showAlert)
    }
    
    private var settingsButton: some View {
        glassButton("gear") { type = .settings; showAlert = true }   // open for everyone; SettingsView will replace this later
    }
    
    private var struggleButton: some View {
        glassButton("10.arrow.trianglehead.counterclockwise.hi") { type = hasAccess ? .reviewStruggle : .subscriptionRequired; showAlert = true }
    }
    
    private var chevronButton: some View {
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
