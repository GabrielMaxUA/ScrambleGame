//
//  PronunciationService.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-11-01.
//

import AVFoundation
import Observation
import Speech

// MARK: - Flow of this file
// The pronunciation test: listens to the user saying a word and checks it against the target word.
//   isSupported(_:)      -> can iOS recognise speech in this language? Decides whether the Pronunciation test exists for
//                           a language (CabinetVM) and the warning under the language pickers (EntryView, SettingsView).
//   listen(for:in:)      -> "Tap to speak" on a pronunciation card (WordCardOverlay, .speech):
//      1. permissions: speech recognition + microphone (iOS asks once; the texts are in InfoPlist.xcstrings)
//      2. SoundManager.recordingStarting: the audio session records (and plays)
//      3. SpeechListener records and recognises; iOS decides on the phone or Apple's server (the permission prompt
//         says so; requiring on-device fails at once where the language's model isn't downloaded, e.g. the simulator),
//         the target word is passed as a hint (contextualStrings)
//      4. ends as soon as any guess matches the word, or after a pause once the user stopped talking, or after 6 s
//      5. SoundManager.recordingEnded, and the outcome: .match / .noMatch / .nothingHeard / .denied / .unavailable
//   heard               -> what was recognised so far, shown live under the button
//   matches(_:target:in:) -> the check: the same words after tidying (case, punctuation, spaces), the word inside a
//                           longer phrase ("the hammer"), or very close for long words (1 letter off from 8
//                           letters, 2 from 16)
// Recording runs off the main thread (SpeechListener, nonisolated): the microphone and the recogniser call back on
// their own threads. Only the outcome and `heard` come back to the main thread.

@Observable
final class PronunciationService {
  enum Outcome: Equatable {
    case match                                           // said right
    case noMatch(heard: String)                          // something else was heard
    case nothingHeard                                    // silence, or nothing recognisable
    case denied                                          // microphone or speech recognition not allowed
    case unavailable                                     // this language, or the recogniser, can't be used right now
  }

  private(set) var isListening = false                   // the button shows "Listening…"
  private(set) var heard = ""                            // the live transcription
  private var listener: SpeechListener?                  // the running recording; nil = idle

  // MARK: - isSupported(_:)
  // iOS recognises speech in this language (its own list, e.g. "en-GB"; our regional extras like "en-GB-scotland"
  // count as their country, "zh-CN-sichuan" as Mandarin; a region iOS lacks uses another region of the language). Cached: the list doesn't change while the app runs.
  static func isSupported(_ language: Languages) -> Bool { recognitionLocale(for: language) != nil }

  private static let supported: Set<String> = Set(SFSpeechRecognizer.supportedLocales().map { normalized($0.identifier) })

  static func recognitionLocale(for language: Languages) -> Locale? {
    let parts = language.rawValue.split(separator: "-").map(String.init)
    let candidates = [language.rawValue, parts.prefix(2).joined(separator: "-"), parts.first ?? ""]
    if let exact = candidates.first(where: { supported.contains(normalized($0)) }) { return Locale(identifier: exact) }
    let base = normalized(parts.first ?? "") + "-"                  // another region of the same language:
    return supported.sorted().first { $0.hasPrefix(base) }.map { Locale(identifier: $0) }   // es-AR -> es-…, yue-HK -> yue-CN
  }

  private static func normalized(_ identifier: String) -> String {
    identifier.replacingOccurrences(of: "_", with: "-").lowercased()
  }

  // MARK: - listen(for:in:)
  // See the flow above. One recording at a time: a second tap while listening stops the first.
  func listen(for target: String, in language: Languages) async -> Outcome {
    stop()
    guard let locale = Self.recognitionLocale(for: language) else { return .unavailable }
    guard await Self.permissionsGranted() else { return .denied }
    guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else { return .unavailable }

    heard = ""
    isListening = true
    await SoundManager.shared.recordingStarting()
    let listener = SpeechListener(recognizer: recognizer, target: target) { [weak self] text in
      self?.heard = text                                 // a main-actor closure: SpeechListener hops here
    }
    self.listener = listener
    let result = await listener.run()
    self.listener = nil
    isListening = false
    SoundManager.shared.recordingEnded()

    switch result {
    case .failed: return .unavailable
    case .heard(let guesses):
      guard let best = guesses.first, !best.isEmpty else { return .nothingHeard }
      heard = best
      return guesses.contains { Self.matches($0, target: target, in: locale) } ? .match : .noMatch(heard: best)
    }
  }

  // MARK: - stop()
  // Cuts a running recording short (card closed or swiped away).
  func stop() {
    listener?.cancel()
  }

