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
//   Daily reminder: on/off toggle + time (same saved values as EntryView's card) -> DailyReminder.reschedule()
//     turned on but never asked -> the iOS permission popup; said Don't Allow -> a note + "Open Settings" (iOS)
//   Progress: "Reset progress" -> PersistenceController.resetProgress for the current target language
//   Purchases: restore the unlocked professions (Purchases.restore)
//   Legal and support: "How to play" (onHowToPlay -> RootView shows the tutorial again), privacy, terms, support email links,
//     the "Share usage statistics" toggle (AnalyticsConsent) and what goes to OpenAI (AIConsent)
//   "Done" (only when the setup is usable) -> onDone -> AppManager.closeSettings() -> WelcomeBackView.

struct SettingsView: View {
  @Bindable var requestModel: RequestModel                         // languages and profession are edited right in it
  let hasAccess: Bool                                              // at least one profession unlocked: the voice picker opens
  var onShowPaywall: () -> Void                                    // "Unlock" in the locked alert -> PaywallView
  var onDone: () -> Void                                           // back to the welcome-back screen
  var onHowToPlay: () -> Void = {}                                 // RootView: show the "How to play" tutorial again
  
  @AppStorage("nativeLanguage") private var nativeLanguage = "en-US"   // saved copies, same keys as EntryView
  @AppStorage("pickedLanguage") private var pickedLanguage = "en-US"
  @AppStorage("pickedProffession") private var pickedProfession = ""
  @AppStorage("speechRate") private var speechRate = 0.45          // 0.5 = the system's normal speaking speed
  @AppStorage(DailyReminder.enabledKey) private var reminderEnabled = true                        // reminder toggle, on by default
  @AppStorage(DailyReminder.timeKey) private var reminderMinutes = DailyReminder.defaultMinutes   // reminder time, minutes after midnight
  @AppStorage(AnalyticsConsent.key) private var shareStatistics = false                           // optional analytics consent, same key as EntryView
  @Environment(\.scenePhase) private var scenePhase                // back from iOS Settings -> re-check the notification permission
  @Environment(\.openURL) private var openURL                      // opens the app's page in iOS Settings
  @Environment(\.locale) private var locale                       // app language: region names next to voices
  
  @State private var showLockedAlert = false                       // "Premium feature" alert (learning block lock, currently unused)
  @State private var showResetAlert = false                        // "Reset progress?" confirmation
  @State private var showDeleteAlert = false                       // delete-all-data alert (section commented out)
  @State private var showRestoreAlert = false                      // result of "Restore purchases"
  @State private var restoreMessage: LocalizedStringKey = ""       // text of that result alert
  @State private var selectedVoiceID = ""                       // "" = Default
  @State private var speechManager = SpeechManager()            // for the "Try" button
  @State private var showVoiceLockedAlert = false          // NEW — free user tapped the locked voice row
  @State private var notificationsDenied = false                   // user said Don't Allow in iOS: the toggle can't override it
  @FocusState private var professionFocused: Bool                 // passed into ProfessionPicker
  
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
        reminderSection
        progressSection
        subscriptionSection
        legalSection
        //deleteSection
        #if DEBUG || TESTFLIGHT_TOOLS
        debugSection                                               // testing tools: Debug and tester builds, never in App Store builds
        #endif
        
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
    .foldAlert(MenuAlert.settingsLocked.title, isPresented: $showLockedAlert,   // premium lock -> plans
               message: MenuAlert.settingsLocked.message, confirmTitle: MenuAlert.settingsLocked.confirmTitle) { onShowPaywall() }
    .foldAlert("Reset progress?", isPresented: $showResetAlert,
               message: "All your answers and saved words in the language you are learning will be deleted. This can't be undone.",
               confirmTitle: "Reset", confirmRole: .destructive) {      // deletes this target language's answers
      PersistenceController.shared.resetProgress(targetLanguage: requestModel.selectedLanguage.rawValue)
    }
    .foldAlert(restoreMessage, isPresented: $showRestoreAlert, confirmTitle: "OK", hasCancel: false) { }
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
        .singleLine()
      Spacer()
      Button(action: onDone) {
        Text("Done")
          .font(.headline)
          .foregroundStyle(.white)
          .singleLine()
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
            .singleLine()
          Spacer()
          if hasAccess {                                        // paid: real picker
            let voices = SpeechManager.voices(for: language)
            Menu {                                              // own label instead of the system picker button,
              Picker("Voice", selection: $selectedVoiceID) {    // which wrapped long names onto several lines
                Text("Default").tag("")
                ForEach(voices, id: \.identifier) { voice in
                  Text(verbatim: SpeechManager.label(for: voice, target: language, locale: locale))   // "Eddy (Mexico)"
                    .tag(voice.identifier)
                }
              }
            } label: {
              HStack(spacing: 4) {
                if let voice = voices.first(where: { $0.identifier == selectedVoiceID }) {
                  Text(verbatim: SpeechManager.label(for: voice, target: language, locale: locale))
                } else {
                  Text("Default")
                }
                Image(systemName: "chevron.up.chevron.down")
                  .font(.footnote.weight(.semibold))
              }
              .foregroundStyle(.white)
              .singleLine()
            }
          } else {                                              // NEW — free: locked, tap shows the premium alert
            Button {
              showVoiceLockedAlert = true
            } label: {
              Label("Default", systemImage: "lock.fill")
                .foregroundStyle(.white.opacity(0.7))
                .singleLine()
            }
          }
        }
        
