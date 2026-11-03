//
//  LaunchScreen.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-07.
//

import SwiftUI

// MARK: - Flow of this file
// The intro screen shown over everything for the first seconds after launch.
//   RootView shows it while `launching` is true (about 5s), then fades it out.
//   On appear: the logo fades in, and that change also starts its little wobble animation.

struct LaunchScreen: View {
  @Environment(\.topButtonsPadding) private var topButtons         // folded iPhone Duo: the clock column sits at the top right
  @State private var imageOpacity: Double = 0                       // logo starts invisible, fades to 1 on appear
  @State private var rotationAngle: Angle = .degrees(0)             // base rotation of the logo (the wobble is added on top)
    private var folded: Bool { topButtons?.isFolded == true }
    private var side: CGFloat { FoldedDuo.columnRoom + 20 }         // folded Duo: the side column's room (96 pt), on both sides

    var body: some View {
      ZStack{
        Color(.black)
          .ignoresSafeArea()
        VStack{
          if !folded { Spacer() }                                   // folded Duo: the tagline from the top
          VStack(spacing: 8) {                                      // tagline
            Text("Feel at home at work.")
              .font(.title)
              .fontWeight(.semibold)
              .multilineTextAlignment(.center)
            Text("Build the vocabulary.\nGain the confidence.\nUnlock new opportunities.")
              .font(.body)
              .foregroundStyle(.white.opacity(0.8))
              .multilineTextAlignment(.center)
          }
          .foregroundStyle(.white)
          .padding(.horizontal, folded ? side : 0)                  // folded Duo: centred, clear of the clock column
          if folded { Spacer() }                                    // folded Duo: the logo in the middle of the rest
          Image(.launchScreen)                                      // the logo
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .opacity(imageOpacity)
            .rotationEffect(rotationAngle)
            .keyframeAnimator(                                      // wobble: runs once each time imageOpacity changes
            initialValue: CGFloat(0),
            trigger: imageOpacity
          ) { content, rotation in
            content
              .rotationEffect(.degrees(rotation))
          } keyframes: { _ in
            KeyframeTrack {                                         // tilt right, left, right — degrees and seconds
              CubicKeyframe(5, duration: 0.7)
              CubicKeyframe(-5, duration: 0.7)
              CubicKeyframe(3, duration: 0.5)
              CubicKeyframe(5, duration: 0.6)
            }
          }
          .padding(.horizontal, folded ? side : 0)                  // folded Duo: as wide as the game's picture
          Spacer()
          Text("v 1.0.0")                                           // app version at the bottom
            .foregroundStyle(.white)
        }
        .padding(.top, folded ? side / 2 : 0)                       // folded Duo: half the side room, as the game's picture
      }
      .onAppear {                                                   // fade the logo in (also triggers the wobble)
        withAnimation(.easeInOut(duration: 0.3)) {
          imageOpacity = 1
        }
      }
    }
}

#Preview {
    LaunchScreen()
}
