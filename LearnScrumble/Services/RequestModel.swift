// RequestModel.swift
import Foundation
import UIKit
import FirebaseFunctions

// MARK: - Flow of this file
// RequestModel is the generation/data layer. It no longer talks to OpenAI or writes to Firestore itself:
// it calls LearnScrumble's Cloud Functions (functions/src/index.ts), which hold the OpenAI key (Secret Manager)
// and are the only ones writing to the shared word bank. It has no idea about checkpoints, sessions, or
// SwiftUI phases — WordVM and AppManager sit on top of it and just call these entry points:
//
//   generate()                    <- called ONCE by AppManager.startGame(),
//                                     builds the very first batch of questions
//   generateMore(excluding:)      <- called by WordVM whenever it needs a new batch
//   generateStruggleReview(...)   <- called by AppManager for a struggle review
//
// Internal chain for building ANY batch:
//   nextBatch(excluding:countJob:) -> getWords (server: word bank first, GPT only for the missing number)
//   buildQuestions(from:)          -> loadImage() per word:
//                                     stored picture link -> download it
//                                     no link (new word) or broken -> getPicture (server draws + saves it) -> download
//   generateStruggleReview         -> getReviewWords (server reads the words' translations + pictures) -> buildQuestions
//
// Every call: AnonymousAuth.ensureSignedIn() first (the functions refuse calls without a signed-in user).
//
// ERROR HANDLING
// - Function errors are mapped to GenerationError in functionError() (codes set in functions/src/errors.ts).
// - Picture downloads go through send(), which maps failures to GenerationError,
//   retries 408/429/5xx, and respects Task cancellation.
// - One word failing (bad picture, server refusal) never kills the batch — that word is skipped.
//   Only an EMPTY batch is treated as a failure.
// - On failure, lastError holds the reason (AppManager picks the screen from it). generate() never
//   leaves stale questions behind; the other two return [] + set lastError.
// - The old OpenAI code (word list, picture, Firebase writes) is kept commented out in the LEGACY block below.

@Observable
class RequestModel {
    var nativeLanguage: Languages = .englishUS                     // the user's native/origin language — shown as the hint, never tested
    var selectedLanguage: Languages = .englishUS                   // the language being learned — this is what gets scored and spelled
    var proffession: String = ""                                   // drives which vocabulary the server asks GPT for
    var questions: [QuestionModel] = []                            // the current session's question list, populated by generate()
    var isLoading = false                                          // true while generate() is running
    private(set) var lastError: GenerationError?                   // set when any entry point fails, so AppManager can pick the right screen (offline vs error)
    private var lastJobInEnglish: String?                          // the server's English bank key for a typed job (getWords "job") -> rememberTypedJobKey
    var errorMessage: String? { lastError.map { "\($0)" } }        // for logs only — the screens show lastError.message
    var progress: Double = 0                                       // 0...1 loading bar for LoadingView: 20% after the word list, the rest per finished picture
    // The OpenAI key no longer lives in the app: it's in Secret Manager (OPENAI_API_KEY), used only by the Cloud Functions.
    private let batchSize = 5                                      // words per batch (the server's bank + GPT together)
    private static let typedJobKeysKey = "typedProfessionKeys"     // UserDefaults: typed job text -> the server's English job name, e.g. "Кухар" -> "cook"
    private static let region = "us-central1"                      // where the functions run (next to Firestore, nam5)

    private static let session: URLSession = {                     // picture downloads, with sane timeouts instead of URLSession.shared's 60s default
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90
        config.timeoutIntervalForResource = 180                    // hard cap so the user is never stuck on the loading screen
        return URLSession(configuration: config)
    }()

    // MARK: - init
    // Restores the user's saved choices from UserDefaults (written by EntryView / SettingsView):
    // native language ("nativeLanguage"), target language ("pickedLanguage") and profession ("pickedProffession").
    // Unknown or missing values keep the defaults (English US, empty profession).
    init() {
        if let savedLang = UserDefaults.standard.string(forKey: "nativeLanguage"),
           let restored = Languages(rawValue: savedLang) {
            self.nativeLanguage = restored
        }
        if let savedTarget = UserDefaults.standard.string(forKey: "pickedLanguage"),
           let restored = Languages(rawValue: savedTarget) {
            self.selectedLanguage = restored
        }
        self.proffession = UserDefaults.standard.string(forKey: "pickedProffession") ?? ""
        Log.info("🟢 RequestModel.init — restored origin=\(nativeLanguage.rawValue), target=\(selectedLanguage.rawValue)", .words, private: "profession='\(proffession)'")
    }

