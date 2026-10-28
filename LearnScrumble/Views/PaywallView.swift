//
//  PaywallView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-28.
//

import SwiftUI
import StoreKit

// MARK: - Flow of this file
// The unlock screen for the current job (a sheet over RootView, from any "Unlock" button).
//   Purchases.product(for:) -> the price in the user's own currency ($9.99 in the US)
//   -> "Unlock for $9.99" -> Purchases.buy(_:) -> Apple's purchase sheet
//      bought -> onUnlocked (sheet closes, the game can go on); cancelled -> nothing; pending (Ask to Buy) / failed -> a note
//   -> "Restore purchases" -> Purchases.restore(); the job already owned -> onUnlocked
//   -> "Not now" -> onClose
//   No product (offline, or not set up in App Store Connect) -> the button stays disabled with a note.

struct PaywallView: View {
  let job: Occupation                                    // the job to unlock
  var onUnlocked: () -> Void                             // the job is unlocked now
  var onClose: () -> Void                                // "Not now"
  @State private var product: Product?                   // loaded on appear; nil while loading or when unavailable
  @State private var isLoading = true                    // the product is being loaded
  @State private var isBuying = false                    // Apple's sheet is open / restore is running
  @State private var note: LocalizedStringKey?           // pending / failed / unavailable message under the button

  var body: some View {
    VStack(spacing: 24) {
      VStack(spacing: 8) {
        Image(systemName: "lock.open.fill")
          .font(.system(size: 44))
          .foregroundStyle(.yellow)
          .accessibilityHidden(true)
        Text("Unlock your profession")
          .font(.title.bold())
          .foregroundStyle(.white)
        Text(job.displayName)
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
      }
      .multilineTextAlignment(.center)
      .padding(.top, 32)

      VStack(alignment: .leading, spacing: 14) {
        benefit("Unlimited words and pictures for this profession", icon: "infinity")
        benefit("My words: every word you've played, with your right and wrong answers", icon: "list.bullet.rectangle")
        benefit("Repeat all your words, even without internet", icon: "arrow.counterclockwise")
        benefit("Choose a different voice", icon: "speaker.wave.2")
        benefit("One payment, no subscription", icon: "checkmark.seal")
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Spacer(minLength: 0)

      VStack(spacing: 12) {
        if let note {
          Text(note)
            .font(.footnote)
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
        }

        Button {
          Task { await buy() }
        } label: {
          Group {
            if isLoading || isBuying {
              ProgressView().tint(.white)
            } else if let product {
              Text("Unlock for \(product.displayPrice)")
            } else {
              Text("Unlock")
            }
          }
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
        }
        .glassCompat(in: .capsule, interactive: true)
        .disabled(product == nil || isBuying)

        HStack(spacing: 24) {
          Button("Restore purchases") { Task { await restore() } }
          Button("Not now", action: onClose)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))
        .disabled(isBuying)
      }
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.96))
    .task {                                              // load the price once the sheet opens
      Track.paywallShown()
      product = await Purchases.shared.product(for: job)
      isLoading = false
      if product == nil { note = "The App Store isn't available right now. Check your internet connection and try again." }
    }
  }

  // MARK: - benefit(_:icon:)
  // One line of what the unlock gives: an icon and a sentence.
  private func benefit(_ text: LocalizedStringKey, icon: String) -> some View {
    Label {
      Text(text)
        .foregroundStyle(.white)
    } icon: {
      Image(systemName: icon)
        .foregroundStyle(.yellow)
        .frame(width: 28)
    }
  }

  // MARK: - buy
  // Purchases.buy -> bought: onUnlocked; cancelled: nothing; pending / failed: a note under the button.
  private func buy() async {
    isBuying = true
    defer { isBuying = false }
    note = nil
    switch await Purchases.shared.buy(job) {
    case .purchased: onUnlocked()
    case .cancelled: break
    case .pending: note = "Your purchase is waiting for approval. Your profession unlocks as soon as it's approved."
    case .failed: note = "The purchase didn't go through. Please try again."
    }
  }

  // MARK: - restore
  // Asks Apple for earlier purchases; the job is owned now -> onUnlocked, otherwise a note.
  private func restore() async {
    isBuying = true
    defer { isBuying = false }
    note = nil
    do {
      try await Purchases.shared.restore()
      if Purchases.shared.isUnlocked(job) {
        onUnlocked()
      } else {
        note = "No earlier purchase of this profession was found."
      }
    } catch {
      note = "Couldn't restore purchases. Please try again."
    }
  }
}

#Preview {
  PaywallView(job: .plumber, onUnlocked: {}, onClose: {})
}
