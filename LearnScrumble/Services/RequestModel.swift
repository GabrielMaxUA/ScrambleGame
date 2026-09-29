// RequestModel.swift
import Foundation
import UIKit
import FirebaseFirestore

// MARK: - Flow of this file
// RequestModel is the generation/data layer: it talks to GPT for word lists
// and images, and to Firebase for cached translations/images. It has no idea
// about checkpoints, sessions, or SwiftUI phases — WordVM and AppManager sit
// on top of it and just call these entry points:
//
//   generate()                    <- called ONCE by AppManager.startGame(),
//                                     builds the very first batch of questions
//   generateMore(excluding:)      <- called by WordVM whenever it needs a new batch
//   generateStruggleReview(...)   <- called by AppManager for a struggle review
//
// Internal chain for building ANY batch:
//   generateUniqueWordList() -> generateWordList() (GPT) -> filter out seen words
//   buildQuestions(from:) -> resolveImage() per word (Firebase cache or GPT image)
//
// ERROR HANDLING
// - Every network call goes through send(), which maps failures to GenerationError,
//   retries 429/5xx a couple of times, and respects Task cancellation.
// - One word failing (bad image, moderation refusal, upload issue) never kills
//   the batch — that word is skipped. Only an EMPTY batch is treated as a failure.
// - On failure, errorMessage holds a user-facing message. generate() never
//   leaves stale questions behind; the other two return [] + set errorMessage.

// MARK: - Errors



@Observable
class RequestModel {
    var language: Languages = .englishUS                           // the user's native/origin language — shown as the hint, never tested
    var selectedLanguage: Languages = .englishUS                   // the language being learned — this is what gets scored and spelled
    var proffession: String = ""                                   // drives which vocabulary GPT is asked for
    var questions: [QuestionModel] = []                            // the current session's question list, populated by generate()
    var isLoading = false                                          // true while generate() is running
    var errorMessage: String?                                      // user-facing message, set when any entry point fails
    private let apiKey = "" // load from a plist/keychain — never hardcode, never paste in chat
    private let maxGenerationAttempts = 3                          // how many times to re-ask GPT if it keeps returning already-seen words

    private static let session: URLSession = {                     // one session with sane timeouts instead of URLSession.shared's 60s default
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90                      // image generation can legitimately take 30–60s
        config.timeoutIntervalForResource = 180                    // hard cap so the user is never stuck on the loading screen
        return URLSession(configuration: config)
    }()

