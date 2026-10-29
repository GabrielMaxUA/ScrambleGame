// index.ts — LearnScrumble's Cloud Functions. The app calls these instead of OpenAI, so the OpenAI key
// (Secret Manager: OPENAI_API_KEY) never ships inside the app, and only the server writes to the shared word bank.
//
// The callable functions (app: Functions.functions().httpsCallable("<name>")):
//   getWords        -> the next batch of words for a job: word bank first, GPT only for the missing number.
//                      Replaces RequestModel.nextBatch + generateUniqueWordList + the Firestore writes.
//   getPicture      -> one word's picture: the stored one, or a new one generated, converted to WebP,
//                      uploaded and saved. Called per word, so the app's loading ring still moves per picture.
//   getReviewWords  -> translations + picture links for known words. Not called by the app since 28 Oct 2026
//                      ("My words" replays the words saved on the phone); kept for older builds.
//   reportPicture   -> a user says a word's picture is wrong: a new picture is drawn for THAT user only, and the
//                      report is recorded for the developer (daily email). The bank changes only on approval.
// Background functions:
//   prepareProfession -> fills the bank with ~100 English words + pictures per menu job ("prepare" collection).
//   reviewReport      -> you set a report's status to "approve" / "reject" in the console (reports.ts)
//   mailReports       -> once a day, an email to support@learnscrumble.com with the new reports (reports.ts)
//
// Every call:
//   - must come from a signed-in user (the app's silent anonymous sign-in, AnonymousAuth.swift)
//   - App Check: tokens are accepted but not required yet (enforceAppCheck false = monitoring).
//     Switch to true once the app sends tokens and the console shows almost all requests verified.
//   - runs in us-central1, next to Firestore (nam5, United States)
//   - errors are HttpsError codes the app maps back to its GenerationError cases (errors.ts)
//
// Privacy: the typed job text is only sent to OpenAI (and moderation); it is never stored or logged.
// Logs carry languages, counts and the English job key only.

import { onCall, CallableRequest } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import * as openai from "./openai";
import { fetchBank, fetchWords, saveWord, savePicture, repairPictureLink, countProfession, WordDoc,
         countReport, saveReportPicture, recordReport, parsePictureURL, samePicture } from "./store";
import { noWords, refused, badInput, notSignedIn, tooManyReports } from "./errors";
export { prepareProfession } from "./prepare";                  // background bank filling (prepare.ts)
export { reviewReport, mailReports } from "./reports";           // approve/reject a report, the daily report email

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

const BATCH = 5;                   // words per batch, as in the app
const REPORTS_PER_DAY = 10;        // reports one user can send per day — each one draws a picture, so this caps the cost
const MAX_GPT_ATTEMPTS = 3;        // as RequestModel.maxGenerationAttempts

// MARK: - input checks
// Everything from the phone is untrusted: types and sizes are checked before anything else happens.
const isLang = (v: unknown): v is string => typeof v === "string" && /^[a-z]{2,3}(-[A-Za-z0-9]{2,12}){0,2}$/.test(v);
const isText = (v: unknown, max: number): v is string => typeof v === "string" && v.trim().length > 0 && v.length <= max;
const nameList = (v: unknown, max: number): string[] | null =>
  Array.isArray(v) && v.length <= max && v.every((x) => typeof x === "string" && x.length <= 60) ? (v as string[]) : null;

function requireUser(request: CallableRequest): string {
  if (!request.auth) throw notSignedIn();
  return request.auth.uid;
}

interface WordOut {
  toolName: string;
  originWord: string;
  targetWord: string;
  imageURL: string | null;   // null -> call getPicture(toolName, imagePrompt)
  imagePrompt: string;
}

