// EntryView.swift
import SwiftUI

// MARK: - Flow of this file
// First-launch setup screen (phase .onboarding): native language, profession, language to learn, reminder time.
//   Pickers write straight into RequestModel (nativeLanguage, selectedLanguage, proffession)
//   Reminder card: the time is saved straight to UserDefaults (DailyReminder.timeKey), with the reason shown under it
//   -> onChange copies each into UserDefaults (@AppStorage) so the next launch restores them
//   "Your data" card: what goes to OpenAI + an "I agree" checkbox, saved straight to UserDefaults (AIConsent.key)
//   -> "Start Learning" (only when profession is filled, the two languages differ and "I agree" is ticked)
//   -> onSubmit -> RootView: hasCompletedOnboarding = true, notification permission
//      (DailyReminder books the reminders at the time picked here), AppManager.startGame().
//   A raccoon runs onto the button when the form is ready and runs off when it isn't.

struct EntryView: View {
  @AppStorage("nativeLanguage") private var nativeLanguage = "en-US"         // saved copy of requestModel.nativeLanguage
  @AppStorage("pickedLanguage") private var pickedLanguage = "en-US"         // saved copy of requestModel.selectedLanguage
  @AppStorage("pickedProffession") private var pickedProfession = ""         // saved copy of requestModel.proffession
  @AppStorage(DailyReminder.timeKey) private var reminderMinutes = DailyReminder.defaultMinutes   // reminder time, minutes after midnight (9:00 by default)
  @AppStorage(AIConsent.key) private var consentDate: Double = 0             // when "I agree" was ticked; 0 = not agreed
  @AppStorage(AnalyticsConsent.key) private var shareStatistics = false      // optional analytics consent, off by default
  @Bindable var requestModel: RequestModel                                   // the pickers write into it directly
  let onSubmit: () async -> Void                                             // RootView: mark onboarding done + start the game
  private let nativePick: LocalizedStringKey = "I speak"                     // card titles / warning, translated by the catalog
  private let professionPick: LocalizedStringKey = "My profession"
  private let wantToLearnPick: LocalizedStringKey = "I want to learn"
  private let languageAlertMessage: LocalizedStringKey = "Pick two different languages."
  private let reminderPick: LocalizedStringKey = "Daily reminder"
  private let reminderTimeLabel: LocalizedStringKey = "Remind me at"
  private let reminderReason: LocalizedStringKey = "We'll remind you once a day, only if you haven't played yet."
  private let consentPick: LocalizedStringKey = "Your data"
  @FocusState private var professionFocused: Bool                 // passed into ProfessionPicker so the raccoon and the button can react to typing
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var raccoonX: CGFloat = -600                          // raccoon's horizontal position relative to the button center
  @State private var raccoonArrived = false                             // on the button: jumping/scratching instead of running
  @State private var raccoonHidden = true                              // off-screen: no need to animate
  @State private var buttonWidth: CGFloat = 300                        // measured Start button width — decides how far off-screen is
  private let maxProfessionLength = 40                              // keeps prompts short and blocks pasted essays
  
