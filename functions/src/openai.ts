// openai.ts — every OpenAI call, with the key from Secret Manager.
//
// Same requests the app used to make itself (RequestModel), moved here so the key never leaves the server:
//   wordList(...)      -> gpt-4.1 chat: 5 workplace words for a job, named as THAT job means them ("motor oil",
//                         not "oil", since 28 Oct 2026 — one bank entry per meaning), two languages, an image description each,
//                         plus the job's common English name ("job") or "invalid"
//   translate(...)     -> gpt-4.1 chat: existing bank words (English names) into the player's languages
//   describePicture()  -> gpt-4.1 chat: a new, unambiguous picture description for a word whose picture was reported
//   meanings(...)      -> gpt-4.1 chat: does a word shared by several jobs mean the same thing in each? If not, a
//                         job-specific English name per job. Used only by the split tool (src/tools/splitSharedWords.ts)
//   reviewTranslations()-> gpt-4.1 chat: are a word's translations right for its jobs, do its jobs mean the same item,
//                         does it belong to each job? Problems only, with fixes.
//                         Used only by src/tools/checkTranslations.ts
//   image(prompt)      -> gpt-image-1-mini, 1024×1024, low quality, transparent PNG -> raw PNG bytes
//   isFlagged(text)    -> moderation of the job text the user typed (free)
// send() does the HTTP part for all three: 90 s timeout, retries 408/429/5xx twice (2 s, 4 s),
// and turns any other failure into the errors in errors.ts.

import * as logger from "firebase-functions/logger";
import { busy, timedOut, serviceUnavailable, pictureRefused, badResponse } from "./errors";

export interface GptWord {
  toolName: string;     // canonical English name, lowercase — the Firestore document key
  originWord: string;   // in the language the user speaks
  targetWord: string;   // in the language the user learns
  imagePrompt: string;  // unambiguous picture description
}