// MARK: - getWords
// Input:  { origin, target, profession, professionKey?, isMenuJob, exclude: [toolName], count?, countJob? }
//   professionKey = the bank key the app already knows (menu job, or a typed job named before); null = not named yet
//   exclude       = words the user has seen (SwiftData) + words already in this session
//   countJob      = true when the app's once-per-job-per-install check says "count this job" (was ProfessionStore)
// Output: { job, words: [WordOut], fromBank, translated, generated }
//   job = the bank key used (the app remembers it for a typed job, as rememberTypedJobKey did)
//
// 1. Checks: signed in, valid input.
// 2. Typed job seen for the first time -> moderation; refused text -> invalid-argument "refused".
// 3. Bank: words tagged with the job, not excluded, with a picture and both languages -> up to `count`, at random.
// 3b. Short? Unseen bank words with a picture but without one or both of the player's languages: GPT only
//     TRANSLATES them (one text request, no new pictures), the translations are saved on the words, and they're
//     played. This is what makes pre-made words (English name + picture, no translations yet) usable for any language
//     pair. Translation fails -> logged, step 4 fills the batch instead.
// 4. Still short? GPT for ONLY the missing number (skipping excluded + bank words already picked), up to 3 attempts.
//    Nothing at all -> not-found "noWordsAvailable". GPT empty but the bank gave some -> play those.
// 5. GPT words: existing docs are reused (picture link, missing translations filled, job tag added);
//    new words are created with image "" (the app then calls getPicture for them).
// 6. countJob -> the job counter.
// The free words (10, once per install) and the job unlocks are checked on the phone (FreeAllowance, Purchases);
// the server doesn't verify purchases yet, so it doesn't limit words either.
export const getWords = onCall({ secrets: [OPENAI_API_KEY], timeoutSeconds: 120, enforceAppCheck: false }, async (request) => {
  requireUser(request);                                           // signed-in (anonymous) users only
  const data = request.data ?? {};
  const { origin, target, profession, isMenuJob } = data;
  if (!isLang(origin) || !isLang(target)) throw badInput("language");
  if (!isText(profession, 40)) throw badInput("profession");
  const exclude = nameList(data.exclude ?? [], 5000);
  if (!exclude) throw badInput("exclude");
  const count = Number.isInteger(data.count) ? Math.min(Math.max(data.count, 1), BATCH) : BATCH;
  let key: string | null = isText(data.professionKey, 40) ? data.professionKey.trim().toLowerCase() : null;
  const apiKey = OPENAI_API_KEY.value();

  // 2. Moderation, only for a typed job GPT hasn't named yet
  if (!isMenuJob && !key && await openai.isFlagged(apiKey, profession)) {
    logger.info("getWords: typed job refused by moderation");
    throw refused();
  }

  // 3. Bank
  const excluded = new Set(exclude.map((n) => n.toLowerCase()));
  const bank: WordDoc[] = key ? await fetchBank(key) : [];
  const ready = bank.filter((d) => !excluded.has(d.word) && d.image && d.translation?.[origin] && d.translation?.[target]);
  const picked = shuffle(ready).slice(0, count);
  const words: WordOut[] = picked.map((d) => ({
    toolName: d.word, originWord: d.translation[origin], targetWord: d.translation[target],
    imageURL: d.image, imagePrompt: d.imagePrompt ?? d.word,
  }));
  logger.info("getWords: bank", { key: key ?? "none yet", bank: bank.length, ready: ready.length, using: picked.length, origin, target });

  // 3b. Translate bank words that only lack the player's languages
  let translated = 0;
  const untranslated = bank.filter((d) => !excluded.has(d.word) && d.image
    && !(d.translation?.[origin] && d.translation?.[target]));
  if (picked.length < count && untranslated.length > 0) {
    const chosen = shuffle(untranslated).slice(0, count - picked.length);
    try {
      const result = await openai.translate(apiKey, profession, chosen.map((d) => d.word), [origin, target]);
      for (const d of chosen) {
        const t = result.get(d.word);
        const originWord = d.translation?.[origin] ?? t?.[origin];
        const targetWord = d.translation?.[target] ?? t?.[target];
        if (!originWord || !targetWord) continue;                    // GPT skipped it -> step 4 replaces it
        await saveWord(d.word, origin, originWord, target, targetWord, key, d);   // fills only what's missing
        words.push({ toolName: d.word, originWord, targetWord, imageURL: d.image, imagePrompt: d.imagePrompt ?? d.word });
        translated++;
      }
    } catch (error) {
      logger.warn("getWords: translating bank words failed, asking GPT for new words instead", { error: String(error) });
    }
    logger.info("getWords: translated bank words", { asked: chosen.length, translated, origin, target });
  }

  // 4. GPT for the rest
  let generated = 0;
  const missing = count - words.length;
  if (missing > 0) {
    const skip = new Set([...excluded, ...ready.map((d) => d.word), ...words.map((w) => w.toolName)]);
    const collected: openai.GptWord[] = [];
    let job: string | null = null;
    for (let attempt = 1; attempt <= MAX_GPT_ATTEMPTS && collected.length < missing; attempt++) {
      const reply = await openai.wordList(apiKey, profession, origin, target, [...skip]);
      job = job ?? reply.job;
      for (const w of reply.words) {
        if (!skip.has(w.toolName)) collected.push(w);
        skip.add(w.toolName);
      }
    }
    if (!key && job && job !== "invalid" && job.length <= 40) key = job;   // a typed job gets its English key here
    const fresh = collected.slice(0, missing);
    logger.info("getWords: GPT", { asked: missing, got: fresh.length, key: key ?? "none" });

    // 5. Reuse or create the docs
    const existing = await fetchWords(fresh.map((w) => w.toolName));
    for (const w of fresh) {
      const doc = existing.get(w.toolName);
      await saveWord(w.toolName, origin, w.originWord, target, w.targetWord, key, doc);
      words.push({
        toolName: w.toolName,
        originWord: doc?.translation?.[origin] ?? w.originWord,
        targetWord: doc?.translation?.[target] ?? w.targetWord,
        imageURL: doc?.image ? doc.image : null,
        imagePrompt: w.imagePrompt,
      });
      generated++;
    }
  } else {
    logger.info("getWords: whole batch from the bank, no GPT call");
  }

  if (words.length === 0) throw noWords();

  // 6. Job counter
  if (data.countJob === true && key) {
    await countProfession(key, isMenuJob ? "picked" : "typed", isMenuJob === true)
      .catch((error) => logger.error("getWords: job counter failed", { error: String(error) }));
  }

  return { job: key, words, fromBank: picked.length, translated, generated };
});

