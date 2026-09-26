//
//  ButtonstopRow.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

struct ButtonsTopRow: View {
  @Binding var showMenu: Bool          // was @State
  @State private var showAlert = false
  @State private var type: MenuAlert = .settings
  let speechManager: SpeechManager
  let requestModel: RequestModel
  let word: String
  let onExitToSettings: () -> Void
  let onReviewStruggle: () -> Void
  
    var body: some View {
      HStack {
        GlassEffectContainer {
          HStack{
            if showMenu {
              Button {
                showAlert = true
                type = .settings
              } label: {
                Image(systemName: "gear")
                  .frame(width: 50, height: 50)
                  .foregroundStyle(.white)
                  .glassEffect(.clear, in: .circle)
              }
              Button {
                showAlert = true
                type = .reviewStruggle
              } label: {
                Image(systemName: "10.arrow.trianglehead.counterclockwise.hi")
                  .frame(width: 50, height: 50)
                  .foregroundStyle(.white)
                  .glassEffect(.clear, in: .circle)
              }
              .offset(x: showMenu ? -7 : 0)
            }//if showMenu
            
            Button {
              withAnimation {
                showMenu.toggle()
              }
            } label: {
              Image(systemName: showMenu ? "chevron.left" : "chevron.right")
                .frame(width: 50, height: 50)
                .foregroundStyle(.white)
                .glassEffect(.clear, in: .circle)
            }
            .offset(x: showMenu ? -14 : 0)
          }//hs buttons
        }//glass Container buttonsLeading
        Spacer()
        Button {
          speechManager.speak(word,
                              language: requestModel.selectedLanguage.id)
        } label: {
          Image(systemName: "speaker.wave.2.fill")
            .frame(width: 50, height: 50)
            .foregroundStyle(.white)
            .glassEffect(.clear, in: .circle)
        }
      }//hs buttons speak and options
      
      .alert(type.title, isPresented: $showAlert) {
        Button("OK"){
          switch type {
          case .settings: onExitToSettings()
          case .reviewStruggle: onReviewStruggle()
          }
        }
        Button("Cancel", role: .cancel){}
      } message: {
        Text(type.message)
      }
    }
}

#Preview {
  VStack{
    ButtonsTopRow(showMenu: .constant(false), speechManager: SpeechManager(), requestModel: RequestModel(), word: "hammer", onExitToSettings: {}, onReviewStruggle: {})
  }.background(.black)
}