    // MARK: - Entry points

    // MARK: - generate
    // Builds the very first batch of the session (AppManager.startGame).
    // 1. Resets state: loading on, no error, progress 0, and no questions — never leave a previous
    //    session's questions behind on failure. isLoading goes back off when this returns.
    // 2. Seen words: every concept already practiced in this target language (SwiftData) — the server must not repeat them.
    // 3. countJob: ProfessionStore says whether this job still needs counting on this phone -> the server counts it.
    // 4. nextBatch (getWords) -> 5 words (progress 20%) -> buildQuestions -> a picture for each.
    //    Nothing playable -> .noWordsAvailable.
    // 5. Success -> questions = the built batch. Cancelled (user left the screen) -> not an error to show.
    //    Any other failure -> lastError, so AppManager can pick OfflineView or ErrorView.
    @MainActor
    func generate() async {
        isLoading = true
        lastError = nil
        lastJobInEnglish = nil
        progress = 0
        questions = []
        defer { isLoading = false }

        do {
            let seen = PersistenceController.shared.seenToolNames(targetLanguage: selectedLanguage.rawValue)
            Log.info("🧠 generate() — \(seen.count) toolNames already seen in \(selectedLanguage.rawValue)", .words)
            let countJob = ProfessionStore.needsCounting(profession: proffession)
            let words = try await nextBatch(excluding: seen, countJob: countJob)
            if countJob { ProfessionStore.markCounted(profession: proffession) }   // the server counted it with getWords
            progress = 0.2
            let built = try await buildQuestions(from: words)
            guard !built.isEmpty else { throw GenerationError.noWordsAvailable }
            Log.info("Generated \(built.count) questions", .words, private: "\(built.map { $0.word.targetWord })")
            self.questions = built
        } catch is CancellationError {
            Log.info("generate() cancelled", .words)
        } catch {
            Log.error("❌ generate() failed: \(error)", .words)
            lastError = GenerationError.from(error)
            reportFailure(during: "generate", underlying: error)
        }
    }

    // MARK: - generateMore(excluding:)
    // Mid-session batch (WordVM prefetch or safety-net), via WordVM.fetchMore.
    // Same chain as generate(), but excludes both the seen words AND the words already in this session,
    // never counts the job, and returns the questions instead of storing them. Cancelled -> []. Failure -> [] + lastError
    // (the caller decides whether to surface it — it only matters if the user is waiting on an empty buffer).
    @MainActor
    func generateMore(excluding existingToolNames: [String]) async -> [QuestionModel] {
        Log.info("Generating more questions", .words)
        lastError = nil
        progress = 0
        do {
            let seen = PersistenceController.shared.seenToolNames(targetLanguage: selectedLanguage.rawValue)
            let exclusion = seen.union(existingToolNames)
            let words = try await nextBatch(excluding: exclusion, countJob: false)
            progress = 0.2
            return try await buildQuestions(from: words)
        } catch is CancellationError {
            return []
        } catch {
            Log.error("❌ generateMore failed: \(error)", .words)
            lastError = GenerationError.from(error)
            reportFailure(during: "generateMore", underlying: error)
            return []
        }
    }

    // MARK: - generateStruggleReview(toolNames:)
    // Review session from KNOWN toolNames — no GPT call (AppManager.startStruggleReview).
    // 1. No words -> .reviewUnavailable.
    // 2. getReviewWords: the server reads their docs; words without a translation in the target language
    //    or without a picture are skipped there. The native word falls back to the target word if missing.
    // 3. buildQuestions with progress starting at 0 (no word-list step) -> pictures.
    //    Nothing playable -> .reviewUnavailable. Cancelled -> []. Failure -> [] + lastError.
    @MainActor
    func generateStruggleReview(toolNames: [String]) async -> [QuestionModel] {
        lastError = nil
        progress = 0
        guard !toolNames.isEmpty else {
            lastError = .reviewUnavailable
            return []
        }
        Log.info("🎯 generateStruggleReview — resolving \(toolNames.count) struggle words", .words)
        do {
            let reply: WordsReply = try await callFunction("getReviewWords", ReviewRequest(
                toolNames: Array(toolNames.prefix(100)),                       // the server takes at most 100
                origin: nativeLanguage.rawValue,
                target: selectedLanguage.rawValue
            ), timeout: 30)
            Log.info("🎯 generateStruggleReview — server found \(reply.words.count)/\(toolNames.count) words", .words)
            let built = try await buildQuestions(from: reply.words, progressBase: 0)
            guard !built.isEmpty else { throw GenerationError.reviewUnavailable }
            Log.info("🎯 generateStruggleReview — built \(built.count) reviewable questions", .words)
            return built
        } catch is CancellationError {
            return []
        } catch {
            Log.error("❌ generateStruggleReview failed: \(error)", .words)
            lastError = GenerationError.from(error)
            reportFailure(during: "generateStruggleReview", underlying: error)
            return []
        }
    }

