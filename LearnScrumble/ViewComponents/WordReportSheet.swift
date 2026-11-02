//
//  WordReportSheet.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-11-01.
//

import SwiftUI

// MARK: - Flow of this file
// "Wrong word or translation": the form behind the picture flag's second choice (ImageComponent) and the game's
// "Wrong word?" button after an answer (AnswerResultView). Shown as a sheet.
//   Two fields, filled with what the user saw: the word in the language being learned, and its translation in the
//   user's own language. The user corrects the wrong one(s) and may add a short "why".
//   -> Send stays off until a field really changed (the user must write the correct version)
//   -> send(correction) (AppManager.reportWord / reportSavedWord -> RequestModel.reportWord) -> a note:
//      received "Thanks! We'll check it and fix it for everyone." / too many today / couldn't send (Send again)
//   Nothing changes on the phone: the developer approves the correction first (functions/src/reports.ts).

struct WordReportSheet: View {
  @Environment(\.locale) private var locale              // the app's language, for the languages' names
  @Environment(\.dismiss) private var dismiss
  let targetLanguage: Languages?                          // the language being learned
  let originLanguage: Languages?                          // the user's own language
  let targetWord: String                                  // what the user saw
  let originWord: String
  var send: (RequestModel.WordCorrection) async -> RequestModel.ReportResult

  @State private var target: String
  @State private var origin: String
  @State private var note = ""
  @State private var sending = false
  @State private var result: RequestModel.ReportResult?
  @FocusState private var focused: Field?
  private enum Field { case target, origin, note }

  init(targetLanguage: Languages?, originLanguage: Languages?, targetWord: String, originWord: String,
       send: @escaping (RequestModel.WordCorrection) async -> RequestModel.ReportResult) {
    self.targetLanguage = targetLanguage
    self.originLanguage = originLanguage
    self.targetWord = targetWord
    self.originWord = originWord
    self.send = send
    _target = State(initialValue: targetWord)
    _origin = State(initialValue: originWord)
  }

  // A field counts as corrected when its trimmed text is new and not empty.
  private func changed(_ text: String, from original: String) -> String? {
    let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return typed.isEmpty || typed == original.trimmingCharacters(in: .whitespacesAndNewlines) ? nil : typed
  }
  private var correction: RequestModel.WordCorrection {
    .init(target: changed(target, from: targetWord), origin: changed(origin, from: originWord),
          note: note.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text("Type the correct word where it's wrong. We'll check it and fix it for everyone.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Section {
          TextField(text: $target) { Text(verbatim: targetWord) }
            .focused($focused, equals: .target)
            .autocorrectionDisabled()
        } header: {
          Text(verbatim: targetLanguage?.name(in: locale) ?? "")
        } footer: {
          Text("The word you're learning")
        }
        Section {
          TextField(text: $origin) { Text(verbatim: originWord) }
            .focused($focused, equals: .origin)
            .autocorrectionDisabled()
        } header: {
          Text(verbatim: originLanguage?.name(in: locale) ?? "")
        } footer: {
          Text("The translation in your language")
        }
        Section {
          TextField("Why is it wrong? (optional)", text: $note, axis: .vertical)
            .focused($focused, equals: .note)
            .lineLimit(1...3)
        }
        if let result {
          Section {
            Label { Text(message(for: result)) } icon: {
              Image(systemName: result == .received ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(result == .received ? .green : .orange)
            }
          }
        }
      }
      .navigationTitle("Wrong word?")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(result == .received ? "Done" : "Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          if sending {
            ProgressView()
          } else if result == nil || result == .failed {
            Button("Send") { Task { await submit() } }
              .disabled(!(correction.target != nil || correction.origin != nil))
          }
        }
      }
    }
    .presentationDetents([.large])
    .preferredColorScheme(.dark)                         // the app is dark everywhere
  }

  private func message(for result: RequestModel.ReportResult) -> LocalizedStringKey {
    switch result {
    case .received:   "Thanks! We'll check it and fix it for everyone."
    case .tooMany:    "Thanks! You've sent many reports today. Try again tomorrow."
    case .failed:     "Couldn't send the report. Please try again."
    case .newPicture: "Thanks! We'll check it and fix it for everyone."
    }
  }

  private func submit() async {
    guard correction.target != nil || correction.origin != nil else { return }
    focused = nil
    sending = true
    result = nil
    result = await send(correction)
    sending = false
  }
}

extension RequestModel.ReportResult: Equatable {
  static func == (a: Self, b: Self) -> Bool {
    switch (a, b) {
    case (.received, .received), (.tooMany, .tooMany), (.failed, .failed): true
    case (.newPicture(let x, let l), .newPicture(let y, let m)): x == y && l == m
    default: false
    }
  }
}
