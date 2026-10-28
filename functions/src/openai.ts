// openai.ts — every OpenAI call, with the key from Secret Manager.
//
// Same requests the app used to make itself (RequestModel), moved here so the key never leaves the server:
//   wordList(...)      -> gpt-4.1 chat: 5 workplace words for a job, two languages, an image description each,
//                         plus the job's common English name ("job") or "invalid"
//   image(prompt)      -> gpt-image-1-mini, 1024×1024, low quality, transparent PNG -> raw PNG bytes
//   isFlagged(text)    -> moderation of the job text the user typed (free)
// send() does the HTTP part for all three: 90 s timeout, retries 408/429/5xx twice (2 s, 4 s),
// and turns any other failure into the errors in errors.ts.

import * as logger from "firebase-functions/logger";
import { busy, timedOut, serviceUnavailable, badResponse } from "./errors";

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
    throw retryable ? busy() : serviceUnavailable();
  }
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// MARK: - wordList
// One chat request for 5 words. Prompt identical to the app's (RequestModel.generateWordList),
// so words made here match the ones already in the bank.
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
- "originWord" must be the natural, commonly used word for the item in ${origin}.
- "targetWord" must be the natural, commonly used word for the item in ${target}.
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
