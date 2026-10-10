//
//  GenerationError.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-29.
//

import SwiftUI

// Every failure the word pipeline can surface, plus what the user can actually do about it.
// AppManager routes .offline to OfflineView; everything else goes to ErrorView, which picks its
// button from `recovery` — so we never offer a Retry that can't work.
enum GenerationError: Error, Equatable {
  case offline              // no internet — OfflineView
  case timedOut             // slow network, temporary
  case serverBusy           // 429 / 5xx after our retries, temporary
  case badResponse          // garbled reply from GPT, worth another try
  case serviceUnavailable   // 4xx — missing/revoked key, billing, bad request: OUR problem, retry won't help
  case noWordsAvailable     // GPT has nothing new for this profession + language
  case reviewUnavailable    // struggle words exist but their translations couldn't be found
  case noStruggleWords      // nothing to review yet
  case unknown
  
  /// What ErrorView offers the user.
  enum Recovery {
    case retry              // temporary — trying again can work
    case changeProfession   // retrying the same profession won't help, a different one might
    case none               // nothing the user can do now — just a way back
  }
  
  var recovery: Recovery {
    switch self {
    case .offline, .timedOut, .serverBusy, .badResponse, .unknown: .retry
    case .noWordsAvailable:                                       .changeProfession
    case .serviceUnavailable, .reviewUnavailable, .noStruggleWords: .none
    }
  }
  
  /// User-facing text. LocalizedStringKey so Text() uses the app's chosen language (environment locale),
  /// and so Xcode adds each line to the String Catalog on build.
  var message: LocalizedStringKey {
    switch self {
    case .offline:            "You appear to be offline. Check your internet connection and try again."
    case .timedOut:           "This is taking longer than expected. Please try again."
    case .serverBusy:         "Our servers are busy right now. Please try again in a moment."
    case .badResponse:        "Something went wrong while preparing your words. Please try again."
    case .serviceUnavailable: "We can't prepare new words right now. We're on it — please check back later."
    case .noWordsAvailable:   "We couldn't find new words for this profession and language right now. Try again later or pick a different profession."
    case .reviewUnavailable:  "Your review words aren't available right now. Keep practicing new words and check back later."
    case .noStruggleWords:    "No struggle words yet — keep practicing!"
    case .unknown:            "Something went wrong. Please try again."
    }
  }
  
  static func from(_ error: Error) -> GenerationError {             // turns ANY thrown error into one of our cases
    if let error = error as? GenerationError { return error }
    if let urlError = error as? URLError {
      switch urlError.code {
      case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
           .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
        return .offline
      case .timedOut:
        return .timedOut
      default:
        return .unknown
      }
    }
    if error is DecodingError { return .badResponse }
    return .unknown
  }
}
