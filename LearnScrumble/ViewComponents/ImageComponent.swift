//
//  ImageComponent.swift
//  LearnScrumble
//
//  Created by Max Gabriel on 2026-09-25.
//

import SwiftUI

struct ImageComponent: View {
  let image: UIImage?
  @State private var showHint = false
  let hint: String
    var body: some View {
      Group {
        if let uiImage = image {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .padding()
        } else {
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color.gray, lineWidth: 2)
            .fill(.clear)
        }
      }
      .frame(width: 250, height: 250)
      .overlay(alignment: .topLeading){
        Button {
          showHint = true
        } label: {
          Image(systemName: "questionmark.circle.fill")
            .frame(width: 60, height: 60)
            .foregroundStyle(.white)
        }
        .popover(isPresented: $showHint) {
          Text(hint)
            .padding()
            .presentationCompactAdaptation(.popover) // keeps it a small popover even on iPhone
        }
      }//imageOverlay
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .padding(.horizontal)
      .padding(.bottom)
    }
}

#Preview {
  VStack{
    ImageComponent(image: UIImage(named: "cat"), hint: "Word")
  }.background(.black)
}
