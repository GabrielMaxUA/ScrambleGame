//
//  ErrorView.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-03.
//

import SwiftUI

struct ErrorView: View {
  var message: LocalizedStringKey
  let direction: Bool
  var onRetry: () async -> Void
  var onExit: () -> Void
  
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var spiderLanded = false          // drives the drop down the thread
  @State private var showThread = true             // the thread fades away after landing
  @State private var spiderPace: CGFloat = 0       // side-to-side stroll on top of the button
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.opacity(0.9)
        .ignoresSafeArea()
      HStack {
        Button {
          onExit()
        } label: {
          Image(systemName: direction ? "chevron.left" : "chevron.right")
            .frame(width: 50, height: 50)
            .foregroundStyle(.white)
        }
        .glassEffect(.clear, in: .circle)
        Spacer()
      }
      .padding(.horizontal)
      VStack {
        Spacer()
        Text(message)
          .font(.largeTitle)
          .foregroundColor(.white)
        Spacer()
        Button {
          Task {
            await onRetry()
          }
        } label: {
          Text("Retry!")
            .foregroundStyle(Color.white)
            .font(.title3)
            .fontWeight(.semibold)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .glassEffect(.clear, in: .capsule)
        .overlay(alignment: .top) {
          LineSpider(threadLength: showThread ? 1200 : 0)
            .alignmentGuide(.top) { $0[.bottom] - 2 }   // feet rest on top of the button
            .offset(x: spiderPace, y: spiderLanded ? 0 : -900)   // starts far above the screen
            .allowsHitTesting(false)                    // never blocks the Retry tap
        }
        Spacer()
      }//vs
      .padding()
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
    }//zs
    .onAppear(perform: dropSpider)
  }
  
  private func dropSpider() {
    guard !reduceMotion else {                      // Reduce Motion: spider is simply sitting there, no thread, no strolling
      spiderLanded = true
      showThread = false
      return
    }
    // 1. lower down the thread, slowing as it nears the button
    withAnimation(.easeOut(duration: 1.8).delay(0.3)) {
      spiderLanded = true
    } completion: {
      // 2. the thread fades away
      withAnimation(.easeOut(duration: 0.6)) {
        showThread = false
      } completion: {
        // 3. step to one side, then stroll back and forth forever
        withAnimation(.easeInOut(duration: 0.9)) {
          spiderPace = -14
        } completion: {
          withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            spiderPace = 14
          }
        }
      }
    }
  }
}

#Preview {
  ErrorView(message: "Something went wrong here", direction: true, onRetry: {}, onExit: {})
}
