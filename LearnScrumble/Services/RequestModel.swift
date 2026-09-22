// RequestModel.swift
import Foundation
import UIKit

@Observable
class RequestModel {
  var language: Languages = .englishUS
  var selectedLanguage: Languages = .englishUS
  var proffession: String = ""
  var questions: [QuestionModel] = []
  var isLoading = false
  var errorMessage: String?
  private let apiKey = "" // load from a plist/keychain — never hardcode, never paste in chat
  init() {
    
    if let savedLang = UserDefaults.standard.string(forKey: "nativeLanguage"),
       let restored = Languages(rawValue: savedLang) {
      self.language = restored
    }
    if let savedTarget = UserDefaults.standard.string(forKey: "pickedLanguage"),
       let restored = Languages(rawValue: savedTarget) {
      self.selectedLanguage = restored
    }
    self.proffession = UserDefaults.standard.string(forKey: "pickedProffession") ?? ""
  }
  @MainActor
  func generate() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    
    do {
      let words = try await generateWordList(
        profession: proffession,
        originLanguage: language,
        targetLanguage: selectedLanguage
      )
      
      try await withThrowingTaskGroup(of: (Int, Data).self) { group in
        for (index, word) in words.enumerated() {
          group.addTask {
            let data = try await self.generateImage(for: word.toolName)
            return (index, data)
          }
        }
        
        var built = words.map { QuestionModel(id: UUID().uuidString, word: $0, imageData: nil) }
        for try await (index, data) in group {
          built[index].imageData = data
        }
        print("Generated \(built.count) questions: \(built.map { $0.word.targetWord })")
        self.questions = built
      }
    } catch {
      print("GENERATE ERROR:", error)
      
      if let urlError = error as? URLError {
        
        errorMessage = "Couldn't generate your set: Please try again.\(urlError.localizedDescription)"
        //"Couldn't generate your set: \(urlError.localizedDescription)"
        
      } else {
        
        errorMessage = "Couldn't generate your set: Please try again."
        //\(error.localizedDescription)
        
        
      }
    }
  }
  
  @MainActor
  func generateMore(excluding existingWords: [String]) async -> [QuestionModel] {
    print("Generating more questions")
    do {
      let words = try await generateWordList(
        profession: proffession,
        originLanguage: language,
        targetLanguage: selectedLanguage,
        excluding: existingWords
      )
      
      // Client-side safety net — LLMs sometimes ignore the exclusion instruction
      let filtered = words.filter { !existingWords.contains($0.targetWord) }
      
      return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
        for (index, word) in filtered.enumerated() {
          group.addTask {
            let data = try await self.generateImage(for: word.toolName)
            return (index, data)
          }
        }
        var built = filtered.map { QuestionModel(id: UUID().uuidString, word: $0, imageData: nil) }
        for try await (index, data) in group {
          built[index].imageData = data
        }
        return built
      }
    } catch {
      print("generateMore failed: \(error)")
      return []
    }
  }
  
  private func generateWordList(profession: String,
                                originLanguage: Languages,
                                targetLanguage: Languages,
                                excluding existingWords: [String] = []) async throws -> [WordModel] {
    let exclusionClause = existingWords.isEmpty
    ? ""
    : "\nDo not repeat any of these words already used: \(existingWords.joined(separator: ", "))."
    
    //    let prompt = """
    //  List 10 common tools or resources used by a \(profession).\(exclusionClause)
    //  Respond ONLY with a JSON array, no prose, no markdown fences, in this exact shape:
    //  [{"toolName": "hammer", "originWord": "<word in \(originLanguage.rawValue)>", "targetWord": "<word in \(targetLanguage.rawValue)>"}]
    //  """
    let prompt = """
    List exactly 10 common workplace items, objects, equipment, materials, or resources used by a \(profession).\(exclusionClause)
    Rules:    
    - Return exactly 10 unique items.    
    - Choose common and practical vocabulary that someone working as a \(profession) would actually encounter.    
    - Prefer concrete items that can be clearly represented by a single image.    
    - Include a mix of relevant physical objects, equipment, materials, or other recognizable workplace resources when appropriate for the profession.
    - Do not limit the results to tools.    
    - The "toolName" must be a short, common English name for the concept, written in lowercase.    
    - "originWord" must be the natural, commonly used word for the item in \(originLanguage.rawValue).
    - "targetWord" must be the natural, commonly used word for the item in \(targetLanguage.rawValue).
    - Do not include explanations, descriptions, categories, or definitions.    
    - Do not repeat items.
    - Respond ONLY with a JSON array.
    - No markdown fences or additional text.      
    Return exactly this shape:
      [
        {
          "toolName": "hammer",
          "originWord": "<word in \(originLanguage.rawValue)>",
          "targetWord": "<word in \(targetLanguage.rawValue)>"
        }
      ]
    """
    
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": "gpt-4.1",
      "messages": [["role": "user", "content": prompt]]
    ])
    
    let (data, response) = try await URLSession.shared.data(for: request)
    //    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
    //      throw URLError(.badServerResponse)
    //    }
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      let body = String(data: data, encoding: .utf8) ?? "no body"
      print("Bad response: status=\(status), body=\(body)")
      throw URLError(.badServerResponse)
    }
    struct Envelope: Decodable { struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }; let choices: [Choice] }
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)
    guard let contentString = envelope.choices.first?.message.content.data(using: .utf8) else {
      throw URLError(.cannotParseResponse)
    }
    return try JSONDecoder().decode([WordModel].self, from: contentString)
  }
  
  private func generateImage(for toolName: String) async throws -> Data {
    //    let prompt = "A single \(toolName), isolated icon style, no text, no labels, no background"
    let prompt = """
      A single photorealistic \(toolName),
      clearly recognizable, isolated object,
      centered, clean studio lighting,
      the object occupies no more than 60% of the frame width and height,
      nothing cropped or touching the image edges,
      centered with equal white space on all four sides,
      the entire object fully contained within the canvas boundaries,
      no text, no labels, transparent background.
    
    """
    
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": "gpt-image-1-mini",
      "prompt": prompt,
      "size": "1024x1024",
      "quality": "low",
      "background": "transparent",
      "output_format": "png",
      "n": 1
    ])
    
    let (data, response) = try await URLSession.shared.data(for: request)
    //    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
    //      throw URLError(.badServerResponse)
    //    }
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      let body = String(data: data, encoding: .utf8) ?? "no body"
      print("Bad response: status=\(status), body=\(body)")
      throw URLError(.badServerResponse)
    }
    struct ImgResponse: Decodable { struct Item: Decodable { let b64_json: String }; let data: [Item] }
    let decoded = try JSONDecoder().decode(ImgResponse.self, from: data)
    guard let b64 = decoded.data.first?.b64_json, let imgData = Data(base64Encoded: b64) else {
      throw URLError(.cannotParseResponse)
    }
    if let img = UIImage(data: imgData) {
      print("🖼️ Decoded image size: \(img.size)")
    }
    return imgData
  }
}
