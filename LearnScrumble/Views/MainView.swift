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
//   -> taps go back to WordVM: selectLetter / deselectLetter / resetGuess
//   -> every slot filled (vm.isComplete) -> vm.checkAnswer() -> guessResult set -> AnswerResultView overlay
//   -> "next" on that overlay -> vm.nextWord()
//   No current word yet (next batch still loading) -> LoadingView instead.

struct MainView: View {
    let vm: WordVM                                                     // the running session: words, letters, answers
    let manager: AppManager                                            // only used for the loading progress
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
                } else {
                    VStack(spacing: 20) {
                        ImageComponent(image: vm.image, hint: vm.hintWord)
                            .layoutPriority(-1)                          // the image shrinks first on small screens, letters never get cut off

                        ResultWordRow(result: vm.resultWord, resetGuess: vm.resetGuess)
                        .environment(\.layoutDirection, answerDirection)

                        GuessedLettersRow(                               // lays out every word of the answer with one shared slot size
                            segments: vm.segmentRanges,
                            guessedWord: vm.guessedWord,
                            width: contentWidth,
                            isDimmed: vm.overlayShown,
                            onDeselect: { vm.deselectLetter($0) }
                        )
                        .environment(\.layoutDirection, answerDirection)
                        Spacer(minLength: 0)

                        letterTray(width: contentWidth - trayPadding * 2)   // scrambled tiles at the bottom
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 72)                                   // room for RootView's top button row
                    .padding(.bottom, 12)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(.black)
        .overlay {
            if let result = vm.guessResult {                             // answer checked: right/wrong screen on top
                AnswerResultView(
                    result: result,
                    correctAnswer: vm.word?.targetWord ?? "",
                    onNext: { vm.nextWord() }
                )
            }
        }
        .onChange(of: vm.isComplete) { _, complete in                    // last slot filled -> check the answer
            if complete { vm.checkAnswer() }
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
