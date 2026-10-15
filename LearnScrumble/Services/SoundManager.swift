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
// All audio work runs on its own background queue, never on the main thread:
// activating the audio session can block for a moment (iOS warns about it), which made taps feel sticky.
//   init -> the audio session is set up once (playback, mixed with the user's music)
//   play -> returns immediately; on the queue: reuse that sound's player (rewound) or load it once, then play.

nonisolated final class SoundManager: @unchecked Sendable {        // @unchecked: `players` is only ever touched on `queue`
  static let shared = SoundManager()                               // one shared player for the whole app
  
  private let queue = DispatchQueue(label: "LearnScrumble.SoundManager", qos: .userInitiated)   // every audio call runs here, in order
  private var players: [String: AVAudioPlayer] = [:]              // one loaded player per sound, reused (a released player goes silent)
  
  // MARK: - init
  // Private: only `shared` exists. Sets the audio session up once, on the background queue:
  // playback, mixed with other audio (doesn't stop the user's music), then activated.
  // Any audio error is logged, never shown to the user.
  private init() {
    queue.async {
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
      } catch {
        print("❌ Audio session error: \(error.localizedDescription)")
      }
    }
  }
  
  // MARK: - play
  // Returns right away — the caller (a tap on the main thread) never waits. On the background queue:
  // 1. This sound was played before -> rewind its player.
  // 2. First time -> find the file in the app bundle (.mp3 or .wav; missing: log and stop), load it once, keep it.
  // 3. Play.
  // Any audio error is logged, never shown to the user.
  func play(_ sound: String) {
    queue.async { [self] in
      let player: AVAudioPlayer
      if let loaded = players[sound] {
        loaded.currentTime = 0
        player = loaded
      } else {
        guard let url = Bundle.main.url(forResource: sound, withExtension: "mp3")
                ?? Bundle.main.url(forResource: sound, withExtension: "wav") else {
          print("❌ Sound not found: \(sound).mp3 or \(sound).wav")
          return
        }
        do {
          player = try AVAudioPlayer(contentsOf: url)
          player.prepareToPlay()
          players[sound] = player
        } catch {
          print("❌ Audio error: \(error.localizedDescription)")
          return
        }
      }
      player.play()
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

