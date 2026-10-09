//
//  SpeechManager.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-08.
//

import Foundation
import AVFoundation

final class SpeechManager {
  private let synthesizer = AVSpeechSynthesizer()
  
  /// Installed voices for a language, best quality first. Falls back to the same base language (e.g. "pt" for "pt-BR") if no exact match.
  static func voices(for language: String) -> [AVSpeechSynthesisVoice] {
    let all = AVSpeechSynthesisVoice.speechVoices()
    let exact = all.filter { $0.language == language }
    let base = String(language.prefix(2))
    let pool = exact.isEmpty ? all.filter { $0.language.hasPrefix(base) } : exact
    return pool.sorted { $0.quality.rawValue > $1.quality.rawValue }
  }
  
  /// Where the chosen voice is saved — one entry per target language, e.g. "voice_uk-UA".
  static func voiceKey(for language: String) -> String { "voice_\(language)" }
  
  func speak(_ word: String, language: String) {
    synthesizer.stopSpeaking(at: .immediate)                  // a new tap interrupts the previous word instead of queueing
    let utterance = AVSpeechUtterance(string: word)
    
    if let id = UserDefaults.standard.string(forKey: Self.voiceKey(for: language)),
       let chosen = AVSpeechSynthesisVoice(identifier: id) {  // voice picked in Settings, if still installed
      utterance.voice = chosen
    } else {
      utterance.voice = AVSpeechSynthesisVoice(language: language)   // default voice for the language
    }
    
    let savedRate = UserDefaults.standard.object(forKey: "speechRate") as? Double ?? 0.45   // set in Settings
    utterance.rate = Float(savedRate)
    synthesizer.speak(utterance)
  }
}
