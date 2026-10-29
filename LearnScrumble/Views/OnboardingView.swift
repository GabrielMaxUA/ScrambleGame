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
//   -> above it: the title + Skip, and the game's top row (settings gear, speaker)
//   -> one task at a time: a pointer (PointerUp) taps on the button to use, with a tooltip saying what to do;
//      both move on as soon as the task is done (OnboardingService.instruction / pointerTarget)
//   -> the word spelled -> "Correct!" (the game's own success screen, with the 10 free words and "Let's go!")
//      -> Let's go! -> OnboardingService.completed
//   Skip / completed -> OnboardingService.finish() (saved as seen) -> onDone() -> RootView hides it.

struct OnboardingView: View {
  let manager: AppManager                                   // MainView needs it (only for its loading progress)
  var onDone: () -> Void                                    // RootView: hide the tutorial
  @State private var service: OnboardingService            // tasks + the practice game

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
      MainView(vm: service.vm, manager: manager, topInset: topInset,
               onHintToggled: service.hintToggled, onReset: service.resetTapped,
               resultButtonTitle: "Let's go!",                                       // the last screen starts the real game
               resultNote: "You get \(FreeAllowance.freeWordLimit) free words to try the app.")   // the real game, practice word

      if service.vm.guessResult == nil {                    // hidden while the right/wrong screen covers everything
        header
      }
    }
    .background(.black)
    .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in   // the pointer + tooltip, on top of everything
      GeometryReader { proxy in
        pointerLayer(anchors: anchors, in: proxy)
      }
    }
    .onChange(of: service.vm.resultWord) { service.answerChanged() }   // a letter placed or sent back
    .onChange(of: service.completed) { _, done in           // Next on "Correct!": tutorial finished
      if done { finish() }
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
        gameButton("gear", target: .settings, label: "Settings", action: service.settingsTapped)
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
    case .settings:                   "The gear opens Settings: languages, job and your daily reminder. Tap it."
    case .spellWord(let letter):      "Now spell the whole word. Start with \(Text(letter).bold())."
    case .now(let letter):            "Now \(Text(letter).bold())."
    case .finish:                     "Ready? Tap here to start playing!"
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
