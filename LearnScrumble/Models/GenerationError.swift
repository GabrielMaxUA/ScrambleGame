//
//  GenerationError.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-29.
//

import Foundation
enum GenerationError: LocalizedError {
    case offline
    case timedOut
    case serverBusy
    case badResponse
    case noWordsAvailable
    case reviewUnavailable
    case unknown

    var errorDescription: String? {                                   // user-facing text, safe to show in ErrorView
        switch self {
        case .offline:           return "You appear to be offline. Check your internet connection and try again."
        case .timedOut:          return "This is taking longer than expected. Please try again."
        case .serverBusy:        return "Our servers are busy right now. Please try again in a moment."
        case .badResponse:       return "Something went wrong while preparing your words. Please try again."
        case .noWordsAvailable:  return "We couldn't find new words for this profession and language right now. Try again later or pick a different profession."
        case .reviewUnavailable: return "Your review words couldn't be loaded right now. Please try again."
        case .unknown:           return "Something went wrong. Please try again."
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
