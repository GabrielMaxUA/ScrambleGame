//
//  OnboardingView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-14.
//

import SwiftUI

// MARK: - Flow of this file
// The "How to play" tutorial, shown after the setup screen's Start button (while the first real words load behind it),
// at launch for anyone set up who never saw it, and from Settings' "How to play".
// It always comes after the languages are picked, so everything is in the user's own language
// (RootView's locale) and the practice word is in the language being learned.
//   RootView shows it on top of everything while showTutorial is true
//   -> the REAL game screen (MainView) runs OnboardingService's practice word, one session from start to finish
//   -> above it: the title + Skip, and the game's top row (back arrow, speaker; the arrow replaced the gear on
//      1 November 2026, like the game: the tooltip says Settings are on the start screen, behind the gear)
//   -> one task at a time: a pointer (PointerUp) taps on the button to use, with a tooltip saying what to do;
//      both move on as soon as the task is done (OnboardingService.instruction / pointerTarget)
//   -> the word spelled -> "Correct!" (the game's own success screen, with the 10 free words and "Next")
//      -> Next -> OnboardingService.completed -> the two test pages (TutorialTestPage), one after the other:
//        1. Pronunciation test: a mini card (the cat, the word, "Tap to speak"). A demo: the tap shows "Listening…",
//           then ✓ Correct! and the word is read — the microphone is never used, so no permission popup here.
//           -> Next
//        2. Listening test: a mini card with 4 pictures (the cat and 3 drawn things) and the speaker, as the real
//           test: the speaker reads the word and unlocks the pictures, the first tap is final (green / red).
//           -> Let's go!
//        Both say where the tests are: on the start screen, once a few words are played, with "Test all".
//   Skip (any time) / Let's go! -> OnboardingService.finish() (saved as seen) -> onDone() -> RootView hides it.

struct OnboardingView: View {
  let manager: AppManager                                   // MainView needs it (only for its loading progress)
  var onDone: () -> Void                                    // RootView: hide the tutorial
  @State private var service: OnboardingService            // tasks + the practice game
  @State private var testPage: TutorialTestPage.Kind?      // after the practice word: the test pages; nil = the game

  private let topInset: CGFloat = 140                       // room above the picture: header + the game's top row
  private let fingerSize: CGFloat = 46                      // the pointer's size

  // MARK: - init
  // Builds the tutorial with the languages picked on the setup screen (kept in RequestModel).
  init(manager: AppManager, onDone: @escaping () -> Void) {
    self.manager = manager
    self.onDone = onDone
    _service = State(initialValue: OnboardingService(native: manager.requestModel.nativeLanguage,
                                                     target: manager.requestModel.selectedLanguage))
  }

