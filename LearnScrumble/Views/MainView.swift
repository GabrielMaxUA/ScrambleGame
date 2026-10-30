//
//  MainView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI

// MARK: - Flow of this file
// The game screen: picture, answer slots and the scrambled letter tray.
//   RootView shows it for phase .playing(vm)
//   -> reads WordVM: image + hint, guessedWord (slots), scrumbledWord (tiles), guessResult
//   -> taps go back to WordVM: selectLetter / deselectLetter / resetGuess; the picture's flag -> reportPicture
//   -> every slot filled (vm.isComplete) -> vm.checkAnswer() -> guessResult set -> AnswerResultView overlay
//   -> "next" on that overlay -> vm.nextWord()
//   No current word yet (next batch still loading) -> LoadingView instead.
//   iPhone Duo opened (both sides >= 600 pt): the picture alone, bigger, on one half; typed answer + slots + letters on the other
//   (splitLayout), so nothing sits on the fold. Every other screen keeps the single column.
//   Also used by the "How to play" tutorial (OnboardingView) with a practice word: extra top space (topInset),
//   hooks for the hint / ↻ taps, a custom last button ("Let's go!") and note; every tile reports its place for the pointer.

struct MainView: View {
    let vm: WordVM                                                     // the running session: words, letters, answers
    let manager: AppManager                                            // only used for the loading progress
    var topInset: CGFloat = 72                                         // room above the picture: RootView's top buttons, or the tutorial's instructions (OnboardingView)
    var onHintToggled: (Bool) -> Void = { _ in }                       // tutorial only: the hint popover opened (true) / closed (false)
    var onReset: () -> Void = {}                                       // tutorial only: ↻ was tapped (after the answer is cleared)
    var resultButtonTitle: LocalizedStringKey = "Next"                 // tutorial only: the right/wrong screen's button ("Let's go!")
    var resultNote: LocalizedStringKey? = nil                          // tutorial only: highlighted line on the right/wrong screen
    @Environment(\.foldLayout) private var foldLayout                 // opened iPhone Duo (RootView), for the result pop-up
    private let minTile: CGFloat = 40                                  // smallest tray tile (the size every tile used to be)
    private let maxTile: CGFloat = 52                                  // short words get bigger, easier tiles
    private let spacing: CGFloat = 8                                   // gap between tiles and between tray rows
    private let horizontalPadding: CGFloat = 20                        // screen edge padding
    private let trayPadding: CGFloat = 12                              // padding inside the tray box
  
