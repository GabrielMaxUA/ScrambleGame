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
  
  func speak(_ word: String, language: String) {
    let utterance = AVSpeechUtterance(string: word)
    utterance.voice = AVSpeechSynthesisVoice(language: language)
    utterance.rate = 0.45
    
    synthesizer.speak(utterance)
  }
}