  var body: some View {
    ZStack(alignment: .top) {
      if let testPage {
        TutorialTestPage(kind: testPage, word: service.practiceWord, sayWord: service.sayWord,
                         onNext: { withAnimation(.easeInOut(duration: 0.3)) { self.testPage = .listening } },
                         onDone: finish, onSkip: finish)
          .id(testPage)
          .transition(.opacity)
      } else {
        MainView(vm: service.vm, manager: manager, topInset: topInset,
                 onHintToggled: service.hintToggled, onReset: service.resetTapped,
                 resultButtonTitle: "Next",                                          // on to the test pages
                 resultNote: "You get \(FreeAllowance.freeWordLimit) free words to try the app.")   // the real game, practice word

        if service.vm.guessResult == nil {                  // hidden while the right/wrong screen covers everything
          header
        }
      }
    }
    .background(.black)
    .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in   // the pointer + tooltip, on top of everything
      GeometryReader { proxy in
        if testPage == nil { pointerLayer(anchors: anchors, in: proxy) }
      }
    }
    .onChange(of: service.vm.resultWord) { service.answerChanged() }   // a letter placed or sent back
    .onChange(of: service.completed) { _, done in           // Next on "Correct!": on to the test pages
      if done { withAnimation(.easeInOut(duration: 0.3)) { testPage = .speech } }
    }
  }

  // MARK: - Sections

  private var header: some View {                           // title + Skip, then the game's top row
    VStack(spacing: 8) {
      ZStack {
        Text("How to play")
          .font(.headline)
          .foregroundStyle(.white)
        HStack {
          Spacer()
          Button("Skip") { finish() }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
            .frame(minWidth: 44, minHeight: 44)
        }
      }

      HStack {                                              // same buttons, same places as the game's top row
        gameButton("chevron.backward", target: .settings, label: "Back", action: service.settingsTapped)
        Spacer()
        gameButton("speaker.wave.2.fill", target: .speaker, label: "Hear the word", action: service.speakWord)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 4)
  }

  // MARK: - tooltipText(for:)
  // The tooltip for each task. The letter to tap is bold (passed as Text, so the translation keeps its place).
  private func tooltipText(for instruction: OnboardingService.Instruction) -> LocalizedStringKey {
    switch instruction {
    case .startWith(let letter):      "Tap the letters to spell what you see. Start with \(Text(letter).bold())."
    case .wrongOnPurpose(let letter): "Now tap \(Text(letter).bold()). It goes in the wrong place on purpose."
    case .sendBack:                   "Wrong letter? Tap it in your answer to send it back to the letters below."
    case .reset:                      "Tap ↻ to clear the whole answer and start over."
    case .hint:                       "Stuck? Tap the lightbulb to see the word in your language."
    case .speaker:                    "Tap the speaker to hear the word."
    case .settings:                   "This arrow takes you back to the start screen. Settings are there, behind the gear. Tap it."
    case .spellWord(let letter):      "Now spell the whole word. Start with \(Text(letter).bold())."
    case .now(let letter):            "Now \(Text(letter).bold())."
    case .finish:                     "Nice! Tap Next to see two more ways to practise."
    }
  }

  // MARK: - pointerLayer(anchors:in:)
  // Puts the pointer on the current target and the tooltip next to it.
  // Targets low on the screen (tiles, ↻, Next) get the pointer from above, pointing down, with the tooltip above it;
  // everything else gets it from below, pointing up, with the tooltip below.
  // Pointer + tooltip are one group hung from a 1pt point at the target's edge (overlay alignment .bottom = grows upward).
  // The tooltip is nudged sideways to stay at least 16pt from the screen edges. Moving to a new target glides;
  // taps pass through.
  @ViewBuilder
  private func pointerLayer(anchors: [TutorialTarget: Anchor<CGRect>], in proxy: GeometryProxy) -> some View {
    if let target = service.pointerTarget, let anchor = anchors[target] {
      let rect = proxy[anchor]
      let down = Self.pointsDown(at: target)
      let bubbleWidth = min(270, proxy.size.width - 32)
      let bubbleCenter = min(max(rect.midX, 16 + bubbleWidth / 2), proxy.size.width - 16 - bubbleWidth / 2)
      let pointer = TutorialPointer(pointsDown: down)
        .frame(width: fingerSize, height: fingerSize)
        .offset(x: fingerSize * (down ? -0.04 : 0.04))    // the drawing's fingertip is a little off its center
      let bubble = tooltip(width: bubbleWidth)
        .offset(x: bubbleCenter - rect.midX)
      Color.clear
        .frame(width: 1, height: 1)
        .overlay(alignment: down ? .bottom : .top) {
          VStack(spacing: 6) {
            if down { bubble; pointer } else { pointer; bubble }
          }
          .fixedSize()
        }
        .position(x: rect.midX, y: down ? rect.minY - 2 : rect.maxY + 2)
        .allowsHitTesting(false)
        .animation(.spring(duration: 0.45), value: target)
    }
  }

  // MARK: - tooltip(width:)
  // The white bubble with the current task's text.
  private func tooltip(width: CGFloat) -> some View {
    Text(tooltipText(for: service.instruction))
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.black)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(width: width)                                // fixed width, so its height is measured right and the pointer sits correctly
      .background(.white, in: RoundedRectangle(cornerRadius: 12))
      .shadow(color: .black.opacity(0.5), radius: 6)
  }

  // MARK: - pointsDown(at:)
  // True for targets near the bottom of the screen, where there's no room below them for the pointer,
  // and for ↻, so its tooltip covers the picture instead of the answer slots.
  private static func pointsDown(at target: TutorialTarget) -> Bool {
    switch target {
    case .tile, .reset, .next: true
    default:                   false
    }
  }

  // MARK: - gameButton(_:target:label:action:)
  // A round 50×50 glass button like the game's top row, reporting its place for the pointer.
  private func gameButton(_ icon: String, target: TutorialTarget, label: LocalizedStringKey,
                          action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: icon)
        .frame(width: 50, height: 50)
        .foregroundStyle(.white)
    }
    .glassCompat(in: .circle)
    .accessibilityLabel(Text(label))
    .anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [target: $0] }
  }

  // MARK: - finish
  // Skip or Next on "Correct!": saves the tutorial as seen (OnboardingService), then RootView hides it.
  private func finish() {
    Track.tutorialFinished(skipped: !service.completed)        // completed = the practice word reached "Correct!"
    service.finish()
    onDone()
  }
}

