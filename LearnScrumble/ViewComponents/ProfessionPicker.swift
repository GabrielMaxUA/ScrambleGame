//
//  ProfessionPicker.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-08.
//

import SwiftUI

/// Occupation menu plus a free-text field for "Not listed?". Writes the choice into requestModel.proffession.
struct ProfessionPicker: View {
  @Bindable var requestModel: RequestModel
  var isFocused: FocusState<Bool>.Binding                   // owned by the screen using the picker, so it can react to typing
  @State private var occupation: Occupation? = nil
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Menu {
        Picker("Occupation", selection: $occupation) {
          Text("Select your profession")
            .tag(nil as Occupation?)
          ForEach(Occupation.allCases) { job in
            Text(job.displayName)
              .tag(job as Occupation?)
          }
        }
      } label: {
        HStack {
          Text(occupation?.displayName ?? "Select your profession")
          Spacer()
          Image(systemName: "chevron.up.chevron.down")
        }
        .foregroundStyle(.white)
        .contentShape(Rectangle())
      }
      
      if occupation == .notListed {
        TextField(
          "Profession",                                         // spoken by VoiceOver
          text: $requestModel.proffession,
          prompt: Text("e.g. Carpenter, Server, Chef").foregroundStyle(.white.opacity(0.5))
        )
        .foregroundStyle(.white)
        .tint(.white)
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .focused(isFocused)
        .onSubmit { isFocused.wrappedValue = false }
      }
    }
    .onChange(of: occupation) { _, newValue in
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
      if let job = Occupation(rawValue: saved) {
        occupation = job
      } else if !saved.isEmpty {
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
