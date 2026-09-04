//
//  ContentView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI

struct MainView: View {
  @State private var vm: WordVM
  var requestModel: RequestModel
  let boxSize: CGFloat = 55
  let spacing: CGFloat = 8
  
  init(questions: [QuestionModel], requestModel: RequestModel) {
    self.requestModel = requestModel
    _vm = State(initialValue: WordVM(
      questions: questions,
      fetchMore: { existingWords in
        await requestModel.generateMore(excluding: existingWords)
      }
    ))
  }
  
  func guessedRowScale(availableWidth: CGFloat) -> CGFloat {
    let letterWidth: CGFloat = 30
    let neededWidth = CGFloat(vm.guessedWord.count) * letterWidth
    + CGFloat(max(vm.guessedWord.count - 1, 0)) * spacing
    guard neededWidth > availableWidth, neededWidth > 0 else { return 1 }
    return availableWidth / neededWidth
  }
  
  var body: some View {
    GeometryReader { geo in
      let perRow = max(Int((geo.size.width + spacing) / (boxSize + spacing)), 1)
      let totalLetters = vm.word?.targetWord.filter { $0 != " " }.count ?? 0
      let guessedSlotRows = stride(from: 0, to: totalLetters, by: perRow).map {
        Array($0..<min($0 + perRow, totalLetters))
      }
      let scrambledRows = stride(from: 0, to: vm.scrumbledWord.count, by: perRow).map {
        Array(vm.scrumbledWord[$0..<min($0 + perRow, vm.scrumbledWord.count)])
      }
      NavigationStack {
        ZStack {
          Color.black.opacity(0.7).ignoresSafeArea()
          VStack(alignment: .center) {
            VStack {
              Spacer()
              Group {
                if let uiImage = vm.image {
                  Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                } else {
                  ProgressView()
                }
              }
              .frame(width: 250, height: 250)
              .clipShape(RoundedRectangle(cornerRadius: 14))
              .padding(.bottom)
              
              Text(vm.resultWord)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.bottom)
                .frame(height: 35)
                .padding(.bottom)
              Spacer()
            }
            .frame(height: geo.size.height / 2.6)
            
            VStack(spacing: spacing) {
              ForEach(guessedSlotRows.indices, id: \.self) { i in
                HStack(spacing: 16) {
                  ForEach(guessedSlotRows[i], id: \.self) { slotIndex in
                    let letter = slotIndex < vm.guessedWord.count ? vm.guessedWord[slotIndex] : nil
                    GuessedLetterView(letter: letter) { vm.deselectLetter($0) }
                  }
                }
              }
              Spacer()
            }
            .frame(height: geo.size.height / 3.8)
            .padding(.bottom)
            
            VStack {
              ForEach(scrambledRows.indices, id: \.self) { i in
                HStack(spacing: spacing) {
                  ForEach(scrambledRows[i]) { letter in
                    LetterBoxView(letter: letter) { vm.selectLetter($0) }
                  }
                }
                .frame(maxWidth: .infinity)
              }
              Spacer()
            }
            .frame(height: geo.size.height / 3.3)
          }//vsmain
        }//zs
      }//nav
      
      .onChange(of: vm.isComplete) { _, complete in
        if complete { vm.checkAnswer() }
      }
      .overlay {
        if let result = vm.guessResult {
          VStack {
            Text(result == .correct ? "Correct!" : "Incorrect")
              .font(.title)
              .fontWeight(.bold)
              .foregroundStyle(.white)
            
            if result == .incorrect, let word = vm.word {
              Text(word.targetWord)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom)
            } else {
              Spacer().frame(height: 8)
            }
            
            Button("Next") { vm.nextWord() }
          }
          .frame(width: geo.size.width, height: geo.size.height)
          .background(Color.black.opacity(0.7))
        }
      }
    }//geo
  }
}

#Preview {
  MainView(questions: QuestionModel.mockQuestions, requestModel: RequestModel())
}