    // MARK: - Word list (server)

    // MARK: - nextBatch(excluding:countJob:)
    // Asks getWords for the next batch. The server does what nextBatch + generateUniqueWordList did here:
    // the job's word bank first, GPT only for the missing number, and saves new words to the bank.
    // `exclusion` = words the user mustn't get (seen in SwiftData + already in this session).
    // 1. Sends the languages, the job (menu English name or typed text, max 40 characters), the bank key this phone
    //    already knows (nil for a typed job not named yet), the exclusion list, the batch size and countJob.
    // 2. Typed job: the reply's "job" is the server's English name for it -> remembered on this phone
    //    (rememberTypedJobKey), so the next batches go straight to that job's bank.
    // 3. Returns the words; words without a picture link get one from getPicture in buildQuestions.
    @MainActor
    private func nextBatch(excluding exclusion: Set<String>, countJob: Bool) async throws -> [ServerWord] {
        let job = String(proffession.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let reply: WordsReply = try await callFunction("getWords", WordsRequest(
            origin: nativeLanguage.rawValue,
            target: selectedLanguage.rawValue,
            profession: job,
            professionKey: professionKey(),
            isMenuJob: !isTypedJob,
            exclude: Array(exclusion),
            count: batchSize,
            countJob: countJob
        ), timeout: 120)
        Log.info("🏦 nextBatch — \(reply.words.count) words: \(reply.fromBank ?? 0) from the bank, \(reply.generated ?? 0) new from GPT", .words, private: "profession='\(reply.job ?? "none yet")'")
        if isTypedJob {
            lastJobInEnglish = reply.job
            rememberTypedJobKey()
        }
        return reply.words
    }

    // MARK: - professionKey()
    // The bank key for the current profession: the English job name in lowercase, the same name
    // ProfessionStore counts under (professions/{name}).
    // - Menu job (or an old renamed one) -> its English menu name, e.g. "Metalworker & welder" -> "metalworker & welder".
    // - Typed job -> the English name GPT gave it earlier on this phone (rememberTypedJobKey), e.g. "Кухар" -> "cook".
    //   Not named yet -> nil: the server asks GPT, which names it (getWords "job").
    private func professionKey() -> String? {
        let typed = proffession.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return nil }
        if let job = Occupation(rawValue: typed) ?? Occupation.renamed[typed], job != .notListed {
            return job.rawValue.lowercased()
        }
        let saved = UserDefaults.standard.dictionary(forKey: Self.typedJobKeysKey) as? [String: String]
        return saved?[typed]
    }

    // MARK: - isTypedJob
    // true when the profession was typed under "Not listed?" rather than picked from the menu.
    private var isTypedJob: Bool {
        let typed = proffession.trimmingCharacters(in: .whitespacesAndNewlines)
        return !typed.isEmpty && Occupation(rawValue: typed) == nil && Occupation.renamed[typed] == nil
    }

    // MARK: - rememberTypedJobKey()
    // After the server named a typed job (lastJobInEnglish, from getWords), saves typed text -> English name on this phone,
    // so the next batches and sessions can use that job's bank. Skips menu jobs, "invalid" and junk.
    // Stays on the iPhone (UserDefaults), like the profession itself.
    private func rememberTypedJobKey() {
        guard isTypedJob,
              let job = lastJobInEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !job.isEmpty, job != "invalid", job.count <= 40 else { return }
        let typed = proffession.trimmingCharacters(in: .whitespacesAndNewlines)
        var saved = UserDefaults.standard.dictionary(forKey: Self.typedJobKeysKey) as? [String: String] ?? [:]
        guard saved[typed] != job else { return }
        saved[typed] = job
        UserDefaults.standard.set(saved, forKey: Self.typedJobKeysKey)
        Log.info("🏦 rememberTypedJobKey — typed job now uses a bank key", .words, private: "'\(typed)' -> '\(job)'")
    }