// MARK: - send
async function send(apiKey: string, path: string, body: unknown): Promise<any> {
  const delays = [2000, 4000];
  for (let attempt = 0; ; attempt++) {
    let response: Response;
    try {
      response = await fetch(`https://api.openai.com/v1/${path}`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(90_000),
      });
    } catch (error) {
      const timeout = error instanceof Error && error.name === "TimeoutError";
      if (attempt < delays.length) { await sleep(delays[attempt]); continue; }
      logger.error(`openai ${path}: network failure`, { timeout });
      throw timeout ? timedOut() : busy();
    }
    if (response.ok) return response.json();
    const retryable = response.status === 408 || response.status === 429 || response.status >= 500;
    if (retryable && attempt < delays.length) { await sleep(delays[attempt]); continue; }
    const detail = (await response.text()).slice(0, 300);           // OpenAI's error text — never user data
    logger.error(`openai ${path}: status ${response.status}`, { detail });
    if (response.status === 408) throw timedOut();
    if (response.status === 400 && /safety system|safety_violations/.test(detail)) throw pictureRefused();
    throw retryable ? busy() : serviceUnavailable();
  }
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// MARK: - wordList
// One chat request for 5 words. Started as the app's prompt (RequestModel.generateWordList); since 28 Oct 2026 the
// English name and both words follow the job's meaning ("motor oil" for an auto mechanic), so a word that means
// different things in two jobs gets two bank entries, each with its own translations and picture.
// Words already in the bank under a plain name ("oil") keep it until they're split by hand.
export async function wordList(apiKey: string, profession: string, origin: string, target: string,
                               exclude: string[]): Promise<{ job: string | null; words: GptWord[] }> {
  const exclusionClause = exclude.length === 0 ? ""
    : `\nDo not repeat any of these items already used: ${exclude.join(", ")}.`;
  const prompt = `List exactly 5 common workplace items, objects, equipment, materials, or resources used by a ${profession}.${exclusionClause}
Rules:
- Return exactly 5 unique items.
- Choose common and practical vocabulary that someone working as a ${profession} would actually encounter.
- Prefer concrete items that can be clearly represented by a single image.
- Include a mix of relevant physical objects, equipment, materials, or other recognizable workplace resources when appropriate for the profession.
- Do not limit the results to tools.
- The "toolName" must be a short, common English name for the concept, written in lowercase — this is the canonical key, always in English regardless of the languages below.
- The "toolName" must name the item exactly as a ${profession} means it. If the plain word has another common meaning, or means a different thing in another job, make it specific to this job: for an auto mechanic "motor oil", not "oil"; for a cook "cooking oil", not "oil"; for a carpenter "spirit level", not "level"; for a plumber "plumbing pipe", not "pipe". Words with only one meaning stay plain ("hammer", "drill").
- "originWord" must be the natural, commonly used word a ${profession} uses for this item in ${origin}.
- "targetWord" must be the natural, commonly used word a ${profession} uses for this item in ${target}. Use the job's own term, not a word for the item's other meaning (for an auto mechanic in Ukrainian "моторна олива", not "олія", which is cooking oil).
- "imagePrompt" must be a short, UNAMBIGUOUS visual description of the SPECIFIC ${profession}-context object, disambiguated from any other common meaning of the word. For example, for "level" write "a carpenter's spirit level tool with a bubble vial, NOT a level in a video game"; for "pipe" write "a plumbing/construction pipe, a hollow cylindrical tube, NOT a smoking pipe". Always name the disambiguation explicitly when the word has another common meaning.
- Do not include explanations, descriptions, categories, or definitions in toolName/originWord/targetWord.
- Do not repeat items.
- "job" must be the profession "${profession}" as a short, common English job name in lowercase and singular (for example "cook" or "forklift operator"), whatever language it was written in. If it isn't a real job or profession (for example a person's name, random text, or something offensive), write "invalid".
- Respond ONLY with a JSON object.
- No markdown fences or additional text.
Return exactly this shape:
  {
    "job": "carpenter",
    "words": [
      {
        "toolName": "hammer",
        "originWord": "<word in ${origin}>",
        "targetWord": "<word in ${target}>",
        "imagePrompt": "a claw hammer with a wooden handle and a steel head with a curved claw"
      }
    ]
  }`;

  const reply = await send(apiKey, "chat/completions", {
    model: "gpt-4.1",
    messages: [{ role: "user", content: prompt }],
  });
  const content: unknown = reply?.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw badResponse();
  const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
  try {
    const parsed = JSON.parse(cleaned);
    const rawWords: unknown[] = Array.isArray(parsed) ? parsed : Array.isArray(parsed?.words) ? parsed.words : [];
    const words = rawWords.flatMap((w: any) => {
      const toolName = typeof w?.toolName === "string" ? w.toolName.trim().toLowerCase() : "";
      const originWord = typeof w?.originWord === "string" ? w.originWord.trim() : "";
      const targetWord = typeof w?.targetWord === "string" ? w.targetWord.trim() : "";
      const imagePrompt = typeof w?.imagePrompt === "string" ? w.imagePrompt.trim() : toolName;
      return toolName && targetWord && toolName.length <= 60 ? [{ toolName, originWord: originWord || targetWord, targetWord, imagePrompt }] : [];
    });
    const job = typeof parsed?.job === "string" ? parsed.job.trim().toLowerCase() : null;
    return { job, words };
  } catch {
    logger.warn("wordList: GPT reply wasn't valid JSON");
    throw badResponse();
  }
}

