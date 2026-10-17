//
//  SpeechManager.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-08.
//

import Foundation
import AVFoundation

// MARK: - Flow of this file
// Reads a word aloud in the target language.
//   RootView owns one SpeechManager -> ButtonsTopRow's speaker button -> speak(word, language)
//   SettingsView -> voices(for:) lists voices to pick from, saved under voiceKey(for:) in UserDefaults
//   speak() reads that saved voice and the "speechRate" setting.
// Silent switch: the user tapped the speaker on purpose, so the word must play even when the phone is on silent,
// while the game's sound effects stay quiet. The app has one audio session, so SoundManager switches it:
//   speak -> SoundManager.speechStarting (.playback) -> the word is spoken
//   word finished, or cut off by the next tap (delegate below) -> SoundManager.speechEnded (back to .ambient)

@MainActor
final class SpeechManager: NSObject, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()                  // iOS text-to-speech engine, kept so a new word can stop the last one

  override init() {
    super.init()
    synthesizer.delegate = self                                    // tells us when a word finished, so the session goes back to .ambient
  }

  // MARK: - voices(for:)
  // Installed voices for a language, best quality first. Falls back to the same base language
  // (e.g. "pt" for "pt-BR") if no exact match.
  // Steps: all voices -> keep exact language matches -> none? keep same base language -> sort best quality first.
  static func voices(for language: String) -> [AVSpeechSynthesisVoice] {
    let all = AVSpeechSynthesisVoice.speechVoices()
    let exact = all.filter { $0.language == language }
    let base = String(language.prefix(2))
    let pool = exact.isEmpty ? all.filter { $0.language.hasPrefix(base) } : exact
    return pool.sorted { $0.quality.rawValue > $1.quality.rawValue }
  }

  // MARK: - voiceKey(for:)
  // Where the chosen voice is saved — one entry per target language, e.g. "voice_uk-UA".
  static func voiceKey(for language: String) -> String { "voice_\(language)" }

  // MARK: - speak
  // 1. Nothing to read -> stop (no word = no "finished" callback, which would leave the session on .playback).
  // 2. Stops any word still being read, so a new tap interrupts instead of queueing.
  // 3. Uses the voice picked in Settings if it's still installed, otherwise the language's default voice,
  //    and the speed set in Settings ("speechRate", default 0.45).
  // 4. SoundManager switches the session to .playback first, then the word is spoken.
  func speak(_ word: String, language: String) {
    guard !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: word)

    if let id = UserDefaults.standard.string(forKey: Self.voiceKey(for: language)),
       let chosen = AVSpeechSynthesisVoice(identifier: id) {
      utterance.voice = chosen
    } else {
      utterance.voice = AVSpeechSynthesisVoice(language: language)
    }

    let savedRate = UserDefaults.standard.object(forKey: "speechRate") as? Double ?? 0.45
    utterance.rate = Float(savedRate)
    SoundManager.shared.speechStarting { [self] in
      synthesizer.stopSpeaking(at: .immediate)                     // a quicker tap may have started meanwhile: newest word wins
      synthesizer.speak(utterance)
    }
  }

  // MARK: - AVSpeechSynthesizerDelegate
  // Each spoken word ends exactly once: finished, or cut off by the next tap. Either way -> SoundManager.speechEnded,
  // which returns to .ambient once no word is left. nonisolated: iOS may call these off the main thread.
  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    SoundManager.shared.speechEnded()
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    SoundManager.shared.speechEnded()
  }
}
