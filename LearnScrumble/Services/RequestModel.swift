// RequestModel.swift
import Foundation
import UIKit
import FirebaseFirestore

// MARK: - Flow of this file
// RequestModel is the generation/data layer: it talks to GPT for word lists
// and images, and to Firebase for cached translations/images. It has no idea
// about checkpoints, sessions, or SwiftUI phases — WordVM and AppManager sit
// on top of it and just call these two entry points:
//
//   generate()                    <- called ONCE by AppManager.startGame(),
//                                     builds the very first batch of questions
//   generateMore(excluding:)      <- called by WordVM whenever it needs a new
//                                     batch (prefetch near end-of-buffer, or
//                                     the safety-net fetch if the buffer ran dry)
//
// Internal chain for building ANY batch (used by both entry points above):
//   generateUniqueWordList() -> generateWordList() (GPT) -> filter out
//     anything already seen (SwiftData, scoped to targetLanguage) or already
//     in the current session -> retry up to maxGenerationAttempts if short
//   buildQuestions(from:) -> for each surviving word:
//     - check Firebase (fetchExisting, keyed by toolName)
//     - if a cached image exists, reuse it, and fill any missing translation
//     - if not, generate a new image via GPT, upload it, and save/fill
//       whatever translation slots (origin/target) were missing
//
// So one call to generate()/generateMore() = one round trip through:
// SwiftData (exclusion) -> GPT (word list) -> Firebase (cache check/fill) ->
// GPT (image, only if needed) -> Firebase (save) -> [QuestionModel] returned

@Observable
class RequestModel {
  var language: Languages = .englishUS                           // the user's native/origin language — shown as the hint, never tested
  var selectedLanguage: Languages = .englishUS                   // the language being learned — this is what gets scored and spelled
  var proffession: String = ""                                   // drives which vocabulary GPT is asked for
  var questions: [QuestionModel] = []                             // the current session's question list, populated by generate()
  var isLoading = false                                          // true while generate() is running (drives EntryView/LoadingView)
  var errorMessage: String?                                       // set if generate() fails, surfaced by AppManager as phase = .failed
  private let apiKey = "" // load from a plist/keychain — never hardcode, never paste in chat
  private let maxGenerationAttempts = 3                           // how many times to re-ask GPT if it keeps returning already-seen words
  
  init() {
    if let savedLang = UserDefaults.standard.string(forKey: "nativeLanguage"),   // restore the user's last-picked origin language...
       let restored = Languages(rawValue: savedLang) {
      self.language = restored                                    // ...if it's still a valid Languages case
    }
    if let savedTarget = UserDefaults.standard.string(forKey: "pickedLanguage"), // restore the user's last-picked target language...
       let restored = Languages(rawValue: savedTarget) {
      self.selectedLanguage = restored                             // ...if it's still valid
    }
    self.proffession = UserDefaults.standard.string(forKey: "pickedProffession") ?? "" // restore last-picked profession, or empty if none saved
    print("🟢 RequestModel.init — restored origin=\(language.rawValue), target=\(selectedLanguage.rawValue), profession='\(proffession)'") // NEW
  }
  