    // MARK: - reportFailure(during:underlying:)
    // A load failed for the user (the three entry points above): records lastError in Crashlytics as a
    // non-fatal issue, with the languages and the original error. Never the profession (user text).
    // Also sends the generation_failed analytics event (error name only).
    @MainActor
    private func reportFailure(during step: String, underlying: Error) {
        guard let lastError else { return }
        Track.generationFailed(lastError, during: step)
        Log.report(lastError, during: step, info: [
            "origin": nativeLanguage.rawValue,
            "target": selectedLanguage.rawValue,
            "underlying": "\(underlying)"
        ])
    }

    // MARK: - Building questions

    // MARK: - buildQuestions(from:progressBase:)
    // Turns the server's words into playable questions by downloading a picture for each.
    // 1. A question per word, picture still empty.
    // 2. Pictures are loaded 2 at a time (throttled — 5-at-once was spiking CPU and stalling the main thread on generateMore):
    //    - stops early if the user left (Task cancelled)
    //    - each word: loadImage (stored picture, or a new one from getPicture). Cancellation stops everything;
    //      any other failure only drops THIS word (logged, reason kept in `failures`)
    //    - every finished word moves the progress bar: progressBase … 100%
    // 3. Keeps only questions that actually have a picture. Every word failed -> that IS an error: batchFailure explains why.
    private func buildQuestions(from words: [ServerWord], progressBase: Double = 0.2) async throws -> [QuestionModel] {
        guard !words.isEmpty else { return [] }
        Log.info("🏗️ buildQuestions — starting for \(words.count) words, \(words.filter { $0.imageURL == nil }.count) need a new picture", .words, private: "\(words.map { $0.toolName })")

        var built = words.map { w in
            QuestionModel(id: UUID().uuidString,
                          word: WordModel(toolName: w.toolName, originWord: w.originWord, targetWord: w.targetWord, imagePrompt: w.imagePrompt),
                          imageData: nil)
        }
        let maxConcurrent = 2

        var index = 0
        var completed = 0
        var failures: [GenerationError] = []
        while index < words.count {
            try Task.checkCancellation()
            let chunk = Array(words[index..<min(index + maxConcurrent, words.count)])
            let chunkStart = index

            try await withThrowingTaskGroup(of: (Int, Data?, GenerationError?).self) { group in
                for (offset, word) in chunk.enumerated() {
                    let globalIndex = chunkStart + offset
                    group.addTask {
                        do {
                            let data = try await self.loadImage(for: word)
                            return (globalIndex, data, nil)
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            Log.error("⚠️ buildQuestions — skipping a word", .words, private: "'\(word.toolName)': \(error)")
                            return (globalIndex, nil, GenerationError.from(error))
                        }
                    }
                }
                for try await (idx, data, failure) in group {
                    built[idx].imageData = data
                    if let failure { failures.append(failure) }
                    completed += 1
                    let fraction = Double(completed) / Double(words.count)
                    setProgress(progressBase + (1 - progressBase) * fraction)
                }
            }
            index += maxConcurrent
        }

        let playable = built.filter { $0.imageData != nil }
        Log.info("🏗️ buildQuestions — finished, \(playable.count)/\(built.count) questions playable", .words)
        if playable.isEmpty { throw Self.batchFailure(from: failures) }
        return playable
    }

    // MARK: - loadImage(for:)
    // Picture bytes for one word.
    // 1. The word has a stored picture link -> download it (1 retry). It must really be an image (a 404 page is not one).
    //    Cancelled -> stop; any other problem -> step 2.
    // 2. No link (new word) or the download failed -> getPicture: the server returns the stored link, or draws a new
    //    picture, saves it as WebP in Storage and on the word -> download that.
    private func loadImage(for word: ServerWord) async throws -> Data {
        if let link = word.imageURL, !link.isEmpty {
            do {
                let data = try await download(link)
                Log.debug("📦 loadImage — stored picture for '\(word.toolName)'", .words)
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.error("Stored picture unusable, asking the server", .words, private: "\(word.toolName): \(error)")
            }
        }
        Log.info("🎨 loadImage — asking getPicture", .words, private: "'\(word.toolName)'")
        let reply: PictureReply = try await callFunction("getPicture", PictureRequest(
            toolName: word.toolName, imagePrompt: word.imagePrompt
        ), timeout: 180)
        return try await download(reply.imageURL)
    }

