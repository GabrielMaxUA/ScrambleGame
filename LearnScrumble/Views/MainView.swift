//
//  MainView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI

struct MainView: View {
    let vm: WordVM
    let manager: AppManager
    private let minTile: CGFloat = 40                                  // smallest tray tile (the size every tile used to be)
    private let maxTile: CGFloat = 52                                  // short words get bigger, easier tiles
    private let spacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 20
    private let trayPadding: CGFloat = 12
  
    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - horizontalPadding * 2
          let answerDirection: LayoutDirection = vm.isRightToleft ? .rightToLeft : .leftToRight
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

                        letterTray(width: contentWidth - trayPadding * 2)
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
            if let result = vm.guessResult {
                AnswerResultView(
                    result: result,
                    correctAnswer: vm.word?.targetWord ?? "",
                    onNext: { vm.nextWord() }
                )
            }
        }
        .onChange(of: vm.isComplete) { _, complete in
            if complete { vm.checkAnswer() }
        }
    }

    // MARK: - Letter tray

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
        .disabled(vm.overlayShown)                                       // no tile taps while the answer result is showing
    }

    // Fewest rows possible at the smallest tile, spread evenly, then the biggest tile that still fits that row.
    // e.g. 27 letters -> 4 rows of 7/7/7/6 at 40pt, 10 letters -> 2 rows of 5 at 52pt.
    private func tileLayout(width: CGFloat) -> (size: CGFloat, perRow: Int) {
        let count = max(vm.scrumbledWord.count, 1)
        let maxPerRow = max(Int((width + spacing) / (minTile + spacing)), 1)
        let rows = Int((Double(count) / Double(maxPerRow)).rounded(.up))
        let perRow = Int((Double(count) / Double(rows)).rounded(.up))
        let size = min(maxTile, (width + spacing) / CGFloat(perRow) - spacing)
        return (size, perRow)
    }

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
