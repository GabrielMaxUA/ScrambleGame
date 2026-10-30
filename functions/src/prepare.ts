// prepare.ts — fills the word bank in the background: about 100 words with pictures for each menu job.
//
// Why: players get words from the bank instantly (no waiting for pictures), and OpenAI pictures are paid once, ahead.
// Words are made in English only (the English name is the key, the picture is the same for every language);
// a player's two languages are added when someone first needs them (getWords step 3b translates bank words).
//
// How you run it — Firebase console -> Firestore -> collection "prepare" (create it if it isn't there):
//   - one job:      add a document with ID = the job's English menu name in lowercase, e.g. "cook",
//                   with the field  status = "run"  (string). Optional: target = 100 (number).
//   - all menu jobs: add the document "_all" with  status = "run". It creates one document per menu job,
//                   and the jobs are filled ONE AFTER ANOTHER (so OpenAI spending and rate limits stay calm).
//   - pause:        set status = "paused" (the step that's running finishes first). Resume: status = "run".
// Progress is written on the job's document: words (bank words with a picture), steps, lastStep, error.
//
// The loop (one Firestore trigger, no other setup):
//   status "run" -> takes the job (status "working") -> one step -> status "run" again (that write starts the
//   next step) ... -> "done" when the job has `target` words with pictures, or GPT has no new words twice in a row.
//   A step: GPT names 10 new English workplace words for the job (skipping the job's bank words), each is saved and
//   tagged with the job (an existing word just gets the tag), and words without a picture get one
//   (3 at a time, at most 15 per step). A picture OpenAI's safety system refuses is skipped: the word is marked
//   pictureRefused (logged with its prompt) and later steps leave it alone; getPicture still tries when someone plays it.
//   OpenAI credits used up -> this job goes to "paused" (error says so) and the queue waits: add credits, then set
//   status "run" on it; the queued jobs follow when it's done.
//   Any other error -> status "failed" with the message, and the next queued job starts; set status "run" to retry.
// Cost: roughly one OpenAI picture per new word (low quality) plus small text requests. Words other jobs already
// have are tagged, not drawn again. Keep an eye on the OpenAI usage page during a big run.

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { FieldValue } from "firebase-admin/firestore";
import * as openai from "./openai";
import { db, docID, fetchBank, fetchWords, saveWord, savePicture, WordDoc } from "./store";
import { isPictureRefused, isOutOfCredits } from "./errors";

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const DEFAULT_TARGET = 100;
const WORDS_PER_STEP = 10;
const PICTURES_AT_ONCE = 3;
const MAX_PICTURES_PER_STEP = 15;                                 // keeps one step well inside the 9-minute limit
const EN = "en-US";

// The app's menu jobs (OccupationModel.swift rawValues, without "Not listed?"). Keep in sync when the menu changes.
export const MENU_JOBS = [
  "Warehouse worker", "Forklift operator", "Truck driver", "Delivery driver",
  "Construction worker", "Carpenter", "Electrician", "Plumber", "Painter", "Bricklayer & concrete worker",
  "Finishing worker (tiles, drywall, plaster)", "Metalworker & welder", "Handyman & maintenance worker", "Roofer",
  "Auto mechanic", "Factory worker", "Machine operator", "CNC operator & machine setter", "Food production worker",
  "Baker", "Sewing machine operator & tailor", "Cook", "Kitchen assistant", "Waiter", "Bartender & barista",
  "Hotel housekeeper", "Cleaner", "Caregiver", "Hairdresser", "Shop assistant", "Farm worker", "Gardener",
];

// Firestore document IDs can't contain "/"; the job key itself keeps it (the bank tag is the lowercase menu name).
const jobDocID = (key: string) => key.replace(/\//g, "-");

export const prepareProfession = onDocumentWritten(
  { document: "prepare/{jobId}", secrets: [OPENAI_API_KEY], timeoutSeconds: 540, memory: "1GiB" },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists || after.get("status") !== "run") return;   // only "run" starts a step; our own writes stop here
    const id = event.params.jobId;

    if (id === "_all") {
      await startAll(after.ref);
      return;
    }

    // Take the job, so a second trigger can't run the same step twice.
    const ref = after.ref;
    const taken = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.get("status") !== "run") return false;
      tx.update(ref, { status: "working", lastStep: FieldValue.serverTimestamp() });
      return true;
    });
    if (!taken) return;

    const key: string = (after.get("job") as string | undefined) ?? id;   // job = bank key, e.g. "cook"
    const target = Number.isInteger(after.get("target")) ? after.get("target") as number : DEFAULT_TARGET;
    const emptySteps = (after.get("emptySteps") as number | undefined) ?? 0;
    try {
      const result = await step(key);
      const finished = result.words >= target || (result.added === 0 && emptySteps >= 1);
      await ref.update({
        status: finished ? "done" : "run",                          // "run" starts the next step
        words: result.words,
        steps: FieldValue.increment(1),
        emptySteps: result.added === 0 ? emptySteps + 1 : 0,
        error: FieldValue.delete(),
        ...(finished && result.words < target ? { note: "GPT had no new words twice in a row" } : {}),
      });
      logger.info("prepareProfession: step done", { key, words: result.words, added: result.added, finished });
      if (finished) await startNextQueued();
    } catch (error) {
      if (isOutOfCredits(error)) {                                 // every next job would fail the same way: wait
        logger.error("prepareProfession: OpenAI credits used up, queue paused", { key });
        await ref.update({ status: "paused", error: "OpenAI credits used up: add credits, then set status to run" });
        return;
      }
      logger.error("prepareProfession: step failed", { key, error: String(error) });
      await ref.update({ status: "failed", error: String(error).slice(0, 300) });
      await startNextQueued();                                     // one failed job doesn't stop the queue
    }
  },
);