  private var trimmedProfession: String {                              // profession without leading/trailing spaces
    requestModel.proffession.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  private var sameLanguage: Bool {                                     // native == target: not allowed
    requestModel.nativeLanguage == requestModel.selectedLanguage
  }
  private var agreed: Bool { consentDate > 0 }                         // "I agree" is ticked
  private var canStart: Bool {                                         // form complete, agreed, and not already loading
    !trimmedProfession.isEmpty && !sameLanguage && agreed && !requestModel.isLoading
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
          
          if sameLanguage {                                     // orange warning under the pickers
            Label(languageAlertMessage, systemImage: "exclamationmark.circle")
              .font(.footnote)
              .foregroundStyle(.orange)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          
          FieldCard(title: reminderPick, icon: "bell") {        // reminder time + why we'll ask for notifications on Start
            VStack(alignment: .leading, spacing: 8) {
              DatePicker(reminderTimeLabel, selection: DailyReminder.timeBinding($reminderMinutes), displayedComponents: .hourAndMinute)
                .foregroundStyle(.white)
                .singleLine()
                .environment(\.colorScheme, .dark)               // white time pill on the black screen
              Text(reminderReason)                              // the one-line reason, read before the iOS popup
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
            }
          }

          FieldCard(title: consentPick, icon: "hand.raised") {  // what goes to OpenAI + "I agree" (App Review 5.1.2)
            VStack(alignment: .leading, spacing: 12) {
              Text(AIConsent.message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
              Button {                                          // tick saves the date, untick clears it
                consentDate = agreed ? 0 : Date().timeIntervalSince1970
              } label: {
                Label {
                  Text("I agree")
                    .singleLine()
                } icon: {
                  Image(systemName: agreed ? "checkmark.square.fill" : "square")
                }
                .font(.body)
                .foregroundStyle(.white)
              }
              .accessibilityAddTraits(agreed ? .isSelected : [])

              Button {                                          // optional: Firebase Analytics on/off
                shareStatistics.toggle()
                AnalyticsConsent.apply(shareStatistics)
              } label: {
                Label {
                  VStack(alignment: .leading, spacing: 2) {
                    Text("Share usage statistics to help improve the app")
                      .font(.body)
                      .foregroundStyle(.white)
                      .singleLine()
                    Text("Optional. You can change this anytime in Settings.")
                      .font(.footnote)
                      .foregroundStyle(.white.opacity(0.6))
                  }
                  .multilineTextAlignment(.leading)
                } icon: {
                  Image(systemName: shareStatistics ? "checkmark.square.fill" : "square")
                    .foregroundStyle(.white)
                }
              }
              .accessibilityAddTraits(shareStatistics ? .isSelected : [])
            }
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
    .onChange(of: requestModel.nativeLanguage) { _, new in          // save the choice for next launch
      nativeLanguage = new.rawValue
    }
    .onChange(of: requestModel.selectedLanguage) { _, new in        // save the choice for next launch
      pickedLanguage = new.rawValue
    }
    .onChange(of: requestModel.proffession) { _, new in             // cut to 40 characters, then save
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
  
  private var header: some View {                                      // welcome title + subtitle
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
  
  private var footer: some View {                                      // Start button (with the raccoon) + AI / privacy note
    VStack(spacing: 12) {
      Button {                                                          // close keyboard, save the trimmed profession, start
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
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { buttonWidth = $0 }   // keep buttonWidth up to date
      .overlay(alignment: .top) {
        ButtonRaccoon(arrived: raccoonArrived, isAnimating: !raccoonHidden)
          .alignmentGuide(.top) { $0[.bottom] - $0.height * 0.04 - 1 } // feet rest on top of the button
          .offset(x: raccoonX)
          .allowsHitTesting(false)                        // never blocks the button
          .environment(\.layoutDirection, .leftToRight)   // always runs left to right, even in RTL languages
      }
      
      VStack(spacing: 4) {
        Text("Words and images are generated by AI and may contain mistakes.")
        Link("Privacy Policy", destination: AppLinks.privacy)
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
  
  // MARK: - raccoonArrives
  // Runs in from the left edge and stays on the button, jumping and scratching.
  // Reduce Motion: just appears in the middle, standing still.
  // Otherwise runs to the middle over 1.3s, slowing down as it gets there; once there it settles in
  // (arrived = jumping/scratching) — but only if the button is still active.
  private func raccoonArrives() {
    raccoonHidden = false
    raccoonArrived = false
    guard !reduceMotion else {
      raccoonX = 0
      raccoonArrived = true
      return
    }
    withAnimation(.easeOut(duration: 1.3)) {
      raccoonX = 0
    } completion: {
      if canStart { raccoonArrived = true }
    }
  }
  
  // MARK: - raccoonLeaves
  // Gets up and runs off the right edge, then waits off the left edge for next time.
  // Reduce Motion: just disappears to the left.
  // Otherwise runs off to the right over 0.9s; then, unless the form became ready again meanwhile
  // (it came back while running off — leave it be), it jumps back to the left edge unseen and stops animating.
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
      guard !canStart else { return }
      raccoonX = -raccoonOffscreen
      raccoonHidden = true
    }
  }
  
  // MARK: - Building blocks
  
  // MARK: - languageField(title:icon:selection:)
  // A FieldCard with a menu of every language (translated names); the picked one is written into `selection`.
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
  let arrived: Bool                          // on the button (jump/scratch) vs running
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
