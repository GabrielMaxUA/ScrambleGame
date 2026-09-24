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
  @State private var showPop: Bool = false
  @State private var showAlert: Bool = false
  
  let boxSize: CGFloat = 55
  let spacing: CGFloat = 8
  let speechManager = SpeechManager()
  
  var body: some View {
    GeometryReader { geo in
      let perRow = max(Int((geo.size.width + spacing) / (boxSize + spacing)), 1)
      let totalLetters = vm.word?.targetWord.filter { $0 != " " }.count ?? 0
      let targetWord = vm.word?.targetWord ?? ""
      
      let scrambledRows = stride(from: 0, to: vm.scrumbledWord.count, by: perRow).map {
        Array(vm.scrumbledWord[$0..<min($0 + perRow, vm.scrumbledWord.count)])
      }
      ZStack(alignment: .topTrailing){
        Color.black.opacity(0.7).ignoresSafeArea()
        if vm.isLoadingMore && vm.word == nil {
          LoadingView ()
            .tint(.white)
            .frame(width: geo.size.width, height: geo.size.height)
        } else if let word = vm.word {
          HStack {
            Button {
              showAlert = true
            } label: {
              Image(systemName: "gear")
                .frame(width: 50, height: 50)
                .foregroundStyle(.white)
                .glassEffect(.clear, in: .circle)
            }
            Spacer()
            Button {
              speechManager.speak(
                word.targetWord,
                language: requestModel.selectedLanguage.id
              )
            } label: {
              Image(systemName: "speaker.wave.2.fill")
                .frame(width: 50, height: 50)
                .foregroundStyle(.white)
                .glassEffect(.clear, in: .circle)
            }
          }//hs buttons speak and options
          .padding(.horizontal)
        }
        VStack(alignment: .center) {
          Spacer()
          VStack(spacing: spacing) {
            Group {
              if let uiImage = vm.image {
                Image(uiImage: uiImage)
                  .resizable()
                  .scaledToFit()
                  .padding()
              } else {
                RoundedRectangle(cornerRadius: 14)
                  .stroke(Color.gray, lineWidth: 2)
                  .fill(.clear)
              }
            }
            .frame(width: 250, height: 250)
            .overlay(alignment: .topLeading){
              Button {
                showPop = true
              } label: {
                Image(systemName: "questionmark.circle.fill")
                  .frame(width: 60, height: 60)
                  .foregroundStyle(.white)
              }
              .popover(isPresented: $showPop) {
                Text(vm.hintWord)
                  .padding()
                  .presentationCompactAdaptation(.popover) // keeps it a small popover even on iPhone
              }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom)
            
            Text(vm.resultWord)
              .font(.title)
              .fontWeight(.bold)
              .foregroundStyle(vm.overlayShown ? .white.opacity(0.05) : .white)
              .padding(.bottom)
              .frame(height: 35)
              .padding(.bottom)
              .minimumScaleFactor(0.8)
            HStack{
              Spacer()
              Button {
                vm.resetGuess()
              } label: {
                Text("Reset")
                  .padding(.vertical, 7)
                  .padding(.horizontal, 14)
                  .foregroundStyle(.white)
                  .glassEffect(.clear, in: .buttonBorder)
              }
            }//vs reset
            .padding(.trailing)
          }
          Spacer()
          VStack(spacing: spacing) {
            ForEach(vm.segmentRanges.indices, id: \.self) { segIdx in
              let segIndices = Array(vm.segmentRanges[segIdx])
              let segCount = segIndices.count
              let availableWidth = geo.size.width - 32 // side padding
              let letterSpacing: CGFloat = segCount > 12 ? 4 : 16
              let spacingTotal = CGFloat(max(segCount - 1, 0)) * letterSpacing
              let rawSize = (availableWidth - spacingTotal) / CGFloat(max(segCount, 1))
              let slotSize = min(30, max(rawSize, 12)) // never bigger than default, floor so it stays tappable
              
              HStack(spacing: letterSpacing) {
                ForEach(segIndices, id: \.self) { slotIndex in
                  let letter = slotIndex < vm.guessedWord.count ? vm.guessedWord[slotIndex] : nil
                  GuessedLetterView(letter: letter, size: slotSize) { vm.deselectLetter($0) }
                    .foregroundStyle(vm.overlayShown ? .white.opacity(0.05) : .white)
                }
              }
            }//FE guessed
          }//guessed vs
          .padding(.bottom)
          Spacer()
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
            Spacer()
          }//vs Srcummble letters
          Spacer()
        }//vsmain
        .alert("Want to change the settings?", isPresented: $showAlert) {
          Button("OK", role: .destructive) {
            onExitToSettings()
          }
          Button(role: .cancel) { }
        }
      }//zs
      .overlay{
        if let result = vm.guessResult {
          VStack {
            Spacer()
            Text(result == .correct ? "Correct!" : "Incorrect")
              .font(.largeTitle)
              .fontWeight(.bold)
              .foregroundStyle(result == .correct ? .green : .red)
              .padding(.bottom)
            if result == .incorrect, let word = vm.word {
              Text("Correct answer was: \(word.targetWord)")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom)
            } else {
              Spacer().frame(height: 8)
            }
            Spacer()
            Button {
              vm.nextWord()
            } label: {
              Text("Next")
                .padding()
                .foregroundStyle(.white)
                .glassEffect(.clear, in: .buttonBorder)
            }
            Spacer()
          }
          .frame(width: geo.size.width, height: geo.size.height)
          .background(Color.black.opacity(0.7))
        }
      }
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
    onExitToSettings: {}
  )
}
