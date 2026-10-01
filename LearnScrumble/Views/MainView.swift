//
//  MainView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI

struct MainView: View {
    let vm: WordVM
    private let boxSize: CGFloat = 55
    private let spacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 20
    private let trayPadding: CGFloat = 12
  
    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - horizontalPadding * 2
          let answerDirection: LayoutDirection = vm.isRightToleft ? .rightToLeft : .leftToRight
            Group {
                if vm.word == nil {
                    LoadingView()                                        // next word not ready yet
                } else {
                    VStack(spacing: 20) {
                        ImageComponent(image: vm.image, hint: vm.hintWord)
                            .layoutPriority(-1)                          // the image shrinks first on small screens, letters never get cut off

                        ResultWordRow(result: vm.resultWord, resetGuess: vm.resetGuess)
                        .environment(\.layoutDirection, answerDirection)

                        VStack(spacing: 10) {
                            ForEach(vm.segmentRanges.indices, id: \.self) { segIdx in
                                GuessedLettersRow(
                                    segment: vm.segmentRanges[segIdx],
                                    guessedWord: vm.guessedWord,
                                    width: contentWidth,
                                    isDimmed: vm.overlayShown,
                                    onDeselect: { vm.deselectLetter($0) }
                                )
                            }
                        }
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
        VStack(spacing: spacing) {
            ForEach(Array(scrambledRows(width: width).enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row) { letter in
                        LetterBoxView(letter: letter) { vm.selectLetter($0) }
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

    private func scrambledRows(width: CGFloat) -> [[LetterModel]] {
        let letters = vm.scrumbledWord
        let perRow = max(Int((width + spacing) / (boxSize + spacing)), 1)
        return stride(from: 0, to: letters.count, by: perRow).map {
            Array(letters[$0..<min($0 + perRow, letters.count)])
        }
    }
}

#Preview {
    MainView(vm: WordVM(questions: QuestionModel.mockQuestions, targetLanguage: "uk-UA"))
}