    // MARK: - download(_:)
    // One picture from Firebase Storage through send(); the bytes must form an image, otherwise .badResponse.
    private func download(_ link: String) async throws -> Data {
        guard let url = URL(string: link) else { throw GenerationError.badResponse }
        let data = try await send(URLRequest(url: url), retries: 1)
        guard UIImage(data: data) != nil else { throw GenerationError.badResponse }
        return data
    }

    // MARK: - Cloud Functions

    // MARK: - callFunction(_:_:timeout:)
    // Calls one of the Cloud Functions (functions/src/index.ts) with a typed request and reply.
    // 1. Cancelled already -> stop. 2. Makes sure the anonymous sign-in is there (the functions need a signed-in user).
    // 3. Calls it with its own timeout (getWords 120 s, getPicture 180 s — a new picture can take a while).
    // 4. Errors -> functionError (GenerationError cases the screens know).
    // Request/Reply must be Sendable: Firebase encodes/decodes them off the main thread, so their Codable
    // conformance can't be tied to the main actor (the project's default isolation).
    private func callFunction<Request: Encodable & Sendable, Reply: Decodable & Sendable>(_ name: String, _ request: Request,
                                                                   timeout: TimeInterval) async throws -> Reply {
        try Task.checkCancellation()
        await AnonymousAuth.ensureSignedIn()
        var callable = Functions.functions(region: Self.region).httpsCallable(name, requestAs: Request.self, responseAs: Reply.self)
        callable.timeoutInterval = timeout
        do {
            return try await callable.call(request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw Self.functionError(error, function: name)
        }
    }

    // MARK: - functionError(_:function:)
    // Server error codes -> GenerationError (the server side of this table is in functions/src/errors.ts):
    //   no connection (a URLError underneath)   -> .offline / .timedOut (GenerationError.from)
    //   unavailable, resource-exhausted        -> .serverBusy          (OpenAI busy after the server's retries)
    //   deadline-exceeded                      -> .timedOut
    //   failed-precondition, permission-denied -> .serviceUnavailable  (our side: key, billing, App Check)
    //   not-found, invalid-argument            -> .noWordsAvailable    (nothing new, refused job text, bad input)
    //   internal                               -> .badResponse         (garbled GPT reply)
    //   unauthenticated, anything else         -> .unknown
    private static func functionError(_ error: Error, function: String) -> Error {
        if let generation = error as? GenerationError { return generation }
        if error is DecodingError { return GenerationError.badResponse }
        let ns = error as NSError
        if let urlError = (error as? URLError) ?? (ns.userInfo[NSUnderlyingErrorKey] as? NSError).flatMap({ $0.domain == NSURLErrorDomain ? URLError(_nsError: $0) : nil }) {
            if urlError.code == .cancelled { return CancellationError() }
            return GenerationError.from(urlError)
        }
        guard ns.domain == FunctionsErrorDomain, let code = FunctionsErrorCode(rawValue: ns.code) else {
            return GenerationError.from(error)
        }
        Log.info("☁️ \(function) — server error \(code.rawValue): \(ns.localizedDescription)", .words)
        switch code {
        case .cancelled:                             return CancellationError()
        case .unavailable, .resourceExhausted:       return GenerationError.serverBusy
        case .deadlineExceeded:                      return GenerationError.timedOut
        case .failedPrecondition, .permissionDenied: return GenerationError.serviceUnavailable
        case .notFound, .invalidArgument:            return GenerationError.noWordsAvailable
        case .internal:                              return GenerationError.badResponse
        default:                                     return GenerationError.unknown
        }
    }

    // MARK: - Server shapes
    // Requests and replies of the three functions, field for field as in functions/src/index.ts.
    // nonisolated so they can be encoded/decoded off the main thread (the project default would tie them to it).
    nonisolated private struct WordsRequest: Encodable, Sendable {
        let origin: String, target: String, profession: String
        let professionKey: String?                                     // nil -> left out -> the server treats the job as not named yet
        let isMenuJob: Bool
        let exclude: [String]
        let count: Int
        let countJob: Bool
    }
    nonisolated private struct ReviewRequest: Encodable, Sendable { let toolNames: [String]; let origin: String; let target: String }
    nonisolated private struct PictureRequest: Encodable, Sendable { let toolName: String; let imagePrompt: String }
    nonisolated private struct PictureReply: Decodable, Sendable { let imageURL: String }
    nonisolated private struct WordsReply: Decodable, Sendable {
        let job: String?                                               // getWords: the bank key used (nil for a typed job GPT called "invalid")
        let words: [ServerWord]
        let fromBank: Int?                                             // getWords only — for the logs
        let generated: Int?
    }
    nonisolated struct ServerWord: Decodable, Sendable {
        let toolName: String
        let originWord: String
        let targetWord: String
        let imageURL: String?                                          // nil -> new word, getPicture draws it
        let imagePrompt: String
    }

    // MARK: - batchFailure(from:)
    // Picks the most useful reason when a whole batch failed word by word:
    // offline beats everything; all words hitting our-side 4xx means a key/billing problem; otherwise a bad reply.
    private static func batchFailure(from failures: [GenerationError]) -> GenerationError {
        if failures.contains(.offline) { return .offline }
        if !failures.isEmpty && failures.allSatisfy({ $0 == .serviceUnavailable }) { return .serviceUnavailable }
        return .badResponse
    }
    
    // MARK: - setProgress
    // Updates the loading bar. buildQuestions' image tasks report through here so the change happens on the main actor.
    @MainActor
    private func setProgress(_ value: Double) {
        progress = value
    }
    // MARK: - LEGACY (before Cloud Functions)
    // The app used to call OpenAI and write to Firestore itself. Kept for reference while the functions settle in;
    // delete once they've run in production for a while. Needs the old apiKey, FirebaseWordStore and FirebaseImageStore.
    /*
    private static let chatURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private static let imageURL = URL(string: "https://api.openai.com/v1/images/generations")!

    // MARK: - resolveImage(for:knownDoc:profession:originLanguage:targetLanguage:)
    // Returns image bytes for one word: reuses the Firebase-cached image if it's
    // valid, otherwise generates a new one, uploads it, and saves translations.
    // 1. Cached URL -> download it (1 retry). It must really be an image (a 404 page is not an image)
    //    -> saveIfNeeded fills any missing translation in the Firebase doc -> done.
    //    Cancelled -> stop; any other problem -> fall through and regenerate.
    // 2. generateImage (GPT) -> PNG bytes.
    // 3. FirebaseImageStore.uploadWebP -> its URL. Upload failed -> logged, the user still gets the image this session.
    // 4. saveIfNeeded: create/fill the word's Firebase doc with translations + image URL -> return the PNG.
    // Both saves pass the doc we already have (knownDoc: no extra read) and the profession to tag the word with.
    private func resolveImage(
        for word: WordModel,
        knownDoc: FirebaseWordModel?,
        profession: String?,
        originLanguage: Languages,
        targetLanguage: Languages
    ) async throws -> Data {
        let cachedImageURL = knownDoc?.image
        if let cachedImageURL, !cachedImageURL.isEmpty, let url = URL(string: cachedImageURL) {
            do {
                let data = try await send(URLRequest(url: url), retries: 1)
                guard UIImage(data: data) != nil else { throw GenerationError.badResponse }
                Log.debug("📦 resolveImage — reused cached image for '\(word.toolName)'", .words)
                await FirebaseWordStore.saveIfNeeded(
                    toolName: word.toolName, originLanguage: originLanguage, originWord: word.originWord,
                    targetLanguage: targetLanguage, targetWord: word.targetWord, imageURL: cachedImageURL,
                    profession: profession, knownDoc: knownDoc
                )
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.error("Cached image unusable, regenerating", .words, private: "\(word.toolName): \(error)")
            }
        }

        Log.info("🎨 resolveImage — generating a new image", .words, private: "'\(word.toolName)'")
        let pngData = try await generateImage(for: word.toolName, description: word.imagePrompt)
        var imageURL = ""
        do {
            imageURL = try await FirebaseImageStore.uploadWebP(pngData, toolName: word.toolName)
            Log.info("☁️ resolveImage — uploaded new image", .words, private: "'\(word.toolName)'")
        } catch {
            Log.error("WebP upload failed", .words, private: "\(word.toolName): \(error)")
        }
        await FirebaseWordStore.saveIfNeeded(
            toolName: word.toolName, originLanguage: originLanguage, originWord: word.originWord,
            targetLanguage: targetLanguage, targetWord: word.targetWord, imageURL: imageURL,
            profession: profession, knownDoc: knownDoc
        )
        return pngData
    }

    // MARK: - Word list

    // MARK: - generateUniqueWordList
    // Retries generateWordList until it has `count` unique unseen words (5 by default; fewer when the bank
    // already gave some — nextBatch) or
    // maxGenerationAttempts is exhausted. Throws .noWordsAvailable if it found none.
    // - A malformed GPT reply is worth another try (except on the last attempt); network errors are not.
    // - A word counts if it has a toolName and a target word and isn't excluded — the exclusion list
    //   also grows with every word seen, so duplicates inside the same batch are caught too.
    // - None found -> word pool exhausted: tell the user instead of showing an empty game.
    // - Fewer than 5 -> logged, plays with what it has. Returns at most 5.
    private func generateUniqueWordList(
        profession: String,
        originLanguage: Languages,
        targetLanguage: Languages,
        excludingToolNames initialExclusion: Set<String>,
        count: Int = 5
    ) async throws -> [WordModel] {
        var exclusion = initialExclusion
        var collected: [WordModel] = []

        for attempt in 1...maxGenerationAttempts {
            Log.debug("🎲 generateUniqueWordList — attempt \(attempt)/\(maxGenerationAttempts), have \(collected.count)/\(count)", .words)
            let batch: [WordModel]
            do {
                batch = try await generateWordList(
                    profession: profession,
                    originLanguage: originLanguage,
                    targetLanguage: targetLanguage,
                    excluding: Array(exclusion)
                )
            } catch GenerationError.badResponse where attempt < maxGenerationAttempts {
                Log.info("🎲 generateUniqueWordList — GPT reply unreadable, retrying", .words)
                continue
            }

            for word in batch {
                let isValid = !word.toolName.isEmpty && !word.targetWord.isEmpty
                if isValid && !exclusion.contains(word.toolName) {
                    collected.append(word)
                }
                exclusion.insert(word.toolName)
            }
            if collected.count >= count { break }
        }

        if collected.isEmpty { throw GenerationError.noWordsAvailable }
        if collected.count < count {
            Log.info("⚠️ generateUniqueWordList — only found \(collected.count)/\(count) unique words", .words)
        }
        return Array(collected.prefix(count))
    }

    // MARK: - generateWordList
    // One GPT chat request for 5 words.
    // 1. Builds the prompt: profession, the excluded toolNames, and the rules — English lowercase toolName as the
    //    canonical key, natural words in both languages, an unambiguous image description, JSON array only.
    // 2. POST to the chat API (gpt-4.1) through send().
    // 3. Decodes the reply envelope -> the message text -> strips ```json fences (GPT sometimes adds them despite the prompt)
    //    -> decodes {"job", "words"} (or a plain [WordModel] array, as older replies looked). Anything unreadable -> .badResponse.
    //    "job" = the profession's English name, or "invalid" if it isn't a real job -> lastJobInEnglish -> ProfessionStore.
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
      - "job" must be the profession "\(profession)" as a short, common English job name in lowercase and singular (for example "cook" or "forklift operator"), whatever language it was written in. If it isn't a real job or profession (for example a person's name, random text, or something offensive), write "invalid".
      - Respond ONLY with a JSON object.
      - No markdown fences or additional text.
      Return exactly this shape:
        {
          "job": "carpenter",
          "words": [
            {
              "toolName": "hammer",
              "originWord": "<word in \(originLanguage.rawValue)>",
              "targetWord": "<word in \(targetLanguage.rawValue)>",
              "imagePrompt": "a claw hammer with a wooden handle and a steel head with a curved claw"
            }
          ]
        }
    """

        var request = URLRequest(url: Self.chatURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4.1",
            "messages": [["role": "user", "content": prompt]]
        ])

        Log.info("🌐 generateWordList — calling GPT, \(originLanguage.rawValue)->\(targetLanguage.rawValue)", .words, private: "profession='\(profession)'")
        let data = try await send(request)

        struct Envelope: Decodable { struct Choice: Decodable { struct Msg: Decodable { let content: String }; let message: Msg }; let choices: [Choice] }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard let content = envelope.choices.first?.message.content else { throw GenerationError.badResponse }
            let cleaned = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            struct Reply: Decodable { let job: String?; let words: [WordModel] }   // {"job": "cook", "words": [...]}
            let decoded: [WordModel]
            if let reply = try? JSONDecoder().decode(Reply.self, from: Data(cleaned.utf8)) {
                decoded = reply.words
                if let job = reply.job { lastJobInEnglish = job }
            } else {
                decoded = try JSONDecoder().decode([WordModel].self, from: Data(cleaned.utf8))   // GPT sent only the array
            }
            Log.info("🌐 generateWordList — GPT returned \(decoded.count) words", .words, private: "\(decoded.map { $0.toolName })")
            return decoded
        } catch {
            Log.error("generateWordList decode failed: \(error)", .words)
            throw GenerationError.badResponse
        }
    }

    // MARK: - Image

    // MARK: - generateImage(for:description:)
    // One GPT image request for a word.
    // 1. Prompt: a single photorealistic, centered object with room around it, no text, transparent background.
    // 2. POST to the image API (gpt-image-1-mini, 1024×1024, low quality, PNG) through send().
    // 3. Heavy part runs on a background thread (unpackImage) — the loading animation keeps moving.
    //    Unreadable reply -> .badResponse.
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

        Log.debug("🌐 generateImage — requesting image for '\(toolName)'", .words)
        let data = try await send(request)

        guard let imgData = await Self.unpackImage(data) else {
            throw GenerationError.badResponse
        }
        return imgData
    }

    // MARK: - Background image unpacking
    // Flow: resolveImage -> generateImage -> send() (network, waits in iOS) -> raw reply bytes
    //       -> await unpackImage(data) [background thread] -> PNG bytes back on the main thread
    //       -> resolveImage -> FirebaseImageStore.uploadWebP + returned to buildQuestions as the question's image
    // GPT's reply is ~2 MB of JSON with the PNG inside as base64 text.
    // Parsing it, decoding the base64 and checking the image is real CPU work,
    // so it runs on a background thread (@concurrent) instead of freezing the main thread.
    //   @concurrent — run this on a background thread, not the caller's (main) thread
    //   nonisolated + static: touches no RequestModel state, so it may run off the main thread
    // Steps: reply bytes -> ImgResponse (the JSON shape below) -> the first (only, n: 1) image, as base64 text
    //        -> real PNG bytes -> the bytes must actually form an image -> PNG bytes (same Data generateImage returned before).
    // Called from: generateImage above. Returns nil for an unreadable reply -> generateImage throws .badResponse.
    @concurrent
    nonisolated private static func unpackImage(_ data: Data) async -> Data? {
        guard let decoded = try? JSONDecoder().decode(ImgResponse.self, from: data),
              let b64 = decoded.data.first?.b64_json,
              let imgData = Data(base64Encoded: b64),
              UIImage(data: imgData) != nil else {
            return nil
        }
        return imgData
    }

    /// Shape of GPT's image reply: { "data": [ { "b64_json": "<base64 PNG>" } ] }.
    /// nonisolated so unpackImage can decode it on the background thread (the project default would tie it to the main thread).
    nonisolated private struct ImgResponse: Decodable { struct Item: Decodable { let b64_json: String }; let data: [Item] }

    */

    // MARK: - Networking

    // MARK: - send(_:retries:)
    // Single place for every HTTP call: maps errors to GenerationError,
    // retries 429/5xx with a short backoff, and honors Task cancellation.
    // - Cancelled before or during the call -> CancellationError (not shown as an error).
    // - 2xx -> the reply bytes.
    // - 408 / 429 / 5xx (timeout, rate limited or server hiccup — worth a retry) -> waits 2s, 4s… and tries again;
    //   out of retries -> .serverBusy.
    // - Other 4xx (400/401/403/404 — our key, billing or request is wrong) -> .serviceUnavailable, logged loudly.
    // - Anything else unexpected -> .badResponse.
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
            case 408, 429, 500...599:
                guard attempt < retries else { throw GenerationError.serverBusy }
                attempt += 1
                Log.info("⏳ send — status \(status), retry \(attempt)/\(retries)", .words)
                try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            case 400..<500:
                let body = String(data: data, encoding: .utf8) ?? "no body"
                Log.error("🚨 send — status=\(status), service unavailable (our side)", .words, private: "body=\(body)")
                throw GenerationError.serviceUnavailable
            default:
                let body = String(data: data, encoding: .utf8) ?? "no body"
                Log.error("Bad response: status=\(status)", .words, private: "body=\(body)")
                throw GenerationError.badResponse
            }
        }
    }
}
