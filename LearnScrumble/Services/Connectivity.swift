//
//  Connectivity.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import Network

// MARK: - Flow of this file
// Answers "is the phone online right now?" once.
//   AppManager.showFailure() -> await Connectivity.isOnline()
//   -> false: OfflineView, true: ErrorView with the real error.

enum Connectivity {
  // MARK: - isOnline
  // One-shot check: is any network path usable right now?
  // Used after a failure to tell "no internet" apart from "something else broke",
  // because some failures (Firebase reads, image downloads) hide the offline reason.
  // NWPathMonitor reports paths as a stream; the first value is the current state,
  // so it returns right away with it (satisfied = online).
  static func isOnline() async -> Bool {
    for await path in NWPathMonitor() {
      return path.status == .satisfied
    }
    return false
  }
}