  // MARK: - permissionsGranted()
  // Speech recognition first, then the microphone; iOS shows each question only once, later it just answers.
  nonisolated private static func permissionsGranted() async -> Bool {
    let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { done in
      SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0) }
    }
    guard speech == .authorized else { return false }
    return await AVAudioApplication.requestRecordPermission()
  }

  // MARK: - matches(_:target:in:)
  // Is what was heard the target word? See the flow above.
  nonisolated static func matches(_ heard: String, target: String, in locale: Locale) -> Bool {
    let said = tidy(heard, locale: locale), word = tidy(target, locale: locale)
    guard !said.isEmpty, !word.isEmpty else { return false }
    if said == word { return true }
    if " \(said) ".contains(" \(word) ") { return true }          // "the hammer", "a hammer please"
    let noSpaces = { (s: String) in s.replacingOccurrences(of: " ", with: "") }
    if noSpaces(said) == noSpaces(word) { return true }           // "toolbox" / "tool box"; no spaces in CJK
    let allowed = word.count >= 16 ? 2 : (word.count >= 8 ? 1 : 0)   // long words: a letter or two off (the recogniser's
                                                                       // spelling); short words must match exactly
    return allowed > 0 && distance(noSpaces(said), noSpaces(word)) <= allowed
  }

  // Lowercased, punctuation and symbols out, one space between words.
  nonisolated private static func tidy(_ text: String, locale: Locale) -> String {
    let kept = text.lowercased(with: locale).unicodeScalars.map {
      CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || CharacterSet.nonBaseCharacters.contains($0)
        ? Character($0) : " "
    }
    return String(kept).split(separator: " ").joined(separator: " ")
  }

  // Levenshtein distance: letters to change, add or remove to turn one into the other.
  nonisolated private static func distance(_ a: String, _ b: String) -> Int {
    let a = Array(a), b = Array(b)
    guard !a.isEmpty else { return b.count }
    guard !b.isEmpty else { return a.count }
    var previous = Array(0...b.count)
    for i in 1...a.count {
      var current = [i] + Array(repeating: 0, count: b.count)
      for j in 1...b.count {
        current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
      }
      previous = current
    }
    return previous[b.count]
  }
}

// MARK: - SpeechListener
// One recording: microphone -> recogniser, off the main thread. run() waits until it ends and returns every guess
// (best first). It ends when a guess matches the target, after `pause` without new words once something was heard,
// after `limit`, or on cancel().
nonisolated final class SpeechListener: @unchecked Sendable {   // @unchecked: state is only touched under `lock`
  enum Result { case heard([String]), failed }

  private let recognizer: SFSpeechRecognizer
  private let target: String
  private let onHeard: @MainActor @Sendable (String) -> Void   // runs on the main thread (live text under the button)
  private let engine = AVAudioEngine()
  private let request = SFSpeechAudioBufferRecognitionRequest()
  private var task: SFSpeechRecognitionTask?
  private var guesses: [String] = []
  private var lastChange = Date()
  private var finished = false
  private var continuation: CheckedContinuation<Result, Never>?
  private let lock = NSLock()

  private static let pause: TimeInterval = 1.3          // quiet this long after speaking = done
  private static let limit: TimeInterval = 6            // never listen longer than this

  init(recognizer: SFSpeechRecognizer, target: String, onHeard: @escaping @MainActor @Sendable (String) -> Void) {
    self.recognizer = recognizer
    self.target = target
    self.onHeard = onHeard
  }

  func run() async -> Result {
    await withCheckedContinuation { continuation in
      lock.withLock { self.continuation = continuation }
      start()
    }
  }

  func cancel() { finish() }

  private func start() {
    request.shouldReportPartialResults = true
    request.contextualStrings = [target]

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else { return finish(failed: true) }   // no microphone
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [request] buffer, _ in request.append(buffer) }
    engine.prepare()
    do { try engine.start() } catch { return finish(failed: true) }

    let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self else { return }
      if let result {
        let texts = result.transcriptions.map(\.formattedString)
        let best = result.bestTranscription.formattedString
        lock.withLock {
          if best != self.guesses.first { self.lastChange = Date() }
          self.guesses = [best] + texts.filter { $0 != best }
        }
        let onHeard = self.onHeard
        Task { @MainActor in onHeard(best) }
        if result.isFinal || texts.contains(where: { PronunciationService.matches($0, target: self.target, in: self.recognizer.locale) }) {
          return finish()
        }
      }
      if let error {
        Log.error("🎙️ Speech recognition error: \(error.localizedDescription)", .sound)
        finish(failed: self.lock.withLock { self.guesses.isEmpty })   // failed before hearing anything
      }
    }
    lock.withLock { self.task = task }
    watch()
  }

  // Checks every 0.2 s for the pause after speaking and the overall limit.
  private func watch() {
    let started = Date()
    Task.detached { [weak self] in
      while let self, !self.lock.withLock({ self.finished }) {
        try? await Task.sleep(for: .milliseconds(200))
        let (spoke, quiet) = self.lock.withLock { (!self.guesses.isEmpty, Date().timeIntervalSince(self.lastChange)) }
        if (spoke && quiet >= Self.pause) || Date().timeIntervalSince(started) >= Self.limit { self.finish() }
      }
    }
  }

  // Ends once: stops the microphone and the recogniser, hands the guesses back.
  private func finish(failed: Bool = false) {
    let (continuation, task, guesses): (CheckedContinuation<Result, Never>?, SFSpeechRecognitionTask?, [String]) = lock.withLock {
      guard !finished else { return (nil, nil, []) }
      finished = true
      defer { self.continuation = nil }
      return (self.continuation, self.task, self.guesses)
    }
    guard let continuation else { return }
    if engine.isRunning { engine.stop() }
    engine.inputNode.removeTap(onBus: 0)
    request.endAudio()
    task?.cancel()
    continuation.resume(returning: failed ? .failed : .heard(guesses))
  }
}
