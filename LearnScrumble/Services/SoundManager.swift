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
//   init -> the audio session is set up once (ambient: silent when the phone's silent switch is on, mixed with the user's music)
//   play -> returns immediately; on the queue: reuse that sound's player (rewound) or load it once, then play.
// It also owns the switch for spoken words (SpeechManager), because the app has one audio session and one category at a time:
//   speechStarting -> .playback (plays even on silent, lowers the user's music), then the word is spoken
//   speechEnded    -> when no word is being spoken any more: back to .ambient, the user's music comes back up
//   A tap sound made while a word is spoken is heard on silent too: only for that second or two.

nonisolated final class SoundManager: @unchecked Sendable {        // @unchecked: `players` is only ever touched on `queue`
  static let shared = SoundManager()                               // one shared player for the whole app
  
  private let queue = DispatchQueue(label: "LearnScrumble.SoundManager", qos: .userInitiated)   // every audio call runs here, in order
  private var players: [String: AVAudioPlayer] = [:]              // one loaded player per sound, reused (a released player goes silent)
  private var wordsSpeaking = 0                                    // words started and not finished yet (from any SpeechManager); only touched on `queue`

  // MARK: - init
  // Private: only `shared` exists. Sets the audio session up once, on the background queue:
  // ambient — game sounds follow the silent switch (muted phone = no sounds) and mix with the user's music —
  // then activated.
  // Any audio error is logged, never shown to the user.
  private init() {
    queue.async {
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
      } catch {
        Log.error("❌ Audio session error: \(error.localizedDescription)", .sound)
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
          Log.error("❌ Sound not found: \(sound).mp3 or \(sound).wav", .sound)
          return
        }
        do {
          player = try AVAudioPlayer(contentsOf: url)
          player.prepareToPlay()
          players[sound] = player
        } catch {
          Log.error("❌ Audio error: \(error.localizedDescription)", .sound)
          return
        }
      }
      player.play()
    }
  }

  // MARK: - speechStarting(then:)
  // SpeechManager calls this when the user taps the speaker. On the queue:
  // 1. Count the word.
  // 2. Session -> .playback, spoken-audio mode, ducking the user's music: the word plays even when the phone is on silent.
  // 3. Back on the main thread, `speak` reads the word (after the switch, so it isn't muted).
  func speechStarting(then speak: @escaping @MainActor @Sendable () -> Void) {
    queue.async { [self] in
      wordsSpeaking += 1
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
      } catch {
        Log.error("❌ Speech audio session error: \(error.localizedDescription)", .sound)
      }
      DispatchQueue.main.async { speak() }
    }
  }

  // MARK: - speechEnded
  // SpeechManager calls this when a word finished or was cut off by the next one. On the queue:
  // 1. One word fewer. Another word still speaking (quick double tap) -> stay on .playback.
  // 2. None left: deactivate so the user's music comes back to full volume (may fail while a tap sound is
  //    still playing; that's fine), then back to .ambient for the game's sounds.
  func speechEnded() {
    queue.async { [self] in
      wordsSpeaking = max(0, wordsSpeaking - 1)
      guard wordsSpeaking == 0 else { return }
      let session = AVAudioSession.sharedInstance()
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      do {
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
      } catch {
        Log.error("❌ Audio session error: \(error.localizedDescription)", .sound)
      }
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