// MARK: - step
// One round for a job: 10 new words (2 GPT requests of 5), saved and tagged, then pictures for the job's words that
// have none. Returns how many of the job's words now have a picture, and how many words were new to the job.
async function step(key: string): Promise<{ words: number; added: number }> {
  const apiKey = OPENAI_API_KEY.value();
  const bank = await fetchBank(key);
  const skip = new Set(bank.map((d) => d.word));
  const fresh: openai.GptWord[] = [];
  for (let attempt = 0; attempt < 3 && fresh.length < WORDS_PER_STEP; attempt++) {
    const reply = await openai.wordList(apiKey, key, EN, EN, [...skip]);
    for (const w of reply.words) {
      if (!skip.has(w.toolName)) fresh.push(w);
      skip.add(w.toolName);
    }
  }
  const batch = fresh.slice(0, WORDS_PER_STEP);
  const existing = await fetchWords(batch.map((w) => w.toolName));
  const prompts = new Map<string, string>();
  for (const w of batch) {
    await saveWord(w.toolName, EN, w.targetWord, EN, w.targetWord, key, existing.get(w.toolName));
    prompts.set(w.toolName, w.imagePrompt);
  }

  // Pictures for the job's words that have none (new ones, and any left from an interrupted step), up to 15 a step.
  // A prompt OpenAI's safety system refuses ("violence" for swarf or a reamer) skips that word instead of failing the step.
  const tagged = await fetchBank(key);
  const missing = tagged.filter((d: WordDoc) => !d.image && !d.pictureRefused).slice(0, MAX_PICTURES_PER_STEP);
  let refused = 0;
  for (let i = 0; i < missing.length; i += PICTURES_AT_ONCE) {
    await Promise.all(missing.slice(i, i + PICTURES_AT_ONCE).map(async (d) => {
      const prompt = prompts.get(d.word) ?? `${d.word}, as used by a ${key}`;
      try {
        const png = await openai.image(apiKey, prompt);
        await savePicture(d.word, png);
      } catch (error) {
        if (!isPictureRefused(error)) throw error;
        refused++;
        logger.warn("prepareProfession: picture refused by OpenAI's safety system, word skipped", { key, word: d.word, prompt });
        await db.collection("words").doc(docID(d.word)).update({ pictureRefused: true });
      }
    }));
  }
  const words = tagged.filter((d) => d.image).length + missing.length - refused;   // the job's words with a picture now
  return { words, added: batch.length };
}

// MARK: - startAll
// "_all" -> one document per menu job (status "queued", or left alone if it already exists), then the first one runs.
async function startAll(ref: FirebaseFirestore.DocumentReference): Promise<void> {
  const writes = db.batch();
  for (const name of MENU_JOBS) {
    const key = name.toLowerCase();
    const jobRef = db.collection("prepare").doc(jobDocID(key));
    const snap = await jobRef.get();
    if (!snap.exists) writes.set(jobRef, { job: key, status: "queued", words: 0, created: FieldValue.serverTimestamp() });
  }
  writes.update(ref, { status: "started", jobs: MENU_JOBS.length, started: FieldValue.serverTimestamp() });
  await writes.commit();
  logger.info("prepareProfession: queued the menu jobs", { jobs: MENU_JOBS.length });
  await startNextQueued();
}

// MARK: - startNextQueued
// Starts the next "queued" job, if none is running. One job at a time keeps spending and rate limits predictable.
async function startNextQueued(): Promise<void> {
  const busy = await db.collection("prepare").where("status", "in", ["run", "working"]).limit(1).get();
  if (!busy.empty) return;
  const next = await db.collection("prepare").where("status", "==", "queued").limit(1).get();
  if (next.empty) {
    logger.info("prepareProfession: nothing left in the queue");
    return;
  }
  await next.docs[0].ref.update({ status: "run" });
}
