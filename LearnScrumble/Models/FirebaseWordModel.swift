//
//  FirebaseWordModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-22.
//

import Foundation

struct FirebaseWordModel: Codable, Identifiable {
    let id: String
    let word: String
    var translation: [String : String]//"language code suck as "uk-UA"": "translated word to it"
    var image: String
}
