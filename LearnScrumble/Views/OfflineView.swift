//
//  OfflineView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-09.
//

import SwiftUI
import Network

// MARK: - Flow of this file
// Shown by AppManager (phase = .offline) whenever a load fails because there's no internet.
// - Watches the connection with NWPathMonitor while it's on screen.
// - Retries BY ITSELF only when it actually sees the connection come back (offline -> online).
//   If the phone already looks online when the screen opens, it waits for a "Try again" tap
//   instead, so a server that's unreachable can never cause an endless retry loop.
// - SignalHunters draws the owl, raccoon and spider running around with phones, looking for signal.

struct OfflineView: View {
  let direction: Bool
  var onRetry: () async -> Void
  var onExit: () -> Void
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isOnline: Bool?                // nil until the monitor reports the first state
  @State private var backOnline = false             // connection came back while this screen was open
  private var isConnected: Bool { isOnline == true } // drives the whole middle: offline text vs. status only
  private var iconTransition: AnyTransition {        // Reduce Motion: a plain cross-fade, no scaling
    reduceMotion ? .opacity : .scale.combined(with: .opacity)
  }
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.opacity(0.92)
        .ignoresSafeArea()
      
      SignalHunters(celebrating: isConnected)       // full bars + hearts whenever there's a connection
        .transaction { $0.animation = nil }         // it redraws every frame itself — screen animations would smear it
        .allowsHitTesting(false)                    // never blocks the buttons
        .accessibilityHidden(true)                  // decoration only
      
      HStack {
        Button {
          onExit()
        } label: {
          Image(systemName: direction ? "chevron.left" : "chevron.right")
            .frame(width: 50, height: 50)
            .foregroundStyle(.white)
        }
        .glassCompat(in: .circle)
        Spacer()
      }
      .padding(.horizontal)
      
      VStack(spacing: 16) {
        Color.clear
          .frame(height: 110)                       // the owl's flight zone, below the back button
        ZStack {
          if isConnected {
            Image(systemName: "wifi")
              .transition(iconTransition)
          } else {
            Image(systemName: "wifi.slash")
              .symbolEffect(.pulse, isActive: !reduceMotion)
              .transition(iconTransition)
          }
        }
        .font(.system(size: 100, weight: .semibold))
        .foregroundStyle(.white)
        .accessibilityHidden(true)
        if isConnected {
          statusLine                                // online: only the "back online" / "looks OK" line
        } else {
          Text("No internet connection")
            .font(.title.bold())
            .foregroundStyle(.white)
          Text("Check your Wi-Fi or mobile data. We'll continue automatically as soon as you're back online.")
            .font(.body)
            .foregroundStyle(.white.opacity(0.7))
          statusLine                                // offline: "Waiting for connection…"
        }
        Spacer()
        Button {
          Task { await onRetry() }
        } label: {
          Text("Try again")
            .foregroundStyle(Color.white)
            .font(.title3)
            .fontWeight(.semibold)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .glassCompat(in: .capsule)
        Color.clear
          .frame(height: 110)                       // the raccoon's running track
      }
      .padding(.horizontal, 32)
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
    }
    .task { await watchConnection() }
  }
  
  @ViewBuilder
  private var statusLine: some View {
    HStack(spacing: 8) {
      if backOnline {
        Image(systemName: "checkmark.circle.fill")
        Text("Back online! Loading your words…")
      } else if isConnected {
        Text("Your connection looks OK now. Tap Try again.")
      } else {
        ProgressView()
          .tint(.white)
        Text("Waiting for connection…")
      }
    }
    .font(.subheadline)
    .foregroundStyle(.white.opacity(0.85))
    .frame(minHeight: 24)
  }
  
  // Auto-retries only on a real offline -> online change seen on this screen.
  private func watchConnection() async {
    var sawOffline = false
    for await path in NWPathMonitor() {             // ends when the view goes away (task is cancelled)
      let online = path.status == .satisfied
      withAnimation(.easeInOut) { isOnline = online } // icon + text swap smoothly
      if !online {
        sawOffline = true
      } else if sawOffline {
        withAnimation(.easeInOut) { backOnline = true }
        try? await Task.sleep(for: .seconds(1.5))   // let the characters celebrate for a moment
        guard !Task.isCancelled else { return }
        await onRetry()
        return
      }
    }
  }
}

// MARK: - Signal hunters

/// Owl flying loops at the top, spider swinging on its thread, raccoon running along the bottom —
/// each holding up a phone with no bars (the rigged characters live in SignalCharacters.swift).
/// All motion comes from one time value, so it costs nothing when paused.
private struct SignalHunters: View {
  let celebrating: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start = Date()
  @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
  