    private static let chatURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let imageURL = URL(string: "https://api.openai.com/v1/images/generations")!

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
        print("🟢 RequestModel.init — restored origin=\(language.rawValue), target=\(selectedLanguage.rawValue), profession='\(proffession)'")
    }

    // MARK: - Entry points

    @MainActor
    func generate() async {                                            // builds the very first batch of the session
        isLoading = true
        errorMessage = nil
        questions = []                                                   // never leave a previous session's questions behind on failure
        defer { isLoading = false }

        do {
            let seen = PersistenceController.shared.seenToolNames(targetLanguage: selectedLanguage.rawValue)
            print("🧠 generate() — \(seen.count) toolNames already seen in \(selectedLanguage.rawValue)")
            let words = try await generateUniqueWordList(
                profession: proffession,
                originLanguage: language,
                targetLanguage: selectedLanguage,
                excludingToolNames: seen
            )
            let built = try await buildQuestions(from: words)
            guard !built.isEmpty else { throw GenerationError.noWordsAvailable }
            print("Generated \(built.count) questions: \(built.map { $0.word.targetWord })")
            self.questions = built
        } catch is CancellationError {
            print("generate() cancelled")                                // user left the screen — not an error to show
        } catch {
            print("GENERATE ERROR:", error)
            errorMessage = GenerationError.from(error).errorDescription
        }
    }

    @MainActor
    func generateMore(excluding existingToolNames: [String]) async -> [QuestionModel] { // mid-session batch (prefetch or safety-net)
        print("Generating more questions")
        errorMessage = nil
        do {
            let seen = PersistenceController.shared.seenToolNames(targetLanguage: selectedLanguage.rawValue)
            let exclusion = seen.union(existingToolNames)
            let words = try await generateUniqueWordList(
                profession: proffession,
                originLanguage: language,
                targetLanguage: selectedLanguage,
                excludingToolNames: exclusion
            )
            return try await buildQuestions(from: words)
        } catch is CancellationError {
            return []
        } catch {
            print("generateMore failed: \(error)")
            errorMessage = GenerationError.from(error).errorDescription  // caller decides whether to surface it (only matters if the buffer is empty)
            return []
        }
    }

    @MainActor
    func generateStruggleReview(toolNames: [String]) async -> [QuestionModel] { // review session from KNOWN toolNames — no GPT word-list call
        errorMessage = nil
        guard !toolNames.isEmpty else {
            errorMessage = GenerationError.reviewUnavailable.errorDescription
            return []
        }
        print("🎯 generateStruggleReview — resolving \(toolNames.count) struggle words")
        let existing = await FirebaseWordStore.fetchExisting(toolNames: toolNames)
        let originLanguage = self.language
        let targetLanguage = self.selectedLanguage

        let words: [WordModel] = toolNames.compactMap { toolName in
            guard let doc = existing[toolName],
                  let targetWord = doc.translation[targetLanguage.rawValue] else {
                print("⚠️ generateStruggleReview — '\(toolName)' missing its \(targetLanguage.rawValue) translation, skipping")
                return nil
            }
            let originWord = doc.translation[originLanguage.rawValue] ?? targetWord
            return WordModel(toolName: toolName, originWord: originWord, targetWord: targetWord, imagePrompt: toolName)
        }

        do {
            let built = try await buildQuestions(from: words)
            guard !built.isEmpty else { throw GenerationError.reviewUnavailable }
            print("🎯 generateStruggleReview — built \(built.count) reviewable questions")
            return built
        } catch is CancellationError {
            return []
        } catch {
            print("generateStruggleReview failed: \(error)")
            errorMessage = GenerationError.from(error).errorDescription
            return []
        }
    }

    // MARK: - Building questions

    private func buildQuestions(from words: [WordModel]) async throws -> [QuestionModel] {
        guard !words.isEmpty else { return [] }
        print("🏗️ buildQuestions — starting for \(words.count) words: \(words.map { $0.toolName })")
        let existing = await FirebaseWordStore.fetchExisting(toolNames: words.map { $0.toolName })
        print("🔥 buildQuestions — Firebase already has \(existing.count)/\(words.count) cached")
        let originLanguage = self.language
        let targetLanguage = self.selectedLanguage

        var built = words.map { QuestionModel(id: UUID().uuidString, word: $0, imageData: nil) }
        let maxConcurrent = 2 // throttled — 5-at-once was spiking CPU and stalling the main thread on generateMore

        var index = 0
        while index < words.count {
            try Task.checkCancellation()                                   // stop early if the user left
            let chunk = Array(words[index..<min(index + maxConcurrent, words.count)])
            let chunkStart = index

            try await withThrowingTaskGroup(of: (Int, Data?).self) { group in
                for (offset, word) in chunk.enumerated() {
                    let globalIndex = chunkStart + offset
                    let cachedImageURL = existing[word.toolName]?.image
                    group.addTask {
                        do {
                            let data = try await self.resolveImage(
                                for: word,
                                cachedImageURL: cachedImageURL,
                                originLanguage: originLanguage,
                                targetLanguage: targetLanguage
                            )
                            return (globalIndex, data)
                        } catch is CancellationError {
                            throw CancellationError()                         // cancellation stops everything
                        } catch {
                            print("⚠️ buildQuestions — skipping '\(word.toolName)': \(error)") // any other failure only drops THIS word
                            return (globalIndex, nil)
                        }
                    }
                }
                for try await (idx, data) in group {
                    built[idx].imageData = data
                }
            }
            index += maxConcurrent
        }

        let playable = built.filter { $0.imageData != nil }                // only questions that actually have an image
        print("🏗️ buildQuestions — finished, \(playable.count)/\(built.count) questions playable")
        if playable.isEmpty { throw GenerationError.badResponse }          // every word failed — that IS an error
        return playable
    }

    /// Returns image bytes for one word: reuses the Firebase-cached image if it's
    /// valid, otherwise generates a new one, uploads it, and saves translations.
    private func resolveImage(
        for word: WordModel,
        cachedImageURL: String?,
        originLanguage: Languages,
        targetLanguage: Languages
    ) async throws -> Data {
        if let cachedImageURL, !cachedImageURL.isEmpty, let url = URL(string: cachedImageURL) {
            do {
                let data = try await send(URLRequest(url: url), retries: 1)
                guard UIImage(data: data) != nil else { throw GenerationError.badResponse } // a 404 page is not an image
                print("📦 resolveImage — reused cached image for '\(word.toolName)'")
                await FirebaseWordStore.saveIfNeeded(
                    toolName: word.toolName, originLanguage: originLanguage, originWord: word.originWord,
                    targetLanguage: targetLanguage, targetWord: word.targetWord, imageURL: cachedImageURL
                )
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                print("Cached image unusable for \(word.toolName), regenerating: \(error)")
            }
        }

        print("🎨 resolveImage — generating a new image for '\(word.toolName)'")
        let pngData = try await generateImage(for: word.toolName, description: word.imagePrompt)
        var imageURL = ""
        do {
            imageURL = try await FirebaseImageStore.uploadWebP(pngData, toolName: word.toolName)
            print("☁️ resolveImage — uploaded new image for '\(word.toolName)'")
        } catch {
            print("WebP upload failed for \(word.toolName): \(error)") // user still gets the image this session
        }
        await FirebaseWordStore.saveIfNeeded(
            toolName: word.toolName, originLanguage: originLanguage, originWord: word.originWord,
            targetLanguage: targetLanguage, targetWord: word.targetWord, imageURL: imageURL
        )
        return pngData
    }

    // MARK: - Word list

    /// Retries generateWordList until it has 5 unique unseen words or
    /// maxGenerationAttempts is exhausted. Throws .noWordsAvailable if it found none.
    private func generateUniqueWordList(
        profession: String,
        originLanguage: Languages,
        targetLanguage: Languages,
        excludingToolNames initialExclusion: Set<String>
    ) async throws -> [WordModel] {
        var exclusion = initialExclusion
        var collected: [WordModel] = []

        for attempt in 1...maxGenerationAttempts {
            print("🎲 generateUniqueWordList — attempt \(attempt)/\(maxGenerationAttempts), have \(collected.count)/5")
            let batch: [WordModel]
            do {
                batch = try await generateWordList(
                    profession: profession,
                    originLanguage: originLanguage,
                    targetLanguage: targetLanguage,
                    excluding: Array(exclusion)
                )
            } catch GenerationError.badResponse where attempt < maxGenerationAttempts {
                print("🎲 generateUniqueWordList — GPT reply unreadable, retrying")  // malformed JSON is worth another try; network errors are not
                continue
            }

            for word in batch {
                let isValid = !word.toolName.isEmpty && !word.targetWord.isEmpty
                if isValid && !exclusion.contains(word.toolName) {           // also catches duplicates inside the same batch
                    collected.append(word)
                }
                exclusion.insert(word.toolName)
            }
            if collected.count >= 5 { break }
        }

        if collected.isEmpty { throw GenerationError.noWordsAvailable }    // word pool exhausted — tell the user instead of showing an empty game
        if collected.count < 5 {
            print("⚠️ generateUniqueWordList — only found \(collected.count)/5 unique words")
        }
        return Array(collected.prefix(5))
    }

    private func generateWordList(profession: String,
                                  originLanguage: Languages,
                                  targetLanguage: Languages,
                                  excluding existingToolNames: [String] = []) async throws -> [WordModel] {
        let exclusionClause = existingToolNames.isEmpty
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

        var request = URLRequest(url: Self.chatURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4.1",
            "messages": [["role": "user", "content": prompt]]
        ])

        print("🌐 generateWordList — calling GPT for '\(profession)' \(originLanguage.rawValue)->\(targetLanguage.rawValue)")
        let data = try await send(request)

        struct Envelope: Decodable { struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }; let choices: [Choice] }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let content = envelope.choices.first?.message.content else { throw GenerationError.badResponse }
            let cleaned = content                                          // GPT sometimes adds ```json fences despite the prompt
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let decoded = try JSONDecoder().decode([WordModel].self, from: Data(cleaned.utf8))
            print("🌐 generateWordList — GPT returned \(decoded.count) words: \(decoded.map { $0.toolName })")
            return decoded
        } catch {
            print("generateWordList decode failed: \(error)")
            throw GenerationError.badResponse
        }
    }

    // MARK: - Image

    private func generateImage(for toolName: String, description: String) async throws -> Data {
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

        var request = URLRequest(url: Self.imageURL)
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

        print("🌐 generateImage — requesting image for '\(toolName)'")
        let data = try await send(request)

        struct ImgResponse: Decodable { struct Item: Decodable { let b64_json: String }; let data: [Item] }
        guard let decoded = try? JSONDecoder().decode(ImgResponse.self, from: data),
              let b64 = decoded.data.first?.b64_json,
              let imgData = Data(base64Encoded: b64),
              UIImage(data: imgData) != nil else {                        // bytes must actually form an image
            throw GenerationError.badResponse
        }
        return imgData
    }

    // MARK: - Networking

    /// Single place for every HTTP call: maps errors to GenerationError,
    /// retries 429/5xx with a short backoff, and honors Task cancellation.
    private func send(_ request: URLRequest, retries: Int = 2) async throws -> Data {
        var attempt = 0
        while true {
            try Task.checkCancellation()

            let result: (Data, URLResponse)
            do {
                result = try await Self.session.data(for: request)
            } catch let urlError as URLError where urlError.code == .cancelled {
                throw CancellationError()
            } catch {
                throw GenerationError.from(error)
            }
            let (data, response) = result
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1

            switch status {
            case 200..<300:
                return data
            case 429, 500...599:                                           // rate limited or server hiccup — worth a retry
                guard attempt < retries else { throw GenerationError.serverBusy }
                attempt += 1
                print("⏳ send — status \(status), retry \(attempt)/\(retries)")
                try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            default:                                                       // 400/401/403 etc. — retrying won't help
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("Bad response: status=\(status), body=\(body)")
                throw GenerationError.badResponse
            }
        }
    }
}