        divider
        
        Text("Speech speed")
          .foregroundStyle(.white)
          .singleLine()
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
    .foldAlert(MenuAlert.settingsLocked.title, isPresented: $showVoiceLockedAlert,
               message: MenuAlert.settingsLocked.message, confirmTitle: MenuAlert.settingsLocked.confirmTitle) { onShowPaywall() }
    .alertSound(isPresented: showVoiceLockedAlert)
  }
  
  // MARK: - loadVoice
  // Reads the voice saved for the current target language into the picker ("" = Default when none saved).
  // A saved voice that's no longer in the list (a lower-quality copy of a listed voice, see SpeechManager.voices)
  // shows as the listed voice with the same name and language.
  private func loadVoice() {
    let language = requestModel.selectedLanguage.id
    let saved = UserDefaults.standard.string(forKey: SpeechManager.voiceKey(for: language)) ?? ""
    let listed = SpeechManager.voices(for: language)
    if saved.isEmpty || listed.contains(where: { $0.identifier == saved }) {
      selectedVoiceID = saved
    } else {
      let voice = AVSpeechSynthesisVoice(identifier: saved)
      selectedVoiceID = listed.first { $0.name == voice?.name && $0.language == voice?.language }?.identifier ?? ""
    }
  }
  
  private var reminderSection: some View {                         // daily reminder: on/off, time, permission note
    FieldCard(title: "Daily reminder", icon: "bell") {
      VStack(alignment: .leading, spacing: 14) {
        Toggle("Remind me every day", isOn: $reminderEnabled)
          .foregroundStyle(.white)
          .singleLine()
        
        if reminderEnabled {                                       // time and details only while it's on
          divider
          DatePicker("Remind me at", selection: DailyReminder.timeBinding($reminderMinutes), displayedComponents: .hourAndMinute)
            .foregroundStyle(.white)
            .singleLine()
            .environment(\.colorScheme, .dark)                     // white time pill on the black screen
          Text("We'll remind you once a day, only if you haven't played yet.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.6))
          
          if notificationsDenied {                                 // iOS blocks it: explain and offer the way out
            Label("Notifications are off for LearnScrumble in the iPhone's Settings.", systemImage: "bell.slash")
              .font(.footnote)
              .foregroundStyle(.orange)
            row("Open Settings", icon: "gear") {
              if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            }
          }
        }
      }
    }
    .task { await refreshNotificationStatus() }                    // show the note right away if iOS blocks it
    .onChange(of: reminderEnabled) { _, on in                      // toggle -> ask (first time) or re-book / clear
      Task { await reminderToggled(on: on) }
    }
    .onChange(of: reminderMinutes) { _, _ in                        // new time -> re-book at that time
      Task { await DailyReminder.reschedule() }
    }
    .onChange(of: scenePhase) { _, phase in                         // coming back from iOS Settings
      if phase == .active { Task { await refreshNotificationStatus() } }
    }
  }
  
  // MARK: - reminderToggled(on:)
  // Toggle turned on and iOS has never asked (e.g. onboarding finished before reminders existed)
  //   -> DailyReminder.requestPermission(): the iOS popup, then the reminders are booked.
  // Any other change -> DailyReminder.reschedule(): on = book at the saved time, off = remove every booked reminder.
  // Turned on and allowed -> reminder_enabled event (Track).
  // Then re-checks the permission, so the "notifications are off" note is up to date.
  private func reminderToggled(on: Bool) async {
    if on, await DailyReminder.authorizationStatus() == .notDetermined {
      await DailyReminder.requestPermission()
    } else {
      await DailyReminder.reschedule()
    }
    if on, await DailyReminder.authorizationStatus() == .authorized {   // only counts if iOS really allows it
      Track.reminderEnabled(source: .settings)
    }
    await refreshNotificationStatus()
  }
  
  // MARK: - refreshNotificationStatus
  // Asks iOS whether the user said Don't Allow, for the note under the reminder toggle.
  private func refreshNotificationStatus() async {
    notificationsDenied = await DailyReminder.authorizationStatus() == .denied
  }
  
  private var progressSection: some View {                         // reset progress (with confirmation)
    FieldCard(title: "Progress", icon: "chart.bar") {
      row("Reset progress", icon: "arrow.counterclockwise", tint: .orange) { showResetAlert = true }
    }
  }
  
  private var subscriptionSection: some View {                     // restore the one-time unlocks (no subscription to manage)
    FieldCard(title: "Purchases", icon: "star") {
      row("Restore purchases", icon: "arrow.clockwise") { restorePurchases() }
    }
  }
  
  private var legalSection: some View {                            // how to play, privacy, terms, support email
    FieldCard(title: "Legal and support", icon: "doc.text") {
      VStack(spacing: 12) {
        row("How to play", icon: "questionmark.circle") { onHowToPlay() }
        divider
        linkRow("Privacy Policy", icon: "hand.raised", url: AppLinks.privacy)
        divider
        linkRow("Terms of Use", icon: "doc.plaintext", url: AppLinks.terms)
        divider
        linkRow("Contact support", icon: "envelope", url: AppLinks.supportMail)
        divider
        Toggle("Share usage statistics to help improve the app", isOn: $shareStatistics)   // Firebase Analytics on/off
          .foregroundStyle(.white)                                // a whole sentence: may wrap (one line cut off its meaning)
          .onChange(of: shareStatistics) { _, on in AnalyticsConsent.apply(on) }
        divider
        Text(AIConsent.message)                                   // what goes to OpenAI, agreed to on setup (AIConsent)
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
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
  
  #if DEBUG || TESTFLIGHT_TOOLS
  // MARK: - debugSection
  // Debug builds and tester builds (TESTFLIGHT_TOOLS, see README "Tester builds") only: testing tools. Text(verbatim:) keeps these English labels out of the translation catalog.
  //   "Crashlytics crash test" (red) -> fatalError: a real crash for testing Crashlytics (README → Crashlytics test crash)
  //   "Reset free words" -> FreeAllowance.resetForTesting(): the 10 free words again (shows how many are used now)
  //   "Unlock every profession" -> Purchases.debugUnlockAll: the paid version (the whole word list, My words, voices)
  //   without buying anything
  private var debugSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label {
        Text(verbatim: "Debug (not in App Store builds)")
      } icon: {
        Image(systemName: "ladybug")
      }
      .font(.headline)
      .foregroundStyle(.orange)
      Button {
        fatalError("Test crash for Crashlytics")
      } label: {
        Label {
          Text(verbatim: "Crashlytics crash test (closes the app)")
        } icon: {
          Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.red.opacity(0.25), in: .rect(cornerRadius: 16))
      }
      Button {
        FreeAllowance.shared.resetForTesting()
      } label: {
        Text(verbatim: "Reset free words (\(FreeAllowance.shared.wordsUsed)/\(FreeAllowance.freeWordLimit) used)")
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(.orange.opacity(0.15), in: .rect(cornerRadius: 16))
      }
      Toggle(isOn: Bindable(Purchases.shared).debugUnlockAll) {
        Text(verbatim: "Unlock every profession (paid version)")
          .foregroundStyle(.white)
      }
      .tint(.orange)
      .padding(14)
      .background(.orange.opacity(0.15), in: .rect(cornerRadius: 16))
    }
  }
  #endif

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
        .singleLine()                                             // one line, shrinks for long translations
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
  // Purchases.restore(): AppStore.sync() asks Apple for the user's purchases and re-reads the unlocked jobs
  // -> success or failure message -> shows the result alert. The user cancelled Apple's sign-in -> nothing at all.
  private func restorePurchases() {
    Task {
      do {
        guard try await Purchases.shared.restore() else { return }   // cancelled: close quietly
        restoreMessage = "Your purchases have been restored."
        showRestoreAlert = true
      } catch {
        restoreMessage = "Couldn't restore purchases. Please try again."
        showRestoreAlert = true
      }
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
