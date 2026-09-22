//
//  ContentView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import SwiftUI
import AVFoundation

struct MainView: View {
  @State private var vm: WordVM
  @State private var showPop: Bool = false
  @State private var showAlert: Bool = false
  @AppStorage("allSet") private var allSet = false
  var requestModel: RequestModel
  let boxSize: CGFloat = 55
  let spacing: CGFloat = 8
  
  let speechManager = SpeechManager()
  
  init(questions: [QuestionModel], requestModel: RequestModel) {
    
    self.requestModel = requestModel
    
    _vm = State(initialValue: WordVM(
      // Creates the WordVM that will back this view's @State var vm
      
      questions: questions,
      // Populates WordVM with the questions this view was handed at creation
      
      fetchMore: { existingWords in
        // Defines what WordVM should do whenever IT decides it needs more questions later
        
          await requestModel.generateMore(excluding: existingWords)
        // Fetches more questions from requestModel, skipping ones already shown (existingWords)
      }
    ))
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
        ZStack(alignment: .topTrailing){
          Color.black.opacity(0.7).ignoresSafeArea()
          if let word = vm.word {
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
                  language: requestModel.selectedLanguage.rawValue
                )
              } label: {
                Image(systemName: "speaker.wave.2.fill")
                  .frame(width: 50, height: 50)
                  .foregroundStyle(.white)
                  .glassEffect(.clear, in: .circle)
              }
            }
            .padding(.horizontal)
            .offset(y: -5)
          }
          VStack(alignment: .center) {
            Spacer()
            VStack {
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
              .clipShape(RoundedRectangle(cornerRadius: 14))
              .padding(.horizontal)
              .padding(.bottom)
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
              Text(vm.resultWord)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(vm.overlayShown ? .white.opacity(0.05) : .white)
                .padding(.bottom)
                .frame(height: 35)
                .padding(.bottom)
                .minimumScaleFactor(0.8)
              Spacer()
            }
            .frame(height: geo.size.height / 3.1)
            
            VStack(spacing: spacing) {
              ForEach(guessedSlotRows.indices, id: \.self) { i in
                HStack(spacing: 16) {
                  ForEach(guessedSlotRows[i], id: \.self) { slotIndex in
                    let letter = slotIndex < vm.guessedWord.count ? vm.guessedWord[slotIndex] : nil
                    GuessedLetterView(letter: letter) { vm.deselectLetter($0) }
                      .foregroundStyle(vm.overlayShown ? .white.opacity(0.05) : .white)
                  }
                }
              }
              Spacer()
            }
            .frame(height: geo.size.height / 3.6)
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
              Spacer()
            }//vs Srcummble letters
            .frame(height: geo.size.height / 3.3)
          }//vsmain
//          .navigationDestination(isPresented: $backToEntry){ EntryView(requestModel: requestModel)
//          }
          .alert("Want to change the settings?", isPresented: $showAlert) {
//            Button("OK", role: .destructive) {
//              allSet = false
//            }
            Button("OK", role: .destructive) {
              print("🔥 OK BUTTON TAPPED")
              allSet = false
              print("🔥 allSet is now: \(allSet)")
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
  MainView(questions: QuestionModel.mockQuestions, requestModel: RequestModel())
}
