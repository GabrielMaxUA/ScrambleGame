//
//  ContentView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI
import AVFoundation

struct MainView: View {
  let requestModel: RequestModel
  let vm: WordVM
  let onExitToSettings: () -> Void
  let onReviewStruggle: () -> Void
  @State private var showPop: Bool = false
  @State private var showAlert: Bool = false
  @State private var showReviewStruggle: Bool = false
  @State private var showMenu: Bool = false
  @State private var alertType: MenuAlert = .settings
  let speechManager = SpeechManager()
  let boxSize: CGFloat = 55
  let spacing: CGFloat = 8
  
  var body: some View {
    GeometryReader { geo in
      let perRow = max(Int((geo.size.width + spacing) / (boxSize + spacing)), 1)
      //      let totalLetters = vm.word?.targetWord.filter { $0 != " " }.count ?? 0
      let targetWord = vm.word?.targetWord ?? ""
      
      let scrambledRows = stride(from: 0, to: vm.scrumbledWord.count, by: perRow).map {
        Array(vm.scrumbledWord[$0..<min($0 + perRow, vm.scrumbledWord.count)])
      }
      ZStack(alignment: .topTrailing){
        Color.black.opacity(0.7).ignoresSafeArea()
          .onTapGesture {
            withAnimation {
              showMenu = false
            }
          }
        if vm.isLoadingMore && vm.word == nil {
          LoadingView ()
            .tint(.white)
            .frame(width: geo.size.width, height: geo.size.height)
        } else if let word = vm.word {
          VStack(spacing: spacing) {
            HStack {
              ButtonsTopRow(showMenu: $showMenu, speechManager: speechManager, requestModel: requestModel, word: targetWord, onExitToSettings: onExitToSettings, onReviewStruggle: onReviewStruggle)
            }//hs buttons speak and options
            .padding(.horizontal)
            ImageComponent(image: vm.image, hint: vm.hintWord)
            ResultWordRow(result: vm.resultWord, resetGuess: vm.resetGuess)
              .padding(.bottom)
            Spacer()
            VStack {
              ForEach(vm.segmentRanges.indices, id: \.self) { segIdx in
                GuessedLettersRow(
                  segment: vm.segmentRanges[segIdx],
                  guessedWord: vm.guessedWord,
                  width: geo.size.width,
                  isDimmed: vm.overlayShown,
                  onDeselect: {
                    vm.deselectLetter($0)
                  })
              }//FE guessed
              Spacer()
            }//guessed vs
            .padding(.bottom)
            VStack {
              ForEach(scrambledRows.indices, id: \.self) { i in
                HStack(spacing: spacing) {
                  ForEach(scrambledRows[i]) { letter in
                    LetterBoxView(letter: letter) { vm.selectLetter($0) }
                      .foregroundStyle(vm.overlayShown ? .white.opacity(0.05) : .white)
                  }
                }
                .frame(maxWidth: .infinity)
              }
            }//vs Srcummble letters
            .padding(.bottom, 30)
          }//vsmain
          
        }
      }//zs
      .overlay {
        if let result = vm.guessResult {
          AnswerResultView(
            result: result,
            correctAnswer: vm.word?.targetWord ?? "",
            onNext: { vm.nextWord() }
          )
        }
      }//overlay
      .onChange(of: requestModel.questions) { _, newQuestions in
        vm.questions = newQuestions // or however WordVM expects to be updated
        vm.setupCurrentWord()
      }
      .onChange(of: vm.isComplete) { _, complete in
        if complete { vm.checkAnswer() }
      }
    }//geo
  }
}

#Preview {
  MainView(
    requestModel: RequestModel(),
    vm: WordVM(questions: QuestionModel.mockQuestions, targetLanguage: "uk-UA"),
    onExitToSettings: {}, onReviewStruggle: {}
  )
}
