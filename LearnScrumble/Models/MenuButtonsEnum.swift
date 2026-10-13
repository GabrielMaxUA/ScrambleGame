//
//  MenuButtonsEnum.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-29.
//

import Foundation

// MARK: - Flow of this file
// Which buttons the top row shows.
//   RootView.topRow picks a case from the phase and whether struggle words exist
//   -> ButtonsTopRow draws the matching buttons.

enum MenuButtonsEnum {
    case struggle                  // only the "review struggle words" button
    case settings                  // only the settings gear
    case menu                      // both: struggle review + settings
}