// MARK: - TutorialTestPage
// One of the two pages after the practice word (see the flow above): the test's name and what it's for, a mini card
// that works like the real one (speech: a demo without the microphone), a tooltip with the pointer under the card
// while there's something to tap, the line about where the tests are, and Next / Let's go!. Skip on top.
private struct TutorialTestPage: View {
  enum Kind { case speech, listening }
  let kind: Kind
  let word: String                                          // the practice word ("cat" in the language being learned)
  let sayWord: () -> Void                                   // OnboardingService.sayWord
  let onNext: () -> Void                                    // speech page -> listening page
  let onDone: () -> Void                                    // listening page: Let's go!
  let onSkip: () -> Void

  private enum SpeechDemo { case idle, listening, done }
  @State private var speechDemo = SpeechDemo.idle
  @State private var heard = false                          // listening: the word was played, the pictures unlock
  @State private var picked: Int?                           // listening: the tapped picture (0 = the cat)
  @State private var rightTaps = 0                          // haptics
  @State private var wrongTaps = 0

  private static let order = [3, 0, 1, 2]                   // listening: where each picture sits (0 = the cat)
  private static let drawn = ["cup.and.saucer.fill", "chair.fill", "book.closed.fill"]   // the 3 other "words"
  private static let cat = OnboardingService.catImage().flatMap(UIImage.init(data:))

  var body: some View {
    GeometryReader { geo in
      let width = min(geo.size.width - 40, 340)
      VStack(spacing: 16) {
        ZStack {
          Text("How to play")
            .font(.headline)
            .foregroundStyle(.white)
          HStack {
            Spacer()
            Button("Skip", action: onSkip)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white.opacity(0.7))
              .frame(minWidth: 44, minHeight: 44)
          }
        }

        VStack(spacing: 4) {
          Label(kind == .speech ? "Pronunciation test" : "Listening test",
                systemImage: kind == .speech ? "mic.fill" : "headphones")
            .font(.title2.bold())
            .foregroundStyle(.white)
          Text(kind == .speech ? "Say your words out loud and check them." : "Hear a word and tap its picture.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
        }
        .multilineTextAlignment(.center)

        Spacer(minLength: 0)
        Group {
          if kind == .speech { speechCard(width: width) } else { listeningCard(width: width) }
        }
        .padding(16)
        .frame(width: width)
        .background(.black, in: RoundedRectangle(cornerRadius: 26))
        .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.25), lineWidth: 1) }