  private func buildQuestions(from words: [WordModel]) async throws -> [QuestionModel] { // turns GPT's word list into fully-loaded, playable questions
    print("🏗️ buildQuestions — starting for \(words.count) words: \(words.map { $0.toolName })") // NEW
    let existing = await FirebaseWordStore.fetchExisting(toolNames: words.map { $0.toolName }) // one batched lookup: what's already cached in Firebase for these toolNames
    print("🔥 buildQuestions — Firebase already has \(existing.count)/\(words.count) of these words cached") // NEW
    let originLanguage = self.language                             // capture current origin language for this batch
    let targetLanguage = self.selectedLanguage                     // capture current target language for this batch
    
    var built = words.map { QuestionModel(id: UUID().uuidString, word: $0, imageData: nil) } // placeholder questions, images filled in below
    let maxConcurrent = 2 // throttled — 5-at-once was spiking CPU and stalling the main thread on generateMore
    
    var index = 0                                                  // walks through `words` in chunks of maxConcurrent
    while index < words.count {
      let chunk = Array(words[index..<min(index + maxConcurrent, words.count)]) // this round's slice of words to process concurrently
      let chunkStart = index                                        // remember where this chunk starts, to map back to `built`'s indices
      
      try await withThrowingTaskGroup(of: (Int, Data).self) { group in // run this chunk's image work in parallel, capped at maxConcurrent
        for (offset, word) in chunk.enumerated() {
          let globalIndex = chunkStart + offset                      // this word's real index in `words`/`built`
          group.addTask {
            if let existingWord = existing[word.toolName],            // Firebase already has a doc for this word...
               !existingWord.image.isEmpty,                           // ...and it already has an image URL...
               let url = URL(string: existingWord.image) {            // ...and that URL is well-formed
              do {
                let (data, _) = try await URLSession.shared.data(from: url) // download the cached image bytes
                print("📦 buildQuestions — reused cached image for '\(word.toolName)'") // NEW
                await FirebaseWordStore.saveIfNeeded(                  // still call this — fills any missing translation slot even though image was cached
                  toolName: word.toolName, originLanguage: originLanguage, originWord: word.originWord,
                  targetLanguage: targetLanguage, targetWord: word.targetWord, imageURL: existingWord.image
                )
                return (globalIndex, data)                            // done — no image generation needed for this word
              } catch {
                print("Cached image fetch failed for \(word.toolName), regenerating: \(error)") // cached URL is stale/unreachable — fall through to generate a fresh one
              }
            }
            
            print("🎨 buildQuestions — no usable cached image for '\(word.toolName)', generating a new one") // NEW
            let pngData = try await self.generateImage(for: word.toolName, description: word.imagePrompt) // no cached image (or fetch failed) — generate one via GPT
            var imageURL = ""                                         // will hold the uploaded image's URL, if upload succeeds
            do {
              imageURL = try await FirebaseImageStore.uploadWebP(pngData, toolName: word.toolName) // upload the freshly generated image
              print("☁️ buildQuestions — uploaded new image for '\(word.toolName)' -> \(imageURL)") // NEW
            } catch {
              print("WebP upload failed for \(word.toolName): \(error)") // upload failed — proceed with empty imageURL rather than failing the whole batch
            }
            await FirebaseWordStore.saveIfNeeded(                      // save/fill translation + (if upload succeeded) image URL
              toolName: word.toolName, originLanguage: originLanguage, originWord: word.originWord,
              targetLanguage: targetLanguage, targetWord: word.targetWord, imageURL: imageURL
            )
            return (globalIndex, pngData)                              // hand back the freshly generated image bytes
          }
        }
        for try await (idx, data) in group {                          // collect this chunk's results as they complete
          built[idx].imageData = data                                 // attach each word's image bytes to its QuestionModel
        }
      }
      index += maxConcurrent                                          // move on to the next chunk
    }
    print("🏗️ buildQuestions — finished, \(built.count) questions fully built") // NEW
    return built                                                       // every question now has translations + image data ready
  }
  
  @MainActor
  func generate() async {                                            // builds the very first batch of the session — called once by AppManager.startGame()
    isLoading = true                                                  // signal EntryView/LoadingView that generation is underway
    errorMessage = nil                                                // clear any stale error from a previous attempt
    defer { isLoading = false }                                       // always clear the loading flag on exit, success or failure
    
    do {
      let seen = PersistenceController.shared.seenToolNames(targetLanguage: selectedLanguage.rawValue) // words already practiced in this target language, ever
      print("🧠 generate() — \(seen.count) toolNames already seen in \(selectedLanguage.rawValue): \(seen)") // NEW
      let words = try await generateUniqueWordList(                    // ask GPT for 5 words, excluding anything in `seen`
        profession: proffession,
        originLanguage: language,
        targetLanguage: selectedLanguage,
        excludingToolNames: seen
      )
      let built = try await buildQuestions(from: words)                // resolve translations/images for the final word list
      print("Generated \(built.count) questions: \(built.map { $0.word.targetWord })")
      self.questions = built                                           // publish the finished batch — AppManager reads this next
    } catch {
      print("GENERATE ERROR:", error)
      if let urlError = error as? URLError {                           // network-specific failure — likely transient
        errorMessage = "Couldn't generate your set: Please try again."
        print("\(urlError.localizedDescription)")
      } else {                                                         // anything else (decode failure, bad response, etc.)
        errorMessage = "Couldn't generate your set: Please try again later."
        print("\(error.localizedDescription)")
      }
    }
  }
  
