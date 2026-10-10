//
//  SoundManager.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-10.
//

import AVFoundation
import SwiftUI

final class SoundManager {
  static let shared = SoundManager()
  
  private var players: [String: AVAudioPlayer] = [:]
  
  private init() {}
  
  func play(_ sound: String) {
    print("🔊 Requested sound: \(sound)")
    
    // Find the sound in either format.
    guard let url =
            Bundle.main.url(forResource: sound, withExtension: "mp3")
            ?? Bundle.main.url(forResource: sound, withExtension: "wav")
            else {
      print("❌ Sound not found: \(sound).mp3 or \(sound).wav")
      return
    }
    
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      try session.setActive(true)
      
      let player = try AVAudioPlayer(contentsOf: url)
      players[sound] = player
      
      player.prepareToPlay()
      let didPlay = player.play()
      
      print("🎵 Playing: \(url.lastPathComponent)")
      print("🎵 Playback started: \(didPlay)")
    } catch {
      print("❌ Audio error: \(error.localizedDescription)")
    }
  }
}
extension View {
  /// Plays the notification sound each time an alert is presented.
  /// Alert content doesn't reliably get `onAppear`, so this watches the alert's `isPresented` flag instead.
  func alertSound(isPresented: Bool, sound: String = "notification") -> some View {
    onChange(of: isPresented) { _, presented in
      if presented { SoundManager.shared.play(sound) }
    }
  }
}

