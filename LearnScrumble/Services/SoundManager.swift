//
//  SoundManager.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-10.
//

import AVFoundation
import SwiftUI

// MARK: - Flow of this file
// Plays short sound effects bundled with the app (.mp3 or .wav).
//   Views call SoundManager.shared.play("name") on taps, right/wrong answers, etc.
//   .alertSound(isPresented:) plays "notification" whenever an alert opens.

final class SoundManager {
  static let shared = SoundManager()                               // one shared player for the whole app
  
  private var players: [String: AVAudioPlayer] = [:]              // keeps each playing sound alive until it finishes (a released player goes silent)
  
  // MARK: - init
  // Private: only `shared` exists.
  private init() {}
  
  // MARK: - play
  // 1. Finds the sound file in the app bundle, as .mp3 or .wav — missing: logs and stops.
  // 2. Sets the audio session to playback, mixed with other audio (doesn't stop the user's music).
  // 3. Creates a player, stores it in `players` so it isn't released mid-sound, and plays.
  // Any audio error is logged, never shown to the user.
  func play(_ sound: String) {
    print("🔊 Requested sound: \(sound)")
    
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
  // MARK: - alertSound
  // Plays the notification sound each time an alert is presented.
  // Alert content doesn't reliably get `onAppear`, so this watches the alert's `isPresented` flag instead:
  // flag turns true -> SoundManager plays the sound.
  func alertSound(isPresented: Bool, sound: String = "notification") -> some View {
    onChange(of: isPresented) { _, presented in
      if presented { SoundManager.shared.play(sound) }
    }
  }
}

