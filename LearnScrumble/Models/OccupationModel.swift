//
//  OccupationModel.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-07.
//

import SwiftUI

enum Occupation: String, CaseIterable, Identifiable {
  var id: String { rawValue }
  
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
  case welder = "Welder"
  case roofer = "Roofer"
  case autoMechanic = "Auto mechanic"
  
  // Factory and production
  case factoryWorker = "Factory worker"
  case machineOperator = "Machine operator"
  case foodProductionWorker = "Food production worker"
  
  // Kitchen and hospitality
  case cook = "Cook"
  case kitchenAssistant = "Kitchen assistant"
  case waiter = "Waiter"
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
    case .welder: "Welder"
    case .roofer: "Roofer"
    case .autoMechanic: "Auto mechanic"
    case .factoryWorker: "Factory worker"
    case .machineOperator: "Machine operator"
    case .foodProductionWorker: "Food production worker"
    case .cook: "Cook"
    case .kitchenAssistant: "Kitchen assistant"
    case .waiter: "Waiter"
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
}