  var body: some View {
    GeometryReader { geo in
      // Reduce Motion: the timeline is paused — one still frame, no redraws at all.
      // Otherwise capped at 30fps (15 in Low Power Mode) instead of the display's 60/120 — line art looks
      // the same, and the GPU does a fraction of the work.
      TimelineView(.animation(minimumInterval: lowPower ? 1.0 / 15 : 1.0 / 30, paused: reduceMotion)) { context in
        let t = reduceMotion ? 0 : context.date.timeIntervalSince(start)
        ZStack {
          owl(t: t, size: geo.size)
          spider(t: t, size: geo.size)
          raccoon(t: t, size: geo.size)
        }
      }
    }
    .drawingGroup()                                 // renders the three characters as one layer
    .task {                                         // follow Low Power Mode being switched on/off while the screen is up
      for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
      }
    }
  }
  
  // Happy jump when the connection comes back (none with Reduce Motion — the hearts and full bars say it).
  private func celebrationHop(_ t: Double) -> CGFloat {
    celebrating && !reduceMotion ? -abs(sin(t * 9)) * 18 : 0
  }
  
  // MARK: Owl — flies a wavy loop across the top, one wing flapping, the other holding the phone up
  
  private func owl(t: Double, size: CGSize) -> some View {
    let side: CGFloat = 64
    let swing = (size.width - side) / 2 - 12
    let x = size.width / 2 + sin(t * 0.55) * swing
    let facing: CGFloat = cos(t * 0.55) >= 0 ? 1 : -1                 // which way it's flying — the phone leads
    let y = 82 + sin(t * 1.4) * 14 + celebrationHop(t)
    return PhoneOwl(t: t, celebrating: celebrating, facing: facing, size: side)
      .rotationEffect(.degrees(Double(facing) * 8))                    // leans into the flight
      .position(x: x, y: y - side * 0.2)                               // the drawing has room above for the raised phone
  }
  
  // MARK: Spider — hangs from the top on a thread down to the Try again button, bungee up and down and swinging
  
  private func spider(t: Double, size: CGSize) -> some View {
    let side: CGFloat = 64
    let threadLength = max(size.height - 260 + sin(t * 0.8) * 26 + celebrationHop(t), 0) // dangles beside the button, below the text
    let angle = sin(t * 1.7) * 4
    let spider = PhoneSpider(t: t, celebrating: celebrating, size: side)
    let spiderWidth = side * 1.24, spiderHeight = side * 1.18          // PhoneSpider's drawing space
    let threadX = spiderWidth * PhoneSpider.threadX                    // where its own thread starts at the top
    return VStack(alignment: .leading, spacing: 0) {
      Rectangle()
        .fill(.white.opacity(0.5))
        .frame(width: 1, height: threadLength)
        .padding(.leading, threadX - 0.5)                              // lines up with the spider's own thread
      spider
    }
    .rotationEffect(.degrees(angle), anchor: UnitPoint(x: PhoneSpider.threadX, y: 0)) // swings from the top of the thread
    .frame(width: spiderWidth, height: threadLength + spiderHeight, alignment: .top)
    .position(x: size.width - spiderWidth / 2 - 4, y: (threadLength + spiderHeight) / 2)
  }
  
  // MARK: Raccoon — runs back and forth along the bottom, stopping to jump with its phone held up
  
  private func raccoon(t: Double, size: CGSize) -> some View {
    let side: CGFloat = 86
    let margin = side * 0.75                                           // keeps the outstretched arm + phone on screen at the turns
    let cycle = 9.0                                                    // run right, stop, run left, stop
    let p = t.truncatingRemainder(dividingBy: cycle)
    let progress: Double                                               // 0 = left edge, 1 = right edge
    let facing: CGFloat
    let running: Bool
    switch p {
    case ..<3.5: progress = ease(p / 3.5); facing = 1; running = true
    case ..<4.5: progress = 1; facing = 1; running = false
    case ..<8.0: progress = 1 - ease((p - 4.5) / 3.5); facing = -1; running = true
    default:     progress = 0; facing = -1; running = false
    }
    let isRunning = running && !celebrating && !reduceMotion           // Reduce Motion: standing still, phone held up
    // Phone goes up while stopped: eases up over 0.3s after stopping, back down 0.3s before running again.
    let stopStart = p < 4.5 ? 3.5 : 8.0
    let raise = isRunning ? 0 : (celebrating || reduceMotion ? 1 : ease((p - stopStart) / 0.3) * ease((stopStart + 1 - p) / 0.3))
    let x = margin + (size.width - margin * 2) * progress
    let hop: CGFloat = reduceMotion ? 0 : (isRunning ? -abs(sin(t * 11)) * 6 : -abs(sin(t * 6)) * 14) // little run hops / big "signal?" jumps
    let y = size.height - 50 + hop + celebrationHop(t)
    return PhoneRaccoon(t: t, celebrating: celebrating, facing: facing, running: isRunning, raise: raise, size: side)
      .rotationEffect(.degrees(isRunning ? Double(facing) * 5 : 0))    // leans into the run
      .position(x: x, y: y)
  }
  
  private func ease(_ x: Double) -> Double {                           // smooth start and stop
    let c = min(max(x, 0), 1)
    return c * c * (3 - 2 * c)
  }
}

#Preview {
  OfflineView(direction: true, onRetry: {}, onExit: {})
}