// MARK: - translate
// Translates words that are already in the bank (English names, with pictures) into the given languages, in the
// sense a person in this job uses them ("level" for a bricklayer = spirit level). One text request for the batch,
// no pictures. Returns toolName -> { language code: word }; words GPT leaves out are simply missing from the map.
export async function translate(apiKey: string, profession: string, toolNames: string[],
                                languages: string[]): Promise<Map<string, Record<string, string>>> {
  const langs = [...new Set(languages)];
  const prompt = `Translate these workplace items, as a ${profession} uses them, into each of these languages: ${langs.join(", ")}.
Items (English): ${toolNames.join(", ")}.
Rules:
- For each item and each language, give the natural, commonly used word for that item at work, matching the meaning a ${profession} would mean (for example "level" is the spirit level tool, not a game level).
- Only the word itself: no explanations, articles only where the language always uses them, no alternatives.
- Keep "toolName" exactly as given.
- Respond ONLY with a JSON object, no markdown fences or additional text.
Return exactly this shape:
  {
    "items": [
      { "toolName": "${toolNames[0] ?? "hammer"}", "translations": { ${langs.map((l) => `"${l}": "<word in ${l}>"`).join(", ")} } }
    ]
  }`;

  const reply = await send(apiKey, "chat/completions", {
    model: "gpt-4.1",
    messages: [{ role: "user", content: prompt }],
  });
  const content: unknown = reply?.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw badResponse();
  const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
  const result = new Map<string, Record<string, string>>();
  try {
    const parsed = JSON.parse(cleaned);
    const items: unknown[] = Array.isArray(parsed?.items) ? parsed.items : [];
    const wanted = new Set(toolNames);
    for (const item of items as any[]) {
      const name = typeof item?.toolName === "string" ? item.toolName.trim().toLowerCase() : "";
      if (!wanted.has(name)) continue;
      const words: Record<string, string> = {};
      for (const lang of langs) {
        const word = item?.translations?.[lang];
        if (typeof word === "string" && word.trim() && word.length <= 60) words[lang] = word.trim();
      }
      result.set(name, words);
    }
  } catch {
    logger.warn("translate: GPT reply wasn't valid JSON");
    throw badResponse();
  }
  return result;
}

// MARK: - describePicture
// A user reported a word's picture as wrong (reportPicture). The bank keeps no picture description, so the old
// picture may have been drawn from the bare word ("oil" -> a golden drop that looks like an egg). GPT writes a new
// description of the object as this job uses it, explicitly ruling out the other meanings. One short text request.
export async function describePicture(apiKey: string, word: string, profession: string): Promise<string> {
  const prompt = `A picture for the workplace word "${word}", as used by a ${profession}, was reported by a user as showing the wrong thing.
Write a new picture description for an image generator.
Rules:
- Describe ONE concrete, physical object (or the typical container it comes in) that a ${profession} would recognise at once as "${word}".
- Make it UNAMBIGUOUS: name what it must look like (shape, material, colour, typical label-free packaging) and, with "NOT", the things it could be confused with. For example, for "oil" used by an auto mechanic: "a plastic bottle of motor oil with a screw cap, amber oil visible through the side, NOT cooking oil, NOT an egg or a drop of liquid".
- At most 40 words. No text or labels on the object.
- Respond ONLY with a JSON object, no markdown fences or additional text: { "imagePrompt": "<description>" }`;

  const reply = await send(apiKey, "chat/completions", {
    model: "gpt-4.1",
    messages: [{ role: "user", content: prompt }],
  });
  const content: unknown = reply?.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw badResponse();
  const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
  try {
    const description = JSON.parse(cleaned)?.imagePrompt;
    if (typeof description !== "string" || !description.trim() || description.length > 400) throw badResponse();
    return description.trim();
  } catch {
    logger.warn("describePicture: GPT reply wasn't valid JSON");
    throw badResponse();
  }
}

