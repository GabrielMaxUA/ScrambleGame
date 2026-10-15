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
//   Speech uses its own audio session, not the app's: tapping the speaker plays the word even when the phone is on silent,
//   while the game's sound effects (SoundManager, ambient) stay quiet.

final class SpeechManager {
  private let synthesizer: AVSpeechSynthesizer = {                // iOS text-to-speech engine, kept so a new word can stop the last one
    let synthesizer = AVSpeechSynthesizer()
    synthesizer.usesApplicationAudioSession = false               // its own audio session: the word plays even on silent (SoundManager's ambient effects don't)
    return synthesizer
  }()
  
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
  // 1. Stops any word still being read, so a new tap interrupts instead of queueing.
  // 2. Uses the voice picked in Settings if it's still installed, otherwise the language's default voice.
  // 3. Uses the speed set in Settings ("speechRate", default 0.45) and starts speaking.
  func speak(_ word: String, language: String) {
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
    synthesizer.speak(utterance)
  }
}
