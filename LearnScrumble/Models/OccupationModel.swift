//
//  OccupationModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-07.
//

import SwiftUI

// MARK: - Flow of this file
// The list of jobs offered in the profession menu.
//   ProfessionPicker lists Occupation.sorted(for: locale): alphabetical in the app language
//   ("Not listed?" is hidden since 28 Oct 2026 — see the MARK at sorted(for:))
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

  // MARK: - productID
  // The job's one-time unlock in the App Store (Purchases): bundle ID + ".job." + the case name, e.g. "…job.metalworkerWelder".
  // The case name, not the English menu name, so renaming a job's text never changes a product that was already sold.
  // Never rename a case once its product exists in App Store Connect.
  var productID: String { "com.MaxGabriel.LearnScrumble.job.\(self)" }

  // MARK: - listed(_:)
  // The menu job for a saved profession name (or its old name, see renamed); nil for typed text or nothing.
  static func listed(_ name: String) -> Occupation? {
    guard let job = Occupation(rawValue: name) ?? renamed[name], job != .notListed else { return nil }
    return job
  }

  // MARK: - renamed
  // Old menu names saved on phones before a job was renamed or merged -> the job that replaced it.
  // ProfessionPicker uses it on appear, so a saved "Welder" opens as "Metalworker & welder" instead of "Not listed?".
  static let renamed: [String: Occupation] = [
    "Welder": .metalworkerWelder        // merged 18 October 2026
  ]

  // MARK: - sorted(for:)
  // Menu order: A–Z in the app's language, using that language's alphabet rules
  // (Polish "ł" after "l", Ukrainian "і" after "и", …).
  static func sorted(for locale: Locale) -> [Occupation] {
    let jobs = allCases
      .filter { $0 != .notListed }
      .map { (job: $0, name: $0.localizedName(in: locale)) }
      .sorted { $0.name.compare($1.name, options: .caseInsensitive, range: nil, locale: locale) == .orderedAscending }
      .map(\.job)
    // MARK: - "Not listed?" hidden (28 Oct 2026)
    // Only menu jobs for now: each one is a $9.99 product, and a typed job has no product to sell.
    // To bring typed jobs back: return `jobs + [.notListed]` here and uncomment the text field in ProfessionPicker
    // (and the typed-job reset in RootView's launch task).
    // return jobs + [.notListed]
    return jobs
  }
}