// MARK: - meanings
// For the split tool: words that several jobs share in the bank ("oil": cook + auto mechanic). One request for a batch.
// Returns word -> { same, names, reason }:
//   same = true  -> the word names the same physical item in all its jobs ("work gloves"): nothing to split
//   same = false -> names = a short, specific English name for EVERY listed job ("cooking oil", "motor oil")
// Words GPT leaves out are missing from the map (the tool treats them as "same", i.e. left alone).
export interface Meaning { same: boolean; names: Record<string, string>; reason: string }
export async function meanings(apiKey: string, items: { word: string; jobs: string[] }[]): Promise<Map<string, Meaning>> {
  const list = items.map((i) => `- "${i.word}": ${i.jobs.map((j) => `"${j}"`).join(", ")}`).join("\n");
  const prompt = `These English workplace words are each shared by several jobs in a vocabulary app. Every word has ONE picture and ONE translation per language, shared by all its jobs.
${list}
For each word decide: does it name the same physical item in every listed job, so one picture and one translation fit all of them?
Rules:
- "same": true when one picture and one translation would be right for every job (for example "work gloves", "drill", "bucket").
- "same": false when the item differs between jobs (for example "oil": cooking oil for a cook, motor oil for an auto mechanic; "level": a spirit level for a carpenter, a laser level for an electrician).
- When "same" is false, give in "names" a short, specific, lowercase English name for EVERY listed job, as that job means it ("cooking oil", "motor oil"). Jobs that mean the same item get the same name.
- "reason": at most 12 words.
- Keep each "word" and job exactly as given.
- Respond ONLY with a JSON object, no markdown fences or additional text:
  { "words": [ { "word": "oil", "same": false, "names": { "cook": "cooking oil", "auto mechanic": "motor oil" }, "reason": "cooking oil vs engine oil" } ] }`;

  const reply = await send(apiKey, "chat/completions", {
    model: "gpt-4.1",
    messages: [{ role: "user", content: prompt }],
  });
  const content: unknown = reply?.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw badResponse();
  const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
  const result = new Map<string, Meaning>();
  try {
    const parsed = JSON.parse(cleaned);
    const wanted = new Map(items.map((i) => [i.word, i.jobs]));
    for (const w of (Array.isArray(parsed?.words) ? parsed.words : []) as any[]) {
      const word = typeof w?.word === "string" ? w.word.trim().toLowerCase() : "";
      const jobs = wanted.get(word);
      if (!jobs) continue;
      const names: Record<string, string> = {};
      for (const job of jobs) {
        const name = w?.names?.[job];
        if (typeof name === "string" && name.trim() && name.length <= 60) names[job] = name.trim().toLowerCase();
      }
      const same = w?.same === true || Object.keys(names).length < jobs.length;   // incomplete answer -> leave it alone
      result.set(word, { same, names: same ? {} : names, reason: typeof w?.reason === "string" ? w.reason.slice(0, 120) : "" });
    }
  } catch {
    logger.warn("meanings: GPT reply wasn't valid JSON");
    throw badResponse();
  }
  return result;
}

