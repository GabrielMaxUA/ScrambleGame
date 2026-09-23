// EntryView.swift
import SwiftUI

struct EntryView: View {
  @AppStorage("nativeLanguage") var nativeLanguage: String = "en-US"
  @AppStorage("pickedLanguage") var pickedLanguage: String = "en-US"
  @AppStorage("pickedProffession") var pickedProfession: String = ""
  @AppStorage("allSet") var allSet: Bool = false
  @Bindable var requestModel: RequestModel
  let onSubmit: () async -> Void
  let spacing: CGFloat = 10
  
  var body: some View {
    GeometryReader { geo in
        ZStack {
          Color.black.opacity(0.7).ignoresSafeArea()
          VStack {
            Group {
              Text("Welcome to LearnScrumble!")
                .font(.largeTitle)
                .fontWeight(.bold)
              Text("Place where you can learn the words you need for your specific workplace.")
                .font(.title3)
                .fontWeight(.medium)
            }
            .foregroundStyle(.white)
            Spacer()
            
            VStack {
              Text("Choose the language of origin.")
                .font(.body)
              Picker("Language", selection: $requestModel.language) {
                ForEach(Languages.allCases, id: \.self) { language in
                  Text(language.displayName).tag(language)
                }
              }
              .onChange(of: requestModel.language) { _ , newLanguage in
                nativeLanguage = newLanguage.rawValue
              }
              .onChange(of: requestModel.selectedLanguage) { _, newLanguage in
                pickedLanguage = newLanguage.rawValue
              }
              .frame(width: geo.size.width - spacing)
              .tint(Color.white)
              .overlay {
                RoundedRectangle(cornerRadius: 14)
                  .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
              }
            }
            .padding(.vertical, 20)
            .foregroundStyle(.white)
            
            VStack {
              Text("Enter the Occupancy (e.g. Construction, Waiter, Cook...), terminology of which you want to learn.")
                .font(.body)
              TextField(text: $requestModel.proffession) {
                Text("Enter your proffession")
                  .foregroundColor(.white.opacity(0.6))
              }
              .onChange(of: requestModel.proffession) { _, newProffession in
                pickedProfession = newProffession
              }
              .foregroundColor(.white)
              .tint(.white)
              .padding()
              .frame(width: geo.size.width - spacing, height: 33)
              .overlay {
                RoundedRectangle(cornerRadius: 14)
                  .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
              }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 20)
            
            VStack {
              Text("Choose the language You want to learn the words in.")
                .font(.body)
              Picker("Language", selection: $requestModel.selectedLanguage) {
                ForEach(Languages.allCases, id: \.self) { language in
                  Text(language.displayName).tag(language)
                }
              }
              .frame(width: geo.size.width - spacing)
              .tint(Color.white)
              .overlay {
                RoundedRectangle(cornerRadius: 14)
                  .stroke(.white, lineWidth: 1)
              }
            }
            .padding(.vertical, 20)
            .foregroundStyle(.white)
            Spacer()
            
            if let error = requestModel.errorMessage {
              Text(error)
                .foregroundStyle(.red)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            }
            
            Button {
              Task {
                await onSubmit()
              }
            } label: {
              Text("Let's go!")
                .foregroundStyle(Color.white)
                .font(.title3)
                .fontWeight(.semibold)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color.blue)
            .clipShape(Capsule())
            .disabled(requestModel.proffession.isEmpty || requestModel.isLoading)
          }
          .multilineTextAlignment(.center)
          .padding()
        }
        .frame(width: geo.size.width)
        .onAppear {
          if let restored = Languages(rawValue: nativeLanguage) {
            requestModel.language = restored
          }
          if let restored = Languages(rawValue: pickedLanguage) {
            requestModel.selectedLanguage = restored
          }
          requestModel.proffession = pickedProfession
        }
        .fullScreenCover(isPresented: $requestModel.isLoading, content: {
          LoadingView()
        })
    }//geo
  }//body
}

#Preview {
  EntryView(requestModel: RequestModel(), onSubmit: {})
}
