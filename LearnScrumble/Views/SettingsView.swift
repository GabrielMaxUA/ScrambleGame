//
//  SettingsView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI
import StoreKit
import AVFoundation

// MARK: - Flow of this file
// The settings screen (phase .settings), opened from the gear or ErrorView's "Change profession".
//   Learning: native language, profession, target language -> written into RequestModel + saved like EntryView does
//   Audio: voice (paid; free users get the locked alert) saved per language, speech speed, "Try it" -> SpeechManager
//   Progress: "Reset progress" -> PersistenceController.resetProgress for the current target language
//   Subscription: Apple's manage-subscriptions sheet, restore purchases (StoreKit AppStore.sync)
//   Legal: privacy, terms, support email links
//   "Done" (only when the setup is usable) -> onDone -> AppManager.closeSettings() -> WelcomeBackView.

struct SettingsView: View {
  @Bindable var requestModel: RequestModel                         // languages and profession are edited right in it
  let hasAccess: Bool                                              // paid/unlocked: languages and profession can be changed
  var onShowPaywall: () -> Void                                    // "See plans" in the locked alert
  var onDone: () -> Void                                           // back to the welcome-back screen
  
  @AppStorage("nativeLanguage") private var nativeLanguage = "en-US"   // saved copies, same keys as EntryView
  @AppStorage("pickedLanguage") private var pickedLanguage = "en-US"
  @AppStorage("pickedProffession") private var pickedProfession = ""
  @AppStorage("speechRate") private var speechRate = 0.45          // 0.5 = the system's normal speaking speed
  
  @State private var showLockedAlert = false                       // "Premium feature" alert (learning block lock, currently unused)
  @State private var showResetAlert = false                        // "Reset progress?" confirmation
  @State private var showDeleteAlert = false                       // delete-all-data alert (section commented out)
  @State private var showManageSubscriptions = false               // Apple's subscription sheet
  @State private var showRestoreAlert = false                      // result of "Restore purchases"
  @State private var restoreMessage: LocalizedStringKey = ""       // text of that result alert
  @State private var selectedVoiceID = ""                       // "" = Default
  @State private var speechManager = SpeechManager()            // for the "Try" button
  @State private var showVoiceLockedAlert = false          // NEW — free user tapped the locked voice row
  @FocusState private var professionFocused: Bool                 // passed into ProfessionPicker
  
  private let supportEmail = "support@example.com"                 // TODO: real support address
  private let privacyURL = URL(string: "https://your-site.com/privacy")!   // TODO: real privacy policy (blocked by the kits decision)
  private let termsURL = URL(string: "https://your-site.com/terms")!       // TODO: real terms of use
  private let maxProfessionLength = 40                             // same limit as EntryView
  
  private var sameLanguage: Bool { requestModel.nativeLanguage == requestModel.selectedLanguage }   // not allowed
  private var trimmedProfession: String { requestModel.proffession.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var canClose: Bool { !sameLanguage && !trimmedProfession.isEmpty }  // never leave with an unusable setup
  
  private var appVersion: String {                                 // read from the app's settings, e.g. "1.0 (3)"
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "\(version) (\(build))"
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {                 // the sections, top to bottom
        header
        learningSection
        audioSection
        progressSection
        subscriptionSection
        legalSection
        //deleteSection
        
        Text(verbatim: "LearnScrumble \(appVersion)")              // verbatim: not looked up for translation
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.4))
          .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, 20)
      .padding(.top, 42)
      .padding(.bottom, 24)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(.black)
    .onChange(of: requestModel.nativeLanguage) { _, new in nativeLanguage = new.rawValue }      // same saved keys as EntryView
    .onChange(of: requestModel.selectedLanguage) { _, new in pickedLanguage = new.rawValue }
    .onChange(of: requestModel.proffession) { _, new in         // cut to 40 characters, then save
      if new.count > maxProfessionLength {
        requestModel.proffession = String(new.prefix(maxProfessionLength))
      }
      pickedProfession = requestModel.proffession
    }
    .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)   // Apple's own subscription screen
    .alert(MenuAlert.settingsLocked.title, isPresented: $showLockedAlert) {   // premium lock -> plans
      Button(MenuAlert.settingsLocked.confirmTitle) { onShowPaywall() }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text(MenuAlert.settingsLocked.message)
    }
    .alert("Reset progress?", isPresented: $showResetAlert) {
      Button("Reset", role: .destructive) {                     // deletes this target language's answers
        PersistenceController.shared.resetProgress(targetLanguage: requestModel.selectedLanguage.rawValue)
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("All your answers in the language you are learning will be deleted. This can't be undone.")
    }
    .alert(restoreMessage, isPresented: $showRestoreAlert) {
      Button("OK") { }
    }
    .alertSound(isPresented: showLockedAlert)
    .alertSound(isPresented: showResetAlert)
    .alertSound(isPresented: showRestoreAlert)
  }
  
  // MARK: - Sections
  
  private var header: some View {                                  // title + Done (disabled until the setup is usable)
    HStack {
      Text("Settings")
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
      Spacer()
      Button(action: onDone) {
        Text("Done")
          .font(.headline)
          .foregroundStyle(.white)
          .padding(.horizontal, 20)
          .padding(.vertical, 10)
      }
      .glassCompat(in: .capsule, interactive: true)
      .disabled(!canClose)
      .opacity(canClose ? 1 : 0.5)
    }
  }
  
  private var learningSection: some View {                         // languages + profession, with a hint under them
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 20) {
        languageCard(title: "I speak", icon: "person.wave.2", selection: $requestModel.nativeLanguage)
        FieldCard(title: "My profession", icon: "briefcase") {
          ProfessionPicker(requestModel: requestModel, isFocused: $professionFocused)
        }
        languageCard(title: "I want to learn", icon: "character.book.closed", selection: $requestModel.selectedLanguage)
      }
