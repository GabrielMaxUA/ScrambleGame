//
//  SettingsView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI
import StoreKit
import AVFoundation

struct SettingsView: View {
  @Bindable var requestModel: RequestModel
  let hasAccess: Bool                                              // paid/unlocked: languages and profession can be changed
  var onShowPaywall: () -> Void                                    // "See plans" in the locked alert
  var onDone: () -> Void                                           // back to the welcome-back screen
  
  @AppStorage("nativeLanguage") private var nativeLanguage = "en-US"
  @AppStorage("pickedLanguage") private var pickedLanguage = "en-US"
  @AppStorage("pickedProffession") private var pickedProfession = ""
  @AppStorage("speechRate") private var speechRate = 0.45          // 0.5 = the system's normal speaking speed
  
  @State private var showLockedAlert = false
  @State private var showResetAlert = false
  @State private var showDeleteAlert = false
  @State private var showManageSubscriptions = false
  @State private var showRestoreAlert = false
  @State private var restoreMessage: LocalizedStringKey = ""
  @State private var selectedVoiceID = ""                       // "" = Default
  @State private var speechManager = SpeechManager()            // for the "Try" button
  @State private var showVoiceLockedAlert = false          // NEW — free user tapped the locked voice row
  @FocusState private var professionFocused: Bool
  
  private let supportEmail = "support@example.com"                 // TODO: real support address
  private let privacyURL = URL(string: "https://your-site.com/privacy")!   // TODO: real privacy policy (blocked by the kits decision)
  private let termsURL = URL(string: "https://your-site.com/terms")!       // TODO: real terms of use
  private let maxProfessionLength = 40
  
  private var sameLanguage: Bool { requestModel.nativeLanguage == requestModel.selectedLanguage }
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
      VStack(alignment: .leading, spacing: 28) {
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
    .onChange(of: requestModel.proffession) { _, new in
      if new.count > maxProfessionLength {
        requestModel.proffession = String(new.prefix(maxProfessionLength))
      }
      pickedProfession = requestModel.proffession
    }
    .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)   // Apple's own subscription screen
    .alert(MenuAlert.settingsLocked.title, isPresented: $showLockedAlert) {
      Button(MenuAlert.settingsLocked.confirmTitle) { onShowPaywall() }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text(MenuAlert.settingsLocked.message)
    }
    .alert("Reset progress?", isPresented: $showResetAlert) {
      Button("Reset", role: .destructive) {
        PersistenceController.shared.resetProgress(targetLanguage: requestModel.selectedLanguage.rawValue)
      }
      Button("Cancel", role: .cancel) { }
    } message: {
      Text("All your answers in the language you are learning will be deleted. This can't be undone.")
    }
    .alert(restoreMessage, isPresented: $showRestoreAlert) {
      Button("OK") { }
    }
  }
  
  // MARK: - Sections
  
  private var header: some View {
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
      .glassEffect(.clear.interactive(), in: .capsule)
      .disabled(!canClose)
      .opacity(canClose ? 1 : 0.5)
    }
  }
  
  private var learningSection: some View {
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
      
      if !hasAccess {
        Label("Changing languages and profession is part of the subscription.", systemImage: "lock.fill")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
      } else if sameLanguage {
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
  
  private var audioSection: some View {
    let language = requestModel.selectedLanguage.id
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
    .onAppear { loadVoice() }
    .onChange(of: requestModel.selectedLanguage) { _, _ in loadVoice() }   // other language: show that language's saved voice
    .onChange(of: selectedVoiceID) { _, id in
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
  }
  
  private func loadVoice() {
    selectedVoiceID = UserDefaults.standard.string(forKey: SpeechManager.voiceKey(for: requestModel.selectedLanguage.id)) ?? ""
  }
  
  private var progressSection: some View {
    FieldCard(title: "Progress", icon: "chart.bar") {
      row("Reset progress", icon: "arrow.counterclockwise", tint: .orange) { showResetAlert = true }
    }
  }
  
  private var subscriptionSection: some View {
    FieldCard(title: "Subscription", icon: "star") {
      VStack(spacing: 12) {
        row("Manage subscription", icon: "creditcard") { showManageSubscriptions = true }
        divider
        row("Restore purchases", icon: "arrow.clockwise") { restorePurchases() }
      }
    }
  }
  
  private var legalSection: some View {
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
  
  private func row(_ title: LocalizedStringKey, icon: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      rowLabel(title, icon: icon, tint: tint)
    }
  }
  
  private func linkRow(_ title: LocalizedStringKey, icon: String, url: URL) -> some View {
    Link(destination: url) {
      rowLabel(title, icon: icon, tint: .white)
    }
  }
  
  private func rowLabel(_ title: LocalizedStringKey, icon: String, tint: Color) -> some View {
    HStack {
      Label(title, systemImage: icon)
        .foregroundStyle(tint)
      Spacer()
      Image(systemName: "chevron.forward")                          // flips automatically in right-to-left languages
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.4))
    }
    .contentShape(Rectangle())
  }
  
  private var divider: some View {
    Rectangle()
      .fill(.white.opacity(0.15))
      .frame(height: 1)
  }
  
  // MARK: - Actions
  
  private func restorePurchases() {                                 // StoreKit for now; RevenueCat's restore replaces this later
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
