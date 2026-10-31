//
//  MenuButtonsEnum.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-29.
//

import Foundation

// MARK: - Flow of this file
// Which buttons the top row shows.
//   RootView.topRow picks a case from the phase
//   -> ButtonsTopRow draws the matching buttons.
//   The struggle-review button (.struggle, .menu) was removed on 28 Oct 2026: review is "My words" now.

enum MenuButtonsEnum {
    case back                      // the back arrow (was the settings gear until 30 Oct 2026)
}