//MARK: - need to decide on making it accessable to everyone or only to paid users
      
      //.disabled(!hasAccess)                                         // free users can see but not change
//      .opacity(hasAccess ? 1 : 0.5)
//      .overlay {
//        if !hasAccess {
//          Color.clear
//            .contentShape(Rectangle())
//            .onTapGesture { showLockedAlert = true }                // any tap on the locked block explains why
//        }
//      }
//      
//      if !hasAccess {
//        Label("Changing languages and profession is part of the subscription.", systemImage: "lock.fill")
//          .font(.footnote)
//          .foregroundStyle(.white.opacity(0.6))
//      } else
        if sameLanguage {
        Label("Pick two different languages.", systemImage: "exclamationmark.circle")
          .font(.footnote)
          .foregroundStyle(.orange)
      } else {
        Text("Progress is saved separately for each language you learn. Switching keeps your old progress.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
      }
    }
  }
  
  private var audioSection: some View {                            // voice, speed, try it
    let language = requestModel.selectedLanguage.id               // voices are per target language
    return FieldCard(title: "Audio", icon: "speaker.wave.2") {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("Voice")
            .foregroundStyle(.white)
          Spacer()
          if hasAccess {                                        // NEW — paid: real picker
            Picker("Voice", selection: $selectedVoiceID) {
              Text("Default").tag("")
              ForEach(SpeechManager.voices(for: language), id: \.identifier) { voice in
                Text(verbatim: voice.name).tag(voice.identifier)      // voice names are proper names, not translated
              }
            }
            .pickerStyle(.menu)
            .tint(.white)
            .labelsHidden()
          } else {                                              // NEW — free: locked, tap shows the premium alert
            Button {
              showVoiceLockedAlert = true
            } label: {
              Label("Default", systemImage: "lock.fill")
                .foregroundStyle(.white.opacity(0.7))
            }
          }
        }
        
        divider
        
        Text("Speech speed")
          .foregroundStyle(.white)
        HStack(spacing: 12) {
          Image(systemName: "tortoise.fill")
          Slider(value: $speechRate, in: 0.3...0.6)
            .tint(.white)
          Image(systemName: "hare.fill")
        }
        .foregroundStyle(.white.opacity(0.7))
        .environment(\.layoutDirection, .leftToRight)
        
        divider
        
        row("Try it", icon: "play.fill") {                       // speaks the language's own name with the chosen voice and speed
          speechManager.speak(requestModel.selectedLanguage.displayName, language: language)
        }
        
        Text("More voices can be downloaded in the iPhone's Settings › Accessibility › Spoken Content › Voices.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.5))
      }
    }
    .onAppear { loadVoice() }                                     // show this language's saved voice
    .onChange(of: requestModel.selectedLanguage) { _, _ in loadVoice() }   // other language: show that language's saved voice
    .onChange(of: selectedVoiceID) { _, id in                     // save the picked voice for this language
      let key = SpeechManager.voiceKey(for: requestModel.selectedLanguage.id)
      if id.isEmpty {
        UserDefaults.standard.removeObject(forKey: key)              // Default: forget any saved voice
      } else {
        UserDefaults.standard.set(id, forKey: key)
      }
    }
    .alert(MenuAlert.settingsLocked.title, isPresented: $showVoiceLockedAlert) {   // NEW
      Button(MenuAlert.settingsLocked.confirmTitle) { onShowPaywall() }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text(MenuAlert.settingsLocked.message)
    }
    .alertSound(isPresented: showVoiceLockedAlert)
  }
  
  // MARK: - loadVoice
  // Reads the voice saved for the current target language into the picker ("" = Default when none saved).
  private func loadVoice() {
    selectedVoiceID = UserDefaults.standard.string(forKey: SpeechManager.voiceKey(for: requestModel.selectedLanguage.id)) ?? ""
  }
  
  private var progressSection: some View {                         // reset progress (with confirmation)
    FieldCard(title: "Progress", icon: "chart.bar") {
      row("Reset progress", icon: "arrow.counterclockwise", tint: .orange) { showResetAlert = true }
    }
  }
  
  private var subscriptionSection: some View {                     // manage + restore
    FieldCard(title: "Subscription", icon: "star") {
      VStack(spacing: 12) {
        row("Manage subscription", icon: "creditcard") { showManageSubscriptions = true }
        divider
        row("Restore purchases", icon: "arrow.clockwise") { restorePurchases() }
      }
    }
  }
  
  private var legalSection: some View {                            // privacy, terms, support email
    FieldCard(title: "Legal and support", icon: "doc.text") {
      VStack(spacing: 12) {
        linkRow("Privacy Policy", icon: "hand.raised", url: privacyURL)
        divider
        linkRow("Terms of Use", icon: "doc.plaintext", url: termsURL)
        divider
        linkRow("Contact support", icon: "envelope", url: URL(string: "mailto:\(supportEmail)")!)
      }
    }
  }
  
  // MARK: - Building blocks
  
  // MARK: - languageCard(title:icon:selection:)
  // A FieldCard with a menu of every language (translated names); the picked one is written into `selection`.
  private func languageCard(title: LocalizedStringKey, icon: String, selection: Binding<Languages>) -> some View {
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
  
  // MARK: - row(_:icon:tint:action:)
  // A tappable settings row (icon + title + chevron) that runs `action`.
  private func row(_ title: LocalizedStringKey, icon: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      rowLabel(title, icon: icon, tint: tint)
    }
  }
  
  // MARK: - linkRow(_:icon:url:)
  // Same look as row, but opens a URL (web page or mail) instead of running code.
  private func linkRow(_ title: LocalizedStringKey, icon: String, url: URL) -> some View {
    Link(destination: url) {
      rowLabel(title, icon: icon, tint: .white)
    }
  }
  
  // MARK: - rowLabel(_:icon:tint:)
  // The shared look of row and linkRow: icon + title on one side, a small chevron on the other
  // (chevron.forward flips automatically in right-to-left languages). The whole row is tappable.
  private func rowLabel(_ title: LocalizedStringKey, icon: String, tint: Color) -> some View {
    HStack {
      Label(title, systemImage: icon)
        .foregroundStyle(tint)
      Spacer()
      Image(systemName: "chevron.forward")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.4))
    }
    .contentShape(Rectangle())
  }
  
  private var divider: some View {                                 // thin line between rows
    Rectangle()
      .fill(.white.opacity(0.15))
      .frame(height: 1)
  }
  
  // MARK: - Actions
  
  // MARK: - restorePurchases
  // StoreKit for now; RevenueCat's restore replaces this later.
  // AppStore.sync() asks Apple for the user's purchases -> success or failure message -> shows the result alert.
  private func restorePurchases() {
    Task {
      do {
        try await AppStore.sync()
        restoreMessage = "Your purchases have been restored."
      } catch {
        restoreMessage = "Couldn't restore purchases. Please try again."
      }
      showRestoreAlert = true
    }
  }
}

#Preview {
  SettingsView(
    requestModel: RequestModel(),
    hasAccess: false,
    onShowPaywall: {
    },
    onDone: {},
    )
}
