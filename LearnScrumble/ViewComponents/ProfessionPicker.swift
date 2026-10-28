//
//  ProfessionPicker.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI

// MARK: - Flow of this file
// Occupation menu plus a free-text field for "Not listed?". Writes the choice into requestModel.proffession.
//   EntryView / SettingsView put it inside a FieldCard
//   -> menu lists the jobs A–Z in the app language (Occupation.sorted), "Not listed?" last
//   -> user picks a job -> onChange writes its English name to requestModel.proffession
//   -> "Not listed?" -> a text field appears and writes what the user types instead
//   -> on appear, the saved profession is turned back into the menu choice.
//   RequestModel later sends proffession to the server (getWords), which picks the vocabulary from the bank or GPT.

struct ProfessionPicker: View {
  @Bindable var requestModel: RequestModel                  // where the chosen profession is stored
  var isFocused: FocusState<Bool>.Binding                   // owned by the screen using the picker, so it can react to typing
  @State private var occupation: Occupation? = nil          // current menu choice; nil = nothing picked yet
  @Environment(\.locale) private var locale                 // app language (RootView sets it) — the menu is sorted in it
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Menu {
        Picker("Occupation", selection: $occupation) {
          Text("Select your profession")
            .tag(nil as Occupation?)                        // the "nothing picked" row
          ForEach(Occupation.sorted(for: locale)) { job in   // A–Z in the app language, "Not listed?" last
            Text(job.displayName)                           // translated job name
              .tag(job as Occupation?)
          }
        }
      } label: {                                            // what the closed menu looks like
        HStack {
          Text(occupation?.displayName ?? "Select your profession")
          Spacer()
          Image(systemName: "chevron.up.chevron.down")
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())                          // whole row opens the menu
      }
      
      if occupation == .notListed {                         // free text only for "Not listed?"
        TextField(
          "Profession",                                         // spoken by VoiceOver
          text: $requestModel.proffession,
          prompt: Text("e.g. Carpenter, Server, Chef").foregroundStyle(.white.opacity(0.5))
        )
        .foregroundStyle(.white)
        .tint(.white)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled(false)
        .submitLabel(.done)
        .focused(isFocused)
        .onSubmit { isFocused.wrappedValue = false }        // Done key closes the keyboard
      }
    }
    .onChange(of: occupation) { _, newValue in              // menu choice -> requestModel.proffession
      switch newValue {
      case .none:
        requestModel.proffession = ""                            // nothing picked
      case .some(.notListed):
        if Occupation(rawValue: requestModel.proffession) != nil {   // clear only a listed job's name, keep typed text
          requestModel.proffession = ""
        }
      case .some(let job):
        requestModel.proffession = job.rawValue                  // fixed English name, e.g. "Plumber"
      }
    }
    .onAppear {                                                  // show the saved choice
      let saved = requestModel.proffession
      if let job = Occupation(rawValue: saved) ?? Occupation.renamed[saved] {   // a listed job (or its old name) -> select it;
                                                                 // onChange then saves the current English name
        occupation = job
      } else if !saved.isEmpty {                                 // typed text -> "Not listed?" with the field showing it
        occupation = .notListed
      }
    }
  }
}

#Preview {
  @Previewable @FocusState var focused: Bool           // the picker needs a focus state from outside, so the preview makes one
  FieldCard(title: "My profession", icon: "briefcase") {
    ProfessionPicker(requestModel: RequestModel(), isFocused: $focused)
  }
  .padding()
  .frame(maxHeight: .infinity)
  .background(.black)
}
