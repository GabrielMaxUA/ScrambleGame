//
//  OccupationModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-07.
//

import SwiftUI

// MARK: - Flow of this file
// The list of jobs offered in the profession menu.
//   ProfessionPicker lists Occupation.sorted(for: locale): alphabetical in the app language, "Not listed?" last
//   -> the picked case's rawValue (fixed English name) goes into requestModel.proffession
//   -> RequestModel sends that English name to getWords (the server's GPT prompt and bank key), so it's the same whatever the app language.
//   .notListed switches the picker to a free-text field.

enum Occupation: String, CaseIterable, Identifiable {
  var id: String { rawValue }                                      // ForEach needs an id — the English name is unique
  
  // Warehouse and transport
  case warehouseWorker = "Warehouse worker"
  case forkliftOperator = "Forklift operator"
  case truckDriver = "Truck driver"
  case deliveryDriver = "Delivery driver"
  
  // Construction and trades
  case constructionWorker = "Construction worker"
  case carpenter = "Carpenter"
  case electrician = "Electrician"
  case plumber = "Plumber"
  case painter = "Painter"
  case bricklayerConcrete = "Bricklayer & concrete worker"
  case finishingWorker = "Finishing worker (tiles, drywall, plaster)"
  case metalworkerWelder = "Metalworker & welder"           // was "Welder" (see renamed)
  case handyman = "Handyman & maintenance worker"
  case roofer = "Roofer"
  case autoMechanic = "Auto mechanic"
  
  // Factory and production
  case factoryWorker = "Factory worker"
  case machineOperator = "Machine operator"
  case cncOperator = "CNC operator & machine setter"
  case foodProductionWorker = "Food production worker"
  case baker = "Baker"
  case sewingMachineOperator = "Sewing machine operator & tailor"
  
  // Kitchen and hospitality
  case cook = "Cook"
  case kitchenAssistant = "Kitchen assistant"
  case waiter = "Waiter"
  case bartender = "Bartender & barista"
  case hotelHousekeeper = "Hotel housekeeper"
  
  // Services and care
  case cleaner = "Cleaner"
  case caregiver = "Caregiver"
  case hairdresser = "Hairdresser"
  case shopAssistant = "Shop assistant"
  
  // Outdoor
  case farmWorker = "Farm worker"
  case gardener = "Gardener"
  
  case notListed = "Not listed?"
  // Shown to the user, translated through the String Catalog
  // Shown to the user. Written as literals so Xcode adds each one to the String Catalog.
  var displayName: LocalizedStringKey {
    switch self {
    
    case .warehouseWorker: "Warehouse worker"
    case .forkliftOperator: "Forklift operator"
    case .truckDriver: "Truck driver"
    case .deliveryDriver: "Delivery driver"
    case .constructionWorker: "Construction worker"
    case .carpenter: "Carpenter"
    case .electrician: "Electrician"
    case .plumber: "Plumber"
    case .painter: "Painter"
    case .bricklayerConcrete: "Bricklayer & concrete worker"
    case .finishingWorker: "Finishing worker (tiles, drywall, plaster)"
    case .metalworkerWelder: "Metalworker & welder"
    case .handyman: "Handyman & maintenance worker"
    case .roofer: "Roofer"
    case .autoMechanic: "Auto mechanic"
    case .factoryWorker: "Factory worker"
    case .machineOperator: "Machine operator"
    case .cncOperator: "CNC operator & machine setter"
    case .foodProductionWorker: "Food production worker"
    case .baker: "Baker"
    case .sewingMachineOperator: "Sewing machine operator & tailor"
    case .cook: "Cook"
    case .kitchenAssistant: "Kitchen assistant"
    case .waiter: "Waiter"
    case .bartender: "Bartender & barista"
    case .hotelHousekeeper: "Hotel housekeeper"
    case .cleaner: "Cleaner"
    case .caregiver: "Caregiver"
    case .hairdresser: "Hairdresser"
    case .shopAssistant: "Shop assistant"
    case .farmWorker: "Farm worker"
    case .gardener: "Gardener"
    case .notListed: "Not listed?"
    }
  }

  // MARK: - localizedName(in:)
  // The job's name in the given language as plain text, for sorting. Same catalog entry as displayName
  // (the key is the English rawValue), resolved in the app's language rather than the iPhone's.
  func localizedName(in locale: Locale) -> String {
    var resource = LocalizedStringResource(stringLiteral: rawValue)
    resource.locale = locale
    return String(localized: resource)
  }

  // MARK: - renamed
  // Old menu names saved on phones before a job was renamed or merged -> the job that replaced it.
  // ProfessionPicker uses it on appear, so a saved "Welder" opens as "Metalworker & welder" instead of "Not listed?".
  static let renamed: [String: Occupation] = [
    "Welder": .metalworkerWelder        // merged 18 October 2026
  ]

  // MARK: - sorted(for:)
  // Menu order: A–Z in the app's language, using that language's alphabet rules
  // (Polish "ł" after "l", Ukrainian "і" after "и", …). "Not listed?" always stays last.
  static func sorted(for locale: Locale) -> [Occupation] {
    let jobs = allCases
      .filter { $0 != .notListed }
      .map { (job: $0, name: $0.localizedName(in: locale)) }
      .sorted { $0.name.compare($1.name, options: .caseInsensitive, range: nil, locale: locale) == .orderedAscending }
      .map(\.job)
    return jobs + [.notListed]
  }
}
