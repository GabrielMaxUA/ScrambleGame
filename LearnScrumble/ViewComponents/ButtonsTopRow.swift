import SwiftUI

struct ButtonsTopRow: View {
  @Binding var showMenu: Bool
  @State private var showAlert = false
  @State private var type: MenuAlert = .settings
  let speechManager: SpeechManager
  let requestModel: RequestModel
  let showSettings: Bool
  let showStruggle: Bool
  let word: String?
  let onExitToSettings: () -> Void
  let onReviewStruggle: () -> Void

  private var isSingle: Bool { showSettings != showStruggle }   // exactly one action available

  var body: some View {
    HStack {
      GlassEffectContainer {
        HStack {
          if isSingle {
            // one action: show it directly, no chevron
            if showSettings { settingsButton }
            if showStruggle { struggleButton }
          } else {
            // both actions: chevron toggles the pair
            if showMenu {
              settingsButton
              struggleButton.offset(x: -7)
            }
            chevronButton.offset(x: showMenu ? -14 : 0)
          }
        }
      }
      Spacer()
      if let word {
        glassButton("speaker.wave.2.fill") {
          speechManager.speak(word, language: requestModel.selectedLanguage.id)
        }
      }
    }
    .alert(type.title, isPresented: $showAlert) {
      Button("OK") {
        switch type {
        case .settings: onExitToSettings()
        case .reviewStruggle: onReviewStruggle()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(type.message)
    }
  }

  private var settingsButton: some View {
    glassButton("gear") { type = .settings; showAlert = true }
  }

  private var struggleButton: some View {
    glassButton("10.arrow.trianglehead.counterclockwise.hi") { type = .reviewStruggle; showAlert = true }
  }

  private var chevronButton: some View {
    glassButton(showMenu ? "chevron.left" : "chevron.right") {
      withAnimation { showMenu.toggle() }
    }
  }

  private func glassButton(_ icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .frame(width: 50, height: 50)
        .foregroundStyle(.white)
    }
    .glassEffect(.clear, in: .circle)   // on the Button, not the Image, so the container can merge them
  }
}

#Preview {
  ButtonsTopRow(showMenu: .constant(true), speechManager: SpeechManager(), requestModel: RequestModel(), showSettings: false, showStruggle: false, word: "Hello", onExitToSettings: {}, onReviewStruggle: {})
    .background(.black)
}