        VStack(spacing: 6) {
          if showsPointer {
            TutorialPointer(pointsDown: false)
              .frame(width: 46, height: 46)
              .transition(.opacity)
          }
          Text(tooltip)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: min(270, width))
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.5), radius: 6)
            .contentTransition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: tooltip)
        Spacer(minLength: 0)

        Text("You'll find both tests on the start screen once you've played a few words. Tap Test all to go through every word.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        Button(action: kind == .speech ? onNext : onDone) {
          Text(kind == .speech ? "Next" : "Let's go!")
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 20)
      .padding(.top, 4)
      .padding(.bottom, 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Color.black)
    .sensoryFeedback(.success, trigger: rightTaps)
    .sensoryFeedback(.error, trigger: wrongTaps)
  }

  // The pointer taps on the card's bottom button while it's the next thing to tap.
  private var showsPointer: Bool {
    kind == .speech ? speechDemo == .idle : !heard
  }

  private var tooltip: LocalizedStringKey {
    switch kind {
    case .speech:
      speechDemo == .done ? "A word counts as right when you say it right on the first try. You get 3 tries."
                          : "Tap to speak, then say the word out loud."
    case .listening:
      if picked != nil { "Listen to the word and tap its picture. Your first tap counts." }
      else if heard { "Which picture is it?" }
      else { "Tap the speaker to hear the word." }
    }
  }

  // MARK: - speechCard(width:)
  // The cat, the word and "Tap to speak" (or ✓ Correct! after the demo), with the 3 tries as dots.
  private func speechCard(width: CGFloat) -> some View {
    let listening = speechDemo == .listening
    return VStack(spacing: 12) {
      picture(side: min(width - 32, 220))
      Text(verbatim: word)
        .font(.title.bold())
        .foregroundStyle(.white)
      if speechDemo == .done {
        Label("Correct!", systemImage: "checkmark.circle.fill")
          .font(.title3.bold())
          .foregroundStyle(.green)
          .frame(height: 50)
          .transition(.scale.combined(with: .opacity))
      } else {
        Button(action: demoSpeech) {
          Label { Text(listening ? "Listening…" : "Tap to speak") } icon: {
            Image(systemName: listening ? "waveform" : "mic.fill")
              .symbolEffect(.variableColor.iterative, isActive: listening)
          }
          .font(.headline)
          .foregroundStyle(listening ? .white : .black)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(listening ? AnyShapeStyle(Color.red.opacity(0.85)) : AnyShapeStyle(.white), in: Capsule())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(speechDemo == .idle)
      }
      HStack(spacing: 6) {
        ForEach(0..<3, id: \.self) { i in
          Circle()
            .fill(i == 0 && speechDemo == .done ? Color.orange : Color.white.opacity(0.25))
            .frame(width: 8, height: 8)
        }
      }
      .accessibilityHidden(true)
    }
  }

  // The demo: "Listening…" for a moment, then ✓ and the word is read out, like the real test.
  private func demoSpeech() {
    withAnimation(.easeInOut(duration: 0.2)) { speechDemo = .listening }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(1400))
      SoundManager.shared.play("success")
      rightTaps += 1
      withAnimation(.spring(duration: 0.35)) { speechDemo = .done }
      try? await Task.sleep(for: .milliseconds(700))
      sayWord()
    }
  }

  // MARK: - listeningCard(width:)
  // 4 pictures and the speaker, then the word and green / red, like WordCardOverlay's listening card.
  private func listeningCard(width: CGFloat) -> some View {
    let gap: CGFloat = 10
    let side = min((width - 32 - gap) / 2, 130)
    return VStack(spacing: 14) {
      LazyVGrid(columns: [GridItem(.fixed(side), spacing: gap), GridItem(.fixed(side), spacing: gap)], spacing: gap) {
        ForEach(Self.order, id: \.self) { choice in
          tile(choice, side: side)
        }
      }
      if picked != nil {
        Text(verbatim: word)
          .font(.title2.bold())
          .foregroundStyle(.white)
          .frame(height: 72)
          .transition(.opacity)
      } else {
        Button {
          sayWord()
          withAnimation(.easeInOut(duration: 0.2)) { heard = true }
        } label: {
          Image(systemName: "speaker.wave.2.fill")
            .font(.title)
            .foregroundStyle(.black)
            .frame(width: 72, height: 72)
            .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Play the word"))
      }
    }
  }

  private func tile(_ choice: Int, side: CGFloat) -> some View {
    let isRight = picked != nil && choice == 0
    let isWrongPick = picked == choice && choice != 0
    let tint: Color? = isRight ? .green : (isWrongPick ? .red : nil)
    return Button { pick(choice) } label: {
      Group {
        if choice == 0, let cat = Self.cat {
          Image(uiImage: cat)
            .resizable()
            .scaledToFit()
            .padding(8)
        } else {
          Image(systemName: Self.drawn[max(0, choice - 1)])
            .font(.system(size: side * 0.4))
            .foregroundStyle(.gray)
        }
      }
      .frame(width: side, height: side)
      .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(tint ?? .clear, lineWidth: 3)
      }
      .overlay(alignment: .topTrailing) {
        if let tint {
          Image(systemName: isRight ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.title2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, tint)
            .padding(6)
        }
      }
      .opacity(!heard || (picked != nil && tint == nil) ? 0.4 : 1)
    }
    .buttonStyle(.plain)
    .allowsHitTesting(heard && picked == nil)
    .accessibilityLabel(Text("Picture \(choice + 1)"))
  }

  private func pick(_ choice: Int) {
    SoundManager.shared.play(choice == 0 ? "success" : "incorrect")
    if choice == 0 { rightTaps += 1 } else { wrongTaps += 1 }
    withAnimation(.easeInOut(duration: 0.25)) { picked = choice }
  }

  // The cat on a light square, like the word list's pictures.
  private func picture(side: CGFloat) -> some View {
    Group {
      if let cat = Self.cat {
        Image(uiImage: cat).resizable().scaledToFit().padding(12)
      } else {
        Image(systemName: "photo").font(.largeTitle).foregroundStyle(.gray)
      }
    }
    .frame(width: side, height: side)
    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
  }
}

// MARK: - TutorialPointer
// The PointerUp hand, white with a soft shadow, tapping toward its target over and over
// (still with Reduce Motion). Pointing down = turned upside down.
private struct TutorialPointer: View {
  let pointsDown: Bool                                      // true: above the target, pointing down
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    PointerUp()
      .fill(.white)
      .shadow(color: .black.opacity(0.7), radius: 3)
      .rotationEffect(.degrees(pointsDown ? 180 : 0))
      .phaseAnimator([false, true]) { content, pressing in  // pressing = moved toward the target, slightly smaller
        content
          .offset(y: reduceMotion ? 0 : (pressing ? 1 : -1) * (pointsDown ? 6 : -6))
          .scaleEffect(pressing && !reduceMotion ? 0.9 : 1)
      } animation: { _ in .easeInOut(duration: 0.55) }
      .accessibilityHidden(true)                            // decoration — the tooltip says what to do
  }
}

#Preview {
  OnboardingView(manager: AppManager(requestModel: RequestModel()), onDone: {})
}
