//
//  LaunchScreen.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-10-07.
//

import SwiftUI

struct LaunchScreen: View {
  @State private var imageOpacity: Double = 0
  @State private var rotationAngle: Angle = .degrees(0)
    var body: some View {
      ZStack{
        Color(.black)
          .ignoresSafeArea()
        VStack{
          Spacer()
          VStack{
            Text("Learn the words")
            Text("you actually use at work.")
          }
            .font(.title)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
          Image(.launchScreen)
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .opacity(imageOpacity)
            .rotationEffect(rotationAngle)
            .keyframeAnimator(
            initialValue: CGFloat(0),
            trigger: imageOpacity
          ) { content, rotation in
            content
              .rotationEffect(.degrees(rotation))
          } keyframes: { _ in
            KeyframeTrack {
              CubicKeyframe(7, duration: 0.7)
              CubicKeyframe(-7, duration: 0.7)
              CubicKeyframe(3, duration: 0.5)
              CubicKeyframe(7, duration: 0.6)
            }
          }
          Spacer()
          Text("v 1.0.0")
            .foregroundStyle(.white)
        }
      }
      .onAppear {
        withAnimation(.easeInOut(duration: 0.3)) {
          imageOpacity = 1
        }
      }
    }
}

#Preview {
    LaunchScreen()
}