  @MainActor
  func generateMore(excluding existingToolNames: [String]) async -> [QuestionModel] { // fetches an additional batch mid-session (prefetch or safety-net)
    print("Generating more questions")
    do {
      let seen = PersistenceController.shared.seenToolNames(targetLanguage: selectedLanguage.rawValue) // all-time seen words for this target language
      let exclusion = seen.union(existingToolNames)                    // combine with this session's in-memory list (covers words shown but not yet scored)
      print("🧠 generateMore() — excluding \(seen.count) SwiftData-seen + \(existingToolNames.count) session toolNames, total \(exclusion.count)") // NEW
      let words = try await generateUniqueWordList(                    // ask GPT for the next 5 words, excluding the combined set
        profession: proffession,
        originLanguage: language,
        targetLanguage: selectedLanguage,
        excludingToolNames: exclusion
      )
      return try await buildQuestions(from: words)                     // resolve translations/images, same as the initial batch
    } catch {
      print("generateMore failed: \(error)")
      return []                                                        // empty batch on failure — WordVM's advance() will still handle this gracefully
    }
  }
  
  
  @MainActor
  func generateStruggleReview(toolNames: [String]) async -> [QuestionModel] { // builds a review session from KNOWN toolNames — no GPT word-list call
    guard !toolNames.isEmpty else { return [] }
    print("🎯 generateStruggleReview — resolving \(toolNames.count) struggle words: \(toolNames)")
    let existing = await FirebaseWordStore.fetchExisting(toolNames: toolNames) // pull cached translations/images for exactly these words
    let originLanguage = self.language
    let targetLanguage = self.selectedLanguage
    
    let words: [WordModel] = toolNames.compactMap { toolName in
      guard let doc = existing[toolName],
            let targetWord = doc.translation[targetLanguage.rawValue] else {
        print("⚠️ generateStruggleReview — '\(toolName)' missing its \(targetLanguage.rawValue) translation in Firebase, skipping")
        return nil // can't review a word we can't display in the current target language
      }
      let originWord = doc.translation[originLanguage.rawValue] ?? targetWord // fallback hint if origin translation isn't cached
      return WordModel(toolName: toolName, originWord: originWord, targetWord: targetWord, imagePrompt: toolName)
    }
    
    do {
      let built = try await buildQuestions(from: words) // reuses the same image/translation-fill pipeline as normal generation
      print("🎯 generateStruggleReview — built \(built.count) reviewable questions")
      return built
    } catch {
      print("generateStruggleReview failed: \(error)")
      return []
    }
  }
  /// Retries generateWordList, filtering by toolName, until it has 5 unique
  /// unseen words or maxGenerationAttempts is exhausted (whichever first).
  private func generateUniqueWordList(                                 // wraps generateWordList with client-side dedup + retry
    profession: String,
    originLanguage: Languages,
    targetLanguage: Languages,
    excludingToolNames initialExclusion: Set<String>
  ) async throws -> [WordModel] {
    var exclusion = initialExclusion                                   // grows with every attempt so retries don't re-offer the same rejects
    var collected: [WordModel] = []                                    // accumulates unique words across attempts
    
    for attempt in 1...maxGenerationAttempts {                         // NEW — numbered for logging (was 0..<maxGenerationAttempts)
      print("🎲 generateUniqueWordList — attempt \(attempt)/\(maxGenerationAttempts), excluding \(exclusion.count) toolNames, have \(collected.count)/5 so far") // NEW
      let batch = try await generateWordList(                          // ask GPT for 5 candidate words
        profession: profession,
        originLanguage: originLanguage,
        targetLanguage: targetLanguage,
        excluding: Array(exclusion)
      )
      let fresh = batch.filter { !exclusion.contains($0.toolName) }    // enforce the exclusion client-side — GPT won't always honor the prompt clause
      print("🎲 generateUniqueWordList — GPT returned \(batch.map { $0.toolName }), \(fresh.count) were actually new") // NEW
      collected.append(contentsOf: fresh)                              // add this attempt's genuinely new words
      exclusion.formUnion(batch.map { $0.toolName }) // don't let a retry re-offer this round's rejects either
      
      if collected.count >= 5 { break }                                // got enough — stop retrying early
    }
    
    if collected.count < 5 {                                           // NEW — flag when we're returning a short batch
      print("⚠️ generateUniqueWordList — only found \(collected.count)/5 unique words after \(maxGenerationAttempts) attempts") // NEW
    }
    return Array(collected.prefix(5))                                  // cap at 5 even if an attempt overshot
    // NOTE: if the profession/language pool is nearly exhausted, this can return
    // fewer than 5 — buildQuestions/WordVM handle a short batch fine, but flag if
    // you'd rather surface an error instead.
  }
  