// MARK: - getPicture
// Input:  { toolName, imagePrompt, broken? }   Output: { imageURL }
//   broken = true when the app couldn't download the word's stored picture link.
// 1. The word has a picture link and the app didn't report it broken (another user may have made it meanwhile)
//    -> that link, no cost.
// 2. Reported broken -> repairPictureLink: the file is still in Storage -> the link is rebuilt with the file's current
//    token and saved on the word, no cost. The file is gone (or the link isn't a Storage link) -> step 3.
// 3. GPT draws it -> WebP -> Storage tools/<id>.webp -> saved on the word -> its link.
export const getPicture = onCall({ secrets: [OPENAI_API_KEY], timeoutSeconds: 180, memory: "512MiB", enforceAppCheck: false }, async (request) => {
  requireUser(request);
  const { toolName, imagePrompt, broken } = request.data ?? {};
  if (!isText(toolName, 60)) throw badInput("toolName");
  const name = toolName.trim().toLowerCase();
  const description = isText(imagePrompt, 400) ? imagePrompt : name;

  const doc = (await fetchWords([name])).get(name);
  if (doc?.image) {
    if (broken !== true) {
      logger.info("getPicture: reused stored picture");
      return { imageURL: doc.image };
    }
    const repaired = await repairPictureLink(doc).catch((error) => {
      logger.error("getPicture: link repair failed", { error: String(error) });
      return null;
    });
    if (repaired) {
      logger.info(repaired.changed ? "getPicture: repaired a stale picture link" : "getPicture: stored link was fine");
      return { imageURL: repaired.url };
    }
    logger.info("getPicture: stored picture is missing, drawing a new one");
  }
  const png = await openai.image(OPENAI_API_KEY.value(), description);
  const imageURL = await savePicture(name, png);
  logger.info("getPicture: generated and saved a new picture");
  return { imageURL };
});