    var body: some View {
        GeometryReader { geo in                                        // screen size decides slot and tile sizes
            let contentWidth = geo.size.width - horizontalPadding * 2
          let answerDirection: LayoutDirection = vm.isRightToleft ? .rightToLeft : .leftToRight   // answer follows the TARGET language's direction
            Group {
                if vm.word == nil {
                    LoadingView(progress: manager.requestModel.progress)                                        // next word not ready yet
                } else if let fold = FoldLayout.from(geo.size) {
                    splitLayout(size: geo.size, fold: fold, answerDirection: answerDirection)   // iPhone Duo opened: one half each side of the fold
                } else {
                    VStack(spacing: 20) {
                        picture()
                        typedAnswer(answerDirection: answerDirection)
                        slots(width: contentWidth, answerDirection: answerDirection)
                        Spacer(minLength: 0)                             // directly in this stack: the picture keeps its share
                        letterTray(width: contentWidth - trayPadding * 2)   // scrambled tiles at the bottom
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topInset)                             // room for RootView's top button row (or the tutorial header)
                    .padding(.bottom, 12)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(.black)
        .overlay {
            if let result = vm.guessResult {                             // answer checked: right/wrong screen on top
                PopupHalf(layout: foldLayout) {                          // opened iPhone Duo: on the right / top half
                AnswerResultView(
                    result: result,
                    correctAnswer: vm.word?.targetWord ?? "",
                    onNext: { vm.nextWord() },
                    nextTitle: resultButtonTitle,
                    note: resultNote
                )
                }
                .background(foldLayout == nil ? Color.clear : Color.black.opacity(0.92))   // the other half dims too
            }
        }
        .onChange(of: vm.isComplete) { _, complete in                    // last slot filled -> check the answer
            if complete { vm.checkAnswer() }
        }
    }

    // MARK: - picture / typedAnswer / slots / answerSection
    // The parts of the game: the picture (with its flag and hint), the typed answer with ↻, the answer slots and the
    // scrambled letter tray. On a phone all four one under the other; on an opened iPhone Duo the picture alone
    // (bigger) on one half and the other three on the other half.
    private func picture(maxSide: CGFloat = 280) -> some View {
        ImageComponent(image: vm.image, hint: vm.hintWord, onHintToggled: onHintToggled,
                       report: vm.pictureReport,
                       onReport: vm.canReport ? { Task { await vm.reportPicture() } } : nil,   // flag: wrong picture
                       maxSide: maxSide)
            .layoutPriority(-1)                                          // the image shrinks first on small screens, letters never get cut off
    }

    private func typedAnswer(answerDirection: LayoutDirection) -> some View {
        ResultWordRow(result: vm.resultWord, resetGuess: { vm.resetGuess(); onReset() })
            .environment(\.layoutDirection, answerDirection)
    }

    private func slots(width: CGFloat, answerDirection: LayoutDirection) -> some View {
        GuessedLettersRow(                                               // lays out every word of the answer with one shared slot size
            segments: vm.segmentRanges,
            guessedWord: vm.guessedWord,
            width: width,
            isDimmed: vm.overlayShown,
            onDeselect: { vm.deselectLetter($0) }
        )
        .environment(\.layoutDirection, answerDirection)
    }

    // The opened iPhone Duo's answer half: the typed answer, slots and letters together in the middle of it.
    // (Phones list the parts straight in their stack instead: a nested stack with a Spacer would take all the height
    // and leave the picture, which gives way first, almost nothing.)
    private func answerSection(width: CGFloat, answerDirection: LayoutDirection) -> some View {
        VStack(spacing: 40) {
            Spacer(minLength: 0)
            typedAnswer(answerDirection: answerDirection)
            slots(width: width, answerDirection: answerDirection)
            letterTray(width: width - trayPadding * 2)
            Spacer(minLength: 0)
        }
    }

    // MARK: - splitLayout
    // An opened iPhone Duo (iOS 27.1+) shows the app on its big inner screen (669 × 951 pt), folded across the middle.
    // UIHinge tells whether the hinge is open, not where the fold is, so the screen size decides: both sides at least
    // 600 pt (no single iPhone screen is that big). Then the picture alone, as big as its half allows, goes on one half
    // and the typed answer (with ↻), slots and letters on the other, so nothing sits on the fold: top / bottom in
    // portrait, left / right when wider than tall.
    // Stacked (portrait): the picture goes up between the top row's settings and sound buttons (no top inset), so it
    // can be bigger; it keeps clear of the buttons on both sides (buttonRoom).
    private func splitLayout(size: CGSize, fold: FoldLayout, answerDirection: LayoutDirection) -> some View {
        let foldGap: CGFloat = 24                                        // space kept free on each side of the fold
        let buttonRoom: CGFloat = 76                                     // the top row's round buttons, each side (stacked)
        let sideBySide = fold == .sideBySide
        let halfWidth = sideBySide ? size.width / 2 : size.width
        let halfHeight = sideBySide ? size.height : size.height / 2
        let answerWidth = halfWidth - horizontalPadding * 2 - (sideBySide ? foldGap : 0)
        let pictureSide = sideBySide
            ? min(halfWidth - horizontalPadding * 2 - foldGap, halfHeight - topInset - 12)
            : min(halfWidth - buttonRoom * 2, halfHeight - foldGap - 8)
        let pictureHalf = picture(maxSide: pictureSide)
            .padding(.horizontal, horizontalPadding)
            .padding(.top, sideBySide ? topInset : 8)                    // room for RootView's top button row; stacked: level with it
            .padding(sideBySide ? .trailing : .bottom, foldGap)
            .frame(width: halfWidth, height: halfHeight)
        let answerHalf = answerSection(width: answerWidth, answerDirection: answerDirection)
            .padding(.horizontal, horizontalPadding)
            .padding(sideBySide ? .leading : .top, foldGap)
            .padding(.top, sideBySide ? topInset : 0)
            .padding(.bottom, 12)
            .frame(width: halfWidth, height: halfHeight)
        return Group {
            if sideBySide {
                HStack(spacing: 0) { pictureHalf; answerHalf }
            } else {
                VStack(spacing: 0) { pictureHalf; answerHalf }
            }
        }
    }

    // MARK: - Letter tray
    // The box of scrambled letter tiles.
    // 1. tileLayout picks the tile size and how many tiles per row for this width.
    // 2. scrambledRows splits WordVM's scrambled letters into those rows.
    // 3. Each tile is a LetterBoxView; a tap -> vm.selectLetter -> the letter goes into the next empty slot.
    // While the answer result is showing, the tray fades to 30% and ignores taps.
    private func letterTray(width: CGFloat) -> some View {
        let tiles = tileLayout(width: width)
        return VStack(spacing: spacing) {
            ForEach(Array(scrambledRows(perRow: tiles.perRow).enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { letter in
                        LetterBoxView(letter: letter, size: tiles.size) { vm.selectLetter($0) }
                            .foregroundStyle(.white)
                            .anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { [.tile(letter.id): $0] }   // where this tile is, for the tutorial's pointer
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(trayPadding)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
        .opacity(vm.overlayShown ? 0.3 : 1)
        .disabled(vm.overlayShown)
    }

    // MARK: - tileLayout(width:)
    // Fewest rows possible at the smallest tile, spread evenly, then the biggest tile that still fits that row.
    // e.g. 27 letters -> 4 rows of 7/7/7/6 at 40pt, 10 letters -> 2 rows of 5 at 52pt.
    // Steps: how many 40pt tiles fit in a row -> rows needed -> letters per row (spread evenly)
    //        -> the tile size that fills that row, never above 52pt.
    private func tileLayout(width: CGFloat) -> (size: CGFloat, perRow: Int) {
        let count = max(vm.scrumbledWord.count, 1)
        let maxPerRow = max(Int((width + spacing) / (minTile + spacing)), 1)
        let rows = Int((Double(count) / Double(maxPerRow)).rounded(.up))
        let perRow = Int((Double(count) / Double(rows)).rounded(.up))
        let size = min(maxTile, (width + spacing) / CGFloat(perRow) - spacing)
        return (size, perRow)
    }

    // MARK: - scrambledRows(perRow:)
    // Cuts WordVM's scrambled letters into rows of `perRow` (the last row may be shorter).
    private func scrambledRows(perRow: Int) -> [[LetterModel]] {
        let letters = vm.scrumbledWord
        return stride(from: 0, to: letters.count, by: perRow).map {
            Array(letters[$0..<min($0 + perRow, letters.count)])
        }
    }
}

#Preview {
    MainView(vm: WordVM(questions: QuestionModel.mockQuestions, targetLanguage: "uk-UA"), manager: AppManager(requestModel: RequestModel()))
}

#Preview("Long words") {
    let long = QuestionModel(id: "long", word: WordModel(toolName: "sealant", originWord: "sealant", targetWord: "Rohrleitungsdichtungsmittel", imagePrompt: ""), imageData: nil)
    let multi = QuestionModel(id: "multi", word: WordModel(toolName: "tape", originWord: "tape", targetWord: "measuring tape", imagePrompt: ""), imageData: nil)
    MainView(vm: WordVM(questions: [long, multi], targetLanguage: "de-DE"), manager: AppManager(requestModel: RequestModel()))
}

#Preview("Multi-word") {
    let multi = QuestionModel(id: "multi", word: WordModel(toolName: "screwdriver", originWord: "screwdriver", targetWord: "Kreuzschlitz schraubendreher", imagePrompt: ""), imageData: nil)
    MainView(vm: WordVM(questions: [multi], targetLanguage: "de-DE"), manager: AppManager(requestModel: RequestModel()))
}