  private func generateWordList(profession: String,                   // the raw GPT call — asks for exactly 5 words, no dedup/retry logic here
                                originLanguage: Languages,
                                targetLanguage: Languages,
                                excluding existingToolNames: [String] = []) async throws -> [WordModel] {
    let exclusionClause = existingToolNames.isEmpty                    // only add the exclusion instruction if there's something to exclude
    ? ""
    : "\nDo not repeat any of these items already used: \(existingToolNames.joined(separator: ", "))."
    
    let prompt = """
      List exactly 5 common workplace items, objects, equipment, materials, or resources used by a \(profession).\(exclusionClause)
      Rules:    
      - Return exactly 5 unique items.    
      - Choose common and practical vocabulary that someone working as a \(profession) would actually encounter.    
      - Prefer concrete items that can be clearly represented by a single image.    
      - Include a mix of relevant physical objects, equipment, materials, or other recognizable workplace resources when appropriate for the profession.
      - Do not limit the results to tools.    
      - The "toolName" must be a short, common English name for the concept, written in lowercase — this is the canonical key, always in English regardless of the languages below. 
      - "originWord" must be the natural, commonly used word for the item in \(originLanguage.rawValue).
      - "targetWord" must be the natural, commonly used word for the item in \(targetLanguage.rawValue).
      - "imagePrompt" must be a short, UNAMBIGUOUS visual description of the SPECIFIC \(profession)-context object, disambiguated from any other common meaning of the word. For example, for "level" write "a carpenter's spirit level tool with a bubble vial, NOT a level in a video game"; for "pipe" write "a plumbing/construction pipe, a hollow cylindrical tube, NOT a smoking pipe". Always name the disambiguation explicitly when the word has another common meaning.
      - Do not include explanations, descriptions, categories, or definitions in toolName/originWord/targetWord.    
      - Do not repeat items.
      - Respond ONLY with a JSON array.
      - No markdown fences or additional text.      
      Return exactly this shape:
        [
          {
            "toolName": "hammer",
            "originWord": "<word in \(originLanguage.rawValue)>",
            "targetWord": "<word in \(targetLanguage.rawValue)>",
            "imagePrompt": "a claw hammer with a wooden handle and a steel head with a curved claw"
          }
        ]
    """
    
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!) // GPT chat-completions endpoint for the word list
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": "gpt-4.1",
      "messages": [["role": "user", "content": prompt]]
    ])
    
    print("🌐 generateWordList — calling GPT for profession='\(profession)' \(originLanguage.rawValue)->\(targetLanguage.rawValue), excluding \(existingToolNames.count)") // NEW
    let (data, response) = try await URLSession.shared.data(for: request) // fire the request and await the raw response
    
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { // any non-200 is treated as a hard failure
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      let body = String(data: data, encoding: .utf8) ?? "no body"
      print("Bad response: status=\(status), body=\(body)")
      throw URLError(.badServerResponse)
    }
    struct Envelope: Decodable { struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }; let choices: [Choice] } // matches OpenAI's chat completion JSON shape
    let envelope = try JSONDecoder().decode(Envelope.self, from: data)  // decode the outer response envelope
    guard let contentString = envelope.choices.first?.message.content.data(using: .utf8) else { // pull out GPT's actual message text (should be a raw JSON array string)
      throw URLError(.cannotParseResponse)
    }
    let decoded = try JSONDecoder().decode([WordModel].self, from: contentString) // decode GPT's JSON-array reply into WordModel structs
    print("🌐 generateWordList — GPT returned \(decoded.count) words: \(decoded.map { $0.toolName })") // NEW
    return decoded
  }
  
  private func generateImage(for toolName: String, description: String) async throws -> Data { // generates a single illustration image for one concept via GPT
    let prompt = """
    A single photorealistic \(description),
    clearly recognizable, isolated object,
    centered, clean studio lighting,
    the object occupies no more than 60% of the frame width and height,
    nothing cropped or touching the image edges,
    centered with equal white space on all four sides,
    the entire object fully contained within the canvas boundaries,
    no text, no labels, transparent background.
  
  """
    
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!) // GPT image-generation endpoint
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
    
    print("🌐 generateImage — requesting image for '\(toolName)'") // NEW
    let (data, response) = try await URLSession.shared.data(for: request) // fire the request and await the raw response
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { // any non-200 is treated as a hard failure
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      let body = String(data: data, encoding: .utf8) ?? "no body"
      print("Bad response: status=\(status), body=\(body)")
      throw URLError(.badServerResponse)
    }
    struct ImgResponse: Decodable { struct Item: Decodable { let b64_json: String }; let data: [Item] } // matches OpenAI's image-generation JSON shape
    let decoded = try JSONDecoder().decode(ImgResponse.self, from: data) // decode the response envelope
    guard let b64 = decoded.data.first?.b64_json, let imgData = Data(base64Encoded: b64) else { // pull out and decode the base64 image payload
      throw URLError(.cannotParseResponse)
    }
    if let img = UIImage(data: imgData) {                               // sanity-check the bytes actually form a valid image
      print("🖼️ Decoded image size: \(img.size)")
    }
    return imgData                                                      // raw PNG bytes, ready for upload
  }
  
}