// MARK: - reviewTranslations
// For the translation check tool: each word with its jobs and its stored translations (language code -> word).
// GPT reports three kinds of problems, everything it doesn't mention is taken as right:
//   wrong     -> a translation that isn't what people in these jobs say, with the fix
//   split     -> the jobs mean different items ("oil": cook vs auto mechanic) — one translation can't fit all;
//                handled by the split tool, not fixed here
//   notForJob -> the word doesn't belong to one of its jobs (an egg for an auto mechanic): that job's tag should go
export interface TranslationIssue { word: string; lang: string; current: string; fix: string; reason: string }
export interface WordReview {
  wrong: TranslationIssue[];
  split: { word: string; reason: string }[];
  notForJob: { word: string; job: string; reason: string }[];
}
export async function reviewTranslations(apiKey: string,
                                         items: { word: string; jobs: string[]; translations: Record<string, string> }[]):
                                         Promise<WordReview> {
  const list = items.map((i) => JSON.stringify({ word: i.word, jobs: i.jobs, translations: i.translations })).join("\n");
  const prompt = `You check a vocabulary app for workers. Each line is an English workplace word, the jobs it is taught for, and its translations (language code -> word). Every listed job sees the same translations and the same picture.
${list}
1. "wrong": for every translation decide: is it the natural word a person in THESE jobs uses for this item, in that language? It is wrong when it:
   - names another meaning of the English word (for an auto mechanic, Ukrainian "олія" is cooking oil; motor oil is "моторна олива"),
   - is not a real or natural word in that language, is in another language or script, or is misspelled,
   - is far too general or too specific for the item.
   Do NOT mark a translation wrong for small style preferences, regional variants, or because another word would also be fine.
   Only mark what you are sure is wrong; if unsure, leave it out (a person checks every change you suggest).
   Give "fix": the natural word in that language as people in these jobs use it (only the word), and "reason": at most 10 words in English.
2. "split": words whose listed jobs mean DIFFERENT items (for example "oil" for a cook and an auto mechanic), so no single translation or picture fits all of them. Don't give fixes for these words' translations.
3. "notForJob": a word that a person in one of its listed jobs would not normally use at work (for example "egg" for an auto mechanic). Give the word, that job exactly as listed, and a reason.
Keep "word", jobs and language codes exactly as given. Leave everything that is right out.
Respond ONLY with a JSON object, no markdown fences or additional text:
  { "wrong": [ { "word": "oil", "lang": "uk-UA", "fix": "моторна олива", "reason": "олія is cooking oil" } ],
    "split": [ { "word": "level", "reason": "spirit level vs laser level" } ],
    "notForJob": [ { "word": "egg", "job": "auto mechanic", "reason": "not used in car repair" } ] }
If nothing is wrong: { "wrong": [], "split": [], "notForJob": [] }`;

  const reply = await send(apiKey, "chat/completions", {
    model: "gpt-4.1",
    messages: [{ role: "user", content: prompt }],
  });
  const content: unknown = reply?.choices?.[0]?.message?.content;
  if (typeof content !== "string") throw badResponse();
  const cleaned = content.replace(/```json/g, "").replace(/```/g, "").trim();
  try {
    const parsed = JSON.parse(cleaned);
    const byWord = new Map(items.map((i) => [i.word, i]));
    const text = (v: unknown) => (typeof v === "string" ? v.trim() : "");
    const list = (v: unknown) => (Array.isArray(v) ? v : []) as any[];
    const wrong = list(parsed?.wrong).flatMap((w) => {
      const word = text(w?.word).toLowerCase();
      const lang = text(w?.lang);
      const current = byWord.get(word)?.translations[lang];
      const fix = text(w?.fix);
      if (!current || !fix || fix === current || fix.length > 60) return [];
      return [{ word, lang, current, fix, reason: text(w?.reason).slice(0, 120) }];
    });
    const split = list(parsed?.split).flatMap((w) => {
      const word = text(w?.word).toLowerCase();
      return byWord.has(word) ? [{ word, reason: text(w?.reason).slice(0, 120) }] : [];
    });
    const notForJob = list(parsed?.notForJob).flatMap((w) => {
      const word = text(w?.word).toLowerCase();
      const job = text(w?.job).toLowerCase();
      return byWord.get(word)?.jobs.includes(job) ? [{ word, job, reason: text(w?.reason).slice(0, 120) }] : [];
    });
    const splitWords = new Set(split.map((s) => s.word));
    return { wrong: wrong.filter((w) => !splitWords.has(w.word)), split, notForJob };
  } catch {
    logger.warn("reviewTranslations: GPT reply wasn't valid JSON");
    throw badResponse();
  }
}

// MARK: - image
// The same prompt and settings as the app's generateImage. Returns PNG bytes.
export async function image(apiKey: string, description: string): Promise<Buffer> {
  const prompt = `A single photorealistic ${description},
clearly recognizable, isolated object,
centered, clean studio lighting,
the object occupies no more than 60% of the frame width and height,
nothing cropped or touching the image edges,
centered with equal white space on all four sides,
the entire object fully contained within the canvas boundaries,
no text, no labels, transparent background.
`;
  const reply = await send(apiKey, "images/generations", {
    model: "gpt-image-1-mini",
    prompt,
    size: "1024x1024",
    quality: "low",
    background: "transparent",
    output_format: "png",
    n: 1,
  });
  const b64: unknown = reply?.data?.[0]?.b64_json;
  if (typeof b64 !== "string") throw badResponse();
  return Buffer.from(b64, "base64");
}

// MARK: - isFlagged
// Moderation of the job text a user typed under "Not listed?" — before anything is generated for it.
// If moderation itself fails, we let the text through (logged): a moderation outage must not stop the game.
export async function isFlagged(apiKey: string, text: string): Promise<boolean> {
  try {
    const reply = await send(apiKey, "moderations", { model: "omni-moderation-latest", input: text });
    return reply?.results?.[0]?.flagged === true;
  } catch (error) {
    logger.warn("isFlagged: moderation unavailable, allowing the text", { error: String(error) });
    return false;
  }
}
