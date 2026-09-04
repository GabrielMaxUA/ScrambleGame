//
//  WordModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-02.
//

import Foundation

struct WordModel: Codable {
  let toolName: String        // canonical English/internal name, used for the image prompt
  let originWord: String      // word in language of origin (helper)
  let targetWord: String  
}
