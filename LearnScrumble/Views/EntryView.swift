// EntryView.swift
import SwiftUI

struct EntryView: View {
  @AppStorage("nativeLanguage") private var nativeLanguage = "en-US"
  @AppStorage("pickedLanguage") private var pickedLanguage = "en-US"
  @AppStorage("pickedProffession") private var pickedProfession = ""
  @Bindable var requestModel: RequestModel
  let onSubmit: () async -> Void
  private let nativePick: LocalizedStringKey = "I speak"
  private let professionPick: LocalizedStringKey = "My profession"
  private let wantToLearnPick: LocalizedStringKey = "I want to learn"
  private let languageAlertMessage: LocalizedStringKey = "Pick two different languages."
  @FocusState private var professionFocused: Bool                 // passed into ProfessionPicker so the dog and the button can react to typing
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var dogX: CGFloat = -600                          // dog's horizontal position relative to the button center
  @State private var dogSitting = false
  @State private var dogHidden = true                              // off-screen: no need to animate
  @State private var buttonWidth: CGFloat = 300
  private let maxProfessionLength = 40                              // keeps prompts short and blocks pasted essays
  private let privacyURL = URL(string: "https://your-site.com/privacy")! // TODO: replace with your real privacy policy URL
  
  private var trimmedProfession: String {
    requestModel.proffession.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  private var sameLanguage: Bool {
    requestModel.nativeLanguage == requestModel.selectedLanguage
  }
  private var canStart: Bool {
    !trimmedProfession.isEmpty && !sameLanguage && !requestModel.isLoading
  }
  private var dogOffscreen: CGFloat { buttonWidth / 2 + 120 }      // far enough that the whole dog is past the screen edge
  
  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        header
        
        VStack(spacing: 20) {
          languageField(title: nativePick, icon: "person.wave.2", selection: $requestModel.nativeLanguage)
          
          FieldCard(title: professionPick, icon: "briefcase") {
            ProfessionPicker(requestModel: requestModel, isFocused: $professionFocused)
          }
          
          languageField(title: wantToLearnPick, icon: "character.book.closed", selection: $requestModel.selectedLanguage)
          
          if sameLanguage {
            Label(languageAlertMessage, systemImage: "exclamationmark.circle")
              .font(.footnote)
              .foregroundStyle(.orange)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 42)                                        // room for the top button row RootView places above
      .padding(.bottom, 24)
    }
    .scrollDismissesKeyboard(.interactively)
    .dismissKeyboardOnTap()
    .background(.black)
    .safeAreaInset(edge: .bottom) { footer }                     // button stays pinned above the keyboard / home indicator
    .onChange(of: requestModel.nativeLanguage) { _, new in
      nativeLanguage = new.rawValue
    }
    .onChange(of: requestModel.selectedLanguage) { _, new in
      pickedLanguage = new.rawValue
    }
    .onChange(of: requestModel.proffession) { _, new in
      if new.count > maxProfessionLength {
        requestModel.proffession = String(new.prefix(maxProfessionLength))
      }
      pickedProfession = requestModel.proffession
    }
    .onChange(of: canStart) { _, active in
      if !active { dogLeaves() }                                // leave right away when the form becomes incomplete
      else if !professionFocused { dogArrives() }               // arrive only when the user isn't typing
    }
    .onChange(of: professionFocused) { _, focused in
      if !focused && canStart { dogArrives() }                  // typing finished and the form is ready: dog runs in
    }
    .onAppear {
      if canStart { dogArrives() }                              // restored profession: dog runs in right away
    }
  }
  
  // MARK: - Sections
  
  private var header: some View {
    VStack(spacing: 8) {
      Text("Welcome to LearnScrumble")
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
      Text("Learn the words you actually use at work.")
        .font(.title3)
        .foregroundStyle(.white.opacity(0.7))
    }
    .multilineTextAlignment(.center)
  }
  
  private var footer: some View {
    VStack(spacing: 12) {
      Button {
        professionFocused = false
        requestModel.proffession = trimmedProfession
        Task { await onSubmit() }
      } label: {
        Text("Start Learning")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
      }
      .glassCompat(in: .capsule, interactive: true)
      .disabled(!canStart)
      .opacity(canStart ? 1 : 0.5)
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { buttonWidth = $0 }
      .overlay(alignment: .top) {
        LineDog(pose: dogSitting ? .sitting : .running, isAnimating: !dogHidden)
          .alignmentGuide(.top) { $0[.bottom] - 2 }       // paws rest on top of the button
          .offset(x: dogX)
          .allowsHitTesting(false)                        // never blocks the button
          .environment(\.layoutDirection, .leftToRight)   // always runs left to right, even in RTL languages
      }
      
      VStack(spacing: 4) {
        Text("Words and images are generated by AI and may contain mistakes.")
        Link("Privacy Policy", destination: privacyURL)
          .underline()
      }
      .font(.footnote)
      .foregroundStyle(.white.opacity(0.5))
      .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(.black)
  }
  
  // MARK: - Dog
  
  /// Runs in from the left edge and sits on the button.
  private func dogArrives() {
    dogHidden = false
    dogSitting = false
    guard !reduceMotion else {                                    // Reduce Motion: just appears, sitting
      dogX = 0
      dogSitting = true
      return
    }
    withAnimation(.easeOut(duration: 1.3)) {                      // slows down as it reaches the middle
      dogX = 0
    } completion: {
      if canStart { dogSitting = true }                         // only sit if the button is still active
    }
  }
  
  /// Gets up and runs off the right edge, then waits off the left edge for next time.
  private func dogLeaves() {
    dogSitting = false
    guard !reduceMotion else {
      dogX = -dogOffscreen
      dogHidden = true
      return
    }
    withAnimation(.easeIn(duration: 0.9)) {
      dogX = dogOffscreen
    } completion: {
      guard !canStart else { return }                           // came back while running off — leave it be
      dogX = -dogOffscreen                                      // jump back to the left, unseen
      dogHidden = true
    }
  }
  
  // MARK: - Building blocks
  
  private func languageField(title: LocalizedStringKey, icon: String, selection: Binding<Languages>) -> some View {
    FieldCard(title: title, icon: icon) {
      Picker(title, selection: selection) {
        ForEach(Languages.allCases, id: \.self) { language in
          Text(language.displayName).tag(language)
        }
      }
      .pickerStyle(.menu)
      .tint(.white)
      .labelsHidden()
    }
  }
}

#Preview {
  EntryView(requestModel: RequestModel(), onSubmit: {})
}
