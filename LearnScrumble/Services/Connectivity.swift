//
//  Connectivity.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import Network

enum Connectivity {
  /// One-shot check: is any network path usable right now?
  /// Used after a failure to tell "no internet" apart from "something else broke",
  /// because some failures (Firebase reads, image downloads) hide the offline reason.
  static func isOnline() async -> Bool {
    for await path in NWPathMonitor() {                        // the first value is the current state
      return path.status == .satisfied
    }
    return false
  }
}
