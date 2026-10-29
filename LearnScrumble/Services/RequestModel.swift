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
//   reportPicture(...)            <- called by WordVM when the user reports the current picture (flag on the picture)
//
// Internal chain for building ANY batch:
//   nextBatch(excluding:countJob:) -> getWords (server: word bank first, GPT only for the missing number)
//   buildQuestions(from:)          -> loadImage() per word:
//                                     stored picture link -> download it
//                                     no link (new word) or broken -> getPicture (server repairs a stale link,
//                                     or draws + saves a new picture) -> download
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
        Log.info("🏦 nextBatch — \(reply.words.count) words: \(reply.fromBank ?? 0) from the bank, \(reply.translated ?? 0) translated from the bank, \(reply.generated ?? 0) new from GPT", .words, private: "profession='\(reply.job ?? "none yet")'")
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
    // A load failed for the user (the two entry points above): records lastError in Crashlytics as a
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

            try await withThrowingTaskGroup(of: (Int, (data: Data, link: String)?, GenerationError?).self) { group in
                for (offset, word) in chunk.enumerated() {
                    let globalIndex = chunkStart + offset
                    group.addTask {
                        do {
                            let picture = try await self.loadImage(for: word)
                            return (globalIndex, picture, nil)
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            Log.error("⚠️ buildQuestions — skipping a word", .words, private: "'\(word.toolName)': \(error)")
                            return (globalIndex, nil, GenerationError.from(error))
                        }
                    }
                }
                for try await (idx, picture, failure) in group {
                    built[idx].imageData = picture?.data
                    built[idx].imageURL = picture?.link
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
    // Picture bytes for one word, with the link they came from (kept on the question for reportPicture).
    // 1. The word has a stored picture link -> download it (1 retry). It must really be an image (a 404 page is not one).
    //    Cancelled -> stop; any other problem -> step 2.
    // 2. No link (new word) or the download failed -> getPicture, with broken = true when step 1 failed:
    //    the server repairs a stale link (the file is there but its token changed) or draws a new picture,
    //    saves it as WebP in Storage and on the word -> download that.
    private func loadImage(for word: ServerWord) async throws -> (data: Data, link: String) {
        var broken = false
        if let link = word.imageURL, !link.isEmpty {
            do {
                let data = try await download(link)
                Log.debug("📦 loadImage — stored picture for '\(word.toolName)'", .words)
                return (data, link)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.error("Stored picture unusable, asking the server", .words, private: "\(word.toolName): \(error)")
                broken = true
            }
        }
        Log.info("🎨 loadImage — asking getPicture", .words, private: "'\(word.toolName)'")
        let reply: PictureReply = try await callFunction("getPicture", PictureRequest(
            toolName: word.toolName, imagePrompt: word.imagePrompt, broken: broken
        ), timeout: 180)
        return (try await download(reply.imageURL), reply.imageURL)
    }

    // MARK: - reportPicture(toolName:imageURL:)
    // The user flagged the current picture as wrong (WordVM.reportPicture). Calls reportPicture on the server
    // (functions/src/index.ts) with the job, so a new picture is drawn for this job's meaning of the word —
    // for THIS user only; the developer gets the report by email and decides whether everyone gets it.
    // 1. No menu job -> nothing to report for (typed jobs are off).
    // 2. Server outcome "drawn" (a picture for this user) or "replaced" (the shared picture was already fixed)
    //    -> downloads it -> .newPicture(data, link). Anything else -> .received.
    // 3. resource-exhausted (the day's reports used up) -> .tooMany; anything else -> .failed.
    @MainActor
    func reportPicture(toolName: String, imageURL: String?) async -> ReportResult {
        guard let job = Occupation.listed(proffession) else { return .failed }
        do {
            let reply: ReportReply = try await callFunction("reportPicture", ReportRequest(
                toolName: toolName, profession: job.rawValue, imageURL: imageURL
            ), timeout: 180)
            Log.info("🚩 reportPicture — \(reply.outcome)", .words, private: "'\(toolName)'")
            guard reply.outcome != "received", !reply.imageURL.isEmpty else { return .received }
            return .newPicture(try await download(reply.imageURL), reply.imageURL)
        } catch is TooManyReports {
            return .tooMany
        } catch {
            Log.error("🚩 reportPicture failed: \(error)", .words)
            return .failed
        }
    }

    enum ReportResult {
        case newPicture(Data, String)   // a picture drawn for this user, or the already-fixed shared one: its bytes and link
        case received                   // recorded; a person will check it
        case tooMany                    // the day's reports are used up
        case failed                     // offline or a server problem
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
    //   resource-exhausted "tooManyReports"    -> TooManyReports      (reportPicture only)
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
        if code == .resourceExhausted, ns.localizedDescription == "tooManyReports" { return TooManyReports() }
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

    private struct TooManyReports: Error {}                            // reportPicture: the user's reports for today are used up

    // MARK: - Server shapes
    // Requests and replies of the functions, field for field as in functions/src/index.ts.
    // nonisolated so they can be encoded/decoded off the main thread (the project default would tie them to it).
    nonisolated private struct WordsRequest: Encodable, Sendable {
        let origin: String, target: String, profession: String
        let professionKey: String?                                     // nil -> left out -> the server treats the job as not named yet
        let isMenuJob: Bool
        let exclude: [String]
        let count: Int
        let countJob: Bool
    }
    nonisolated private struct PictureRequest: Encodable, Sendable {
        let toolName: String
        let imagePrompt: String
        let broken: Bool                                               // the stored link failed -> the server repairs or redraws it
    }
    nonisolated private struct PictureReply: Decodable, Sendable { let imageURL: String }
    nonisolated private struct ReportRequest: Encodable, Sendable {
        let toolName: String
        let profession: String                                         // menu job's English name — the meaning to draw
        let imageURL: String?                                          // the picture the user saw; nil -> left out
    }
    nonisolated private struct ReportReply: Decodable, Sendable {
        let outcome: String                                            // "drawn" (for this user) | "replaced" (already fixed for everyone)
        let imageURL: String
    }
    nonisolated private struct WordsReply: Decodable, Sendable {
        let job: String?                                               // getWords: the bank key used (nil for a typed job GPT called "invalid")
        let words: [ServerWord]
        let fromBank: Int?                                             // getWords only — for the logs
        let translated: Int?                                           // bank words GPT only translated (no new pictures)
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
