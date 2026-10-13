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
  @State private var imageOpacity: Double = 0                       // logo starts invisible, fades to 1 on appear
  @State private var rotationAngle: Angle = .degrees(0)             // base rotation of the logo (the wobble is added on top)
    var body: some View {
      ZStack{
        Color(.black)
          .ignoresSafeArea()
        VStack{
          Spacer()
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
          Spacer()
          Text("v 1.0.0")                                           // app version at the bottom
            .foregroundStyle(.white)
        }
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
