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
  @FocusState private var professionFocused: Bool                 // passed into ProfessionPicker so the raccoon and the button can react to typing
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var raccoonX: CGFloat = -600                          // raccoon's horizontal position relative to the button center
  @State private var raccoonArrived = false
  @State private var raccoonHidden = true                              // off-screen: no need to animate
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
  private var raccoonOffscreen: CGFloat { buttonWidth / 2 + 140 }  // far enough that the whole raccoon (and its arm) is past the screen edge
  
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
      if !active { raccoonLeaves() }                                // leave right away when the form becomes incomplete
      else if !professionFocused { raccoonArrives() }               // arrive only when the user isn't typing
    }
    .onChange(of: professionFocused) { _, focused in
      if !focused && canStart { raccoonArrives() }                  // typing finished and the form is ready: raccoon runs in
    }
    .onAppear {
      if canStart { raccoonArrives() }                              // restored profession: raccoon runs in right away
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
        ButtonRaccoon(arrived: raccoonArrived, isAnimating: !raccoonHidden)
          .alignmentGuide(.top) { $0[.bottom] - $0.height * 0.04 - 1 } // feet rest on top of the button
          .offset(x: raccoonX)
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
  
  // MARK: - Raccoon
  
  /// Runs in from the left edge and stays on the button, jumping and scratching.
  private func raccoonArrives() {
    raccoonHidden = false
    raccoonArrived = false
    guard !reduceMotion else {                                    // Reduce Motion: just appears, standing still
      raccoonX = 0
      raccoonArrived = true
      return
    }
    withAnimation(.easeOut(duration: 1.3)) {                      // slows down as it reaches the middle
      raccoonX = 0
    } completion: {
      if canStart { raccoonArrived = true }                         // only settle in if the button is still active
    }
  }
  
  /// Gets up and runs off the right edge, then waits off the left edge for next time.
  private func raccoonLeaves() {
    raccoonArrived = false
    guard !reduceMotion else {
      raccoonX = -raccoonOffscreen
      raccoonHidden = true
      return
    }
    withAnimation(.easeIn(duration: 0.9)) {
      raccoonX = raccoonOffscreen
    } completion: {
      guard !canStart else { return }                           // came back while running off — leave it be
      raccoonX = -raccoonOffscreen                                      // jump back to the left, unseen
      raccoonHidden = true
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

/// The raccoon on the Start button. Running in or out: all four legs going. Arrived: excited jumps,
/// then a good scratch behind the ear, over and over. Reduce Motion or off-screen: no redraws at all.
private struct ButtonRaccoon: View {
  let arrived: Bool
  let isAnimating: Bool                      // false while hidden off-screen
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimating || reduceMotion)) { timeline in
      let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
      let scratching = arrived && !reduceMotion && t.truncatingRemainder(dividingBy: 4) >= 2.2 // 2.2s jumping, 1.8s scratching
      let hop: CGFloat = reduceMotion ? 0
        : !arrived ? -abs(sin(t * 11)) * 3                                // little run bounce
        : scratching ? 0 : -abs(sin(t * 6)) * 14                          // big happy jumps
      PhoneRaccoon(t: t, running: !arrived, arm: scratching ? .scratch : .leg, size: 76)
        .offset(y: hop)
    }
  }
}

#Preview {
  EntryView(requestModel: RequestModel(), onSubmit: {})
}

#Preview("Raccoon") {
  VStack(spacing: 40) {
    ButtonRaccoon(arrived: false, isAnimating: true)
    ButtonRaccoon(arrived: true, isAnimating: true)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(.black)
}