// MARK: - getReviewWords
// Input:  { toolNames, origin, target }   Output: { words: [WordOut] }
// The struggle review's words, read from the bank. Words without a translation in the learned language
// or without a picture are skipped. No OpenAI call, no writes.
export const getReviewWords = onCall({ timeoutSeconds: 30, enforceAppCheck: false }, async (request) => {
  requireUser(request);
  const { origin, target } = request.data ?? {};
  const toolNames = nameList(request.data?.toolNames ?? [], 100);
  if (!isLang(origin) || !isLang(target)) throw badInput("language");
  if (!toolNames) throw badInput("toolNames");

  const docs = await fetchWords(toolNames);
  const words: WordOut[] = toolNames.flatMap((name) => {
    const d = docs.get(name);
    const targetWord = d?.translation?.[target];
    if (!d || !targetWord || !d.image) return [];
    return [{ toolName: name, originWord: d.translation[origin] ?? targetWord, targetWord, imageURL: d.image, imagePrompt: name }];
  });
  logger.info("getReviewWords", { asked: toolNames.length, found: words.length });
  return { words };
});

// MARK: - reportPicture
// Input:  { toolName, profession, imageURL? }   Output: { outcome, imageURL }
//   profession = the menu job the user plays (English name) — the new picture is drawn for that meaning
//   imageURL   = the picture link the user saw (QuestionModel.imageURL); missing for words saved before it was kept
// outcome:
//   "drawn"    -> a new picture was drawn ONLY for this user; imageURL = its link (reports/<id>/…). The phone keeps
//                 it with the word; the bank picture doesn't change until the developer approves the report.
//   "replaced" -> the bank picture was already replaced (approved) since the user saw it; imageURL = the current one,
//                 nothing drawn
// 1. Checks: signed in, valid input, at most REPORTS_PER_DAY reports per user per day (resource-exhausted).
// 2. The user saw a bank picture that has changed since -> "replaced". (A picture drawn for an earlier report of
//    this user is under reports/ and never counts as replaced: reporting it again draws once more.)
// 3. GPT writes a clear description for the job (describePicture) -> a picture -> Storage reports/<id>/<random>.webp
//    (saveReportPicture) -> recordReport: counted, the suggestion kept, status "new", into tomorrow's email (reports.ts).
// Privacy: a report stores the word, the job, the picture links and a one-way code of the anonymous sign-in ID
// (to count different people) — nothing else about the user.
export const reportPicture = onCall({ secrets: [OPENAI_API_KEY], timeoutSeconds: 180, memory: "512MiB", enforceAppCheck: false }, async (request) => {
  const uid = requireUser(request);
  const { toolName, profession, imageURL } = request.data ?? {};
  if (!isText(toolName, 60)) throw badInput("toolName");
  if (!isText(profession, 40)) throw badInput("profession");
  const seen = isText(imageURL, 2000) ? imageURL : null;
  const name = toolName.trim().toLowerCase();
  const job = profession.trim().toLowerCase();

  if (await countReport(uid) > REPORTS_PER_DAY) {
    logger.info("reportPicture: daily report limit reached");
    throw tooManyReports();
  }
  const doc = (await fetchWords([name])).get(name);
  if (!doc) throw badInput("unknownWord");

  const sawOwnPicture = seen !== null && (parsePictureURL(seen)?.path.startsWith("reports/") ?? false);
  if (seen && doc.image && !sawOwnPicture && !samePicture(seen, doc.image)) {
    logger.info("reportPicture: bank picture already replaced", { word: name });
    return { outcome: "replaced", imageURL: doc.image };
  }

  const apiKey = OPENAI_API_KEY.value();
  const description = await openai.describePicture(apiKey, name, job);
  const picture = await saveReportPicture(name, await openai.image(apiKey, description));
  await recordReport(doc, uid, job, { url: picture.url, path: picture.path, imagePrompt: description });
  logger.info("reportPicture: drew a picture for the reporter", { word: name, job });
  return { outcome: "drawn", imageURL: picture.url };
});

// MARK: - shuffle
function shuffle<T>(items: T[]): T[] {
  const a = [...items];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
