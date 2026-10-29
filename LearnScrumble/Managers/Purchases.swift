//
//  Purchases.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import StoreKit
import Observation

// MARK: - Flow of this file
// One-time job unlocks with Apple's In-App Purchase (StoreKit 2). No subscription.
// Every job in the menu is its own non-consumable product, $9.99: "com.MaxGabriel.LearnScrumble.job.<case name>"
// (Occupation.productID). Buying it unlocks unlimited words and "My words" for that job, on every phone of the
// same Apple Account, and it comes back with Restore purchases.
//   LearnScrumbleApp -> start(): listens for purchases made outside the app (Ask to Buy, another phone) + refresh()
//   AppManager.hasAccess -> isUnlocked(current job); SettingsView's voice picker -> hasAnyUnlock
//   PaywallView -> product(for:) (price in the user's currency) -> buy(_:) -> Apple's purchase sheet
//   SettingsView "Restore purchases" -> restore()
// Testing without App Store Connect: StoreKit/LearnScrumble.storekit, set in the scheme (Run -> Options),
// has all the products; Xcode -> Debug -> StoreKit -> Manage Transactions removes a test purchase.
// The products still have to be created in App Store Connect with the same IDs before release.
//   Debug and tester builds only: SettingsView's "Unlock every profession" -> debugUnlockAll: acts as if every job was bought
//   (no StoreKit), to test the paid version from any run. Never in App Store builds (README "Tester builds").
@Observable
final class Purchases {
  static let shared = Purchases()                                  // one purchase state for the whole app

  enum Outcome { case purchased, cancelled, pending, failed }      // what buy(_:) tells PaywallView

  private(set) var unlockedIDs: Set<String> = []                   // product IDs the user owns right now
  private(set) var products: [String: Product] = [:]               // loaded products by ID (price, name)
  @ObservationIgnored private var updates: Task<Void, Never>?      // the Transaction.updates listener

  private init() {}

  var hasAnyUnlock: Bool { debugUnlocked || !unlockedIDs.isEmpty } // owns at least one job (voice picker)

  // MARK: - isUnlocked(_:)
  // Has the user bought this job? (Debug and tester builds: or the debug switch is on.)
  func isUnlocked(_ job: Occupation) -> Bool { debugUnlocked || unlockedIDs.contains(job.productID) }

  #if DEBUG || TESTFLIGHT_TOOLS
  static let debugUnlockKey = "debugUnlockAll"                     // UserDefaults, Debug and tester builds only
  var debugUnlockAll = UserDefaults.standard.bool(forKey: debugUnlockKey) {   // Settings -> Debug -> Unlock every profession
    didSet { UserDefaults.standard.set(debugUnlockAll, forKey: Self.debugUnlockKey) }
  }
  private var debugUnlocked: Bool { debugUnlockAll }
  #else
  private var debugUnlocked: Bool { false }
  #endif

  // MARK: - start
  // Once at launch: listen for transactions that arrive while the app runs (approved Ask to Buy, a purchase on
  // another phone, a refund) and read what the user already owns.
  func start() {
    guard updates == nil else { return }
    updates = Task { [weak self] in
      for await result in Transaction.updates {
        if case .verified(let transaction) = result { await transaction.finish() }
        await self?.refresh()
      }
    }
    Task { await refresh() }
  }

  // MARK: - refresh
  // Reads the user's current entitlements from Apple (only verified ones, refunded ones are left out by StoreKit).
  func refresh() async {
    var owned: Set<String> = []
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.revocationDate == nil {
        owned.insert(transaction.productID)
      }
    }
    unlockedIDs = owned
    Log.info("💳 Purchases — \(owned.count) job(s) unlocked", .app)
  }

  // MARK: - product(for:)
  // The App Store product for a job (cached after the first load). nil -> no connection, or the product doesn't exist.
  func product(for job: Occupation) async -> Product? {
    if let cached = products[job.productID] { return cached }
    do {
      guard let product = try await Product.products(for: [job.productID]).first else {
        Log.error("💳 Purchases — no product for \(job.productID)", .app)
        return nil
      }
      products[job.productID] = product
      return product
    } catch {
      Log.error("💳 Purchases — couldn't load products: \(error)", .app)
      return nil
    }
  }

  // MARK: - buy(_:)
  // Shows Apple's purchase sheet for the job.
  // Success (verified) -> finish the transaction, refresh -> .purchased. Cancel -> .cancelled.
  // Ask to Buy / waiting for the bank -> .pending (Transaction.updates unlocks it later). Anything else -> .failed.
  func buy(_ job: Occupation) async -> Outcome {
    guard let product = await product(for: job) else { return .failed }
    do {
      switch try await product.purchase() {
      case .success(let result):
        guard case .verified(let transaction) = result else { return .failed }
        await transaction.finish()
        await refresh()
        Track.jobUnlocked(product: transaction.productID)
        return .purchased
      case .userCancelled:
        return .cancelled
      case .pending:
        return .pending
      @unknown default:
        return .failed
      }
    } catch {
      Log.error("💳 Purchases — purchase failed: \(error)", .app)
      return .failed
    }
  }

  // MARK: - restore
  // "Restore purchases": AppStore.sync() asks Apple again (may ask the user to sign in), then refresh().
  // Returns false when the user cancelled Apple's sign-in: not an error, the screens just close quietly.
  // Any other failure is thrown, and the screens show "Couldn't restore purchases".
  func restore() async throws -> Bool {
    do {
      try await AppStore.sync()
    } catch where Self.isCancellation(error) {
      Log.info("💳 Purchases — restore cancelled by the user", .app)
      return false
    } catch {
      Log.error("💳 Purchases — restore failed: \(error)", .app)
      throw error
    }
    await refresh()
    return true
  }

  // MARK: - isCancellation(_:)
  // True when the user closed Apple's sheet instead of something going wrong. StoreKit reports that in several ways:
  // StoreKit 2's userCancelled, the older SKError paymentCancelled, or an Apple Account error whose
  // description (or an underlying error's) says it was cancelled.
  static func isCancellation(_ error: Error) -> Bool {
    if case StoreKitError.userCancelled = error { return true }
    if let skError = error as? SKError, skError.code == .paymentCancelled { return true }
    if error is CancellationError { return true }
    let nsError = error as NSError
    if "\(nsError)".localizedCaseInsensitiveContains("cancel") { return true }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error { return isCancellation(underlying) }
    return false
  }
}
