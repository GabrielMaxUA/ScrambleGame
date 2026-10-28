// splitSharedWords.ts — one-off tool, run from a Mac, never deployed as a function (index.ts doesn't export it).
//
// Why: until 28 October 2026 GPT named words plainly ("oil"), so one bank entry served every job that uses the word,
// with ONE picture and ONE translation per language. A word that means different things in two jobs ("oil": cooking
// oil for a cook, motor oil for an auto mechanic) then shows the wrong picture or word to one of them ("олія" for a
// mechanic). New words are job-specific since the prompt change; this tool splits the existing ones.
//
// How to run (from the functions/ folder; steps also in functions/README.md "Splitting shared words"):
//   npm run build
//   gcloud auth application-default login                       # once: your Google login for Firestore + Storage
//   node lib/tools/splitSharedWords.js --project <project>          # 1. dry run: looks, writes the plan, changes nothing
//   node lib/tools/splitSharedWords.js --project <project> --apply  # 2. carries out the plan file (edit it first if needed)
// Options: --word "oil" (only that word), --limit 50 (only the first 50 shared words). Try --project scrumblegame-dev first.
//
// 1. Dry run:
//    - the OpenAI key: the functions' own secret OPENAI_API_KEY, read from Secret Manager through the Firebase CLI
//      (openAIKey); an OPENAI_API_KEY already set in the terminal wins
//    - reads every word in Firestore "words" that two or more jobs share (professions has 2+ entries)
//    - asks GPT, 30 words per request, whether each means the same item in all its jobs (openai.meanings)
//    - writes plans/split-plan-<project>.json: every shared word with same/different, the reason, and for
//      different ones the new English name per job. Prints a summary and how many new pictures --apply would draw.
// 2. --apply, per word marked "same": false in the plan (the plan file is the source of truth — edit names, or set
//    "same": true to skip a word):
//    - every job whose new name differs from the word gets that entry: an existing word just gets the job tag;
//      a new word is created (no translations yet) and gets a picture: GPT describes it for the job
//      (describePicture) -> picture -> Storage -> saved on the word with its description
//    - the job tag is removed from the old word ("oil"), so getWords no longer serves it for that job.
//      An old word left with no jobs stays in Firestore (phones that already played it still know it) but is
//      never served again from a job's bank.
//    - translations of the new words are made when a player first needs them (getWords step 3b translates bank
//      words with a picture), in the job's meaning ("motor oil" -> "моторна олива").
//    - a record per split word in Firestore "splits" (word, new names, time), for checking later.
//    Running --apply twice is safe: tags are added/removed only once, and words that already have a picture aren't
//    drawn again.
// Cost: one GPT text request per 30 shared words (dry run), and one text request + one low-quality picture per new
// word (--apply).

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import * as path from "node:path";
import { options, configureFirebase, openAIKey, planPath as toolPlanPath, run } from "./common";

interface PlanWord {
  word: string;                      // the shared English name, e.g. "oil"
  jobs: string[];                    // the jobs tagged on it, e.g. ["cook", "auto mechanic"]
  same: boolean;                     // true -> left alone
  names: Record<string, string>;     // job -> new English name (only when same is false)
  reason: string;                    // GPT's short explanation
}
interface Plan { project: string; created: string; words: PlanWord[] }

const BATCH = 30;                    // shared words per GPT request
const planPath = (project: string) => toolPlanPath("split-plan", project);

// MARK: - main
async function main() {
  const opts = options();
  configureFirebase(opts.project);
  const apiKey = openAIKey(opts.project);
  const store = await import("../store");           // only now: it starts Firebase Admin with the settings above
  const openai = await import("../openai");
  if (opts.apply) await apply(opts.project, apiKey, store, openai, opts.word);
  else await dryRun(opts.project, apiKey, store, openai, opts.word, opts.limit);
}

// MARK: - dryRun
// Finds the shared words, asks GPT about their meanings, writes the plan file. Changes nothing in Firebase.
async function dryRun(project: string, apiKey: string, store: typeof import("../store"),
                      openai: typeof import("../openai"), only?: string, limit?: number) {
  const snapshot = await store.db.collection("words").get();
  let shared = snapshot.docs
    .map((d) => d.data() as import("../store").WordDoc)
    .filter((d) => (d.professions ?? []).length >= 2 && (!only || d.word === only))
    .map((d) => ({ word: d.word, jobs: [...new Set(d.professions)] }));
  if (limit) shared = shared.slice(0, limit);
  console.log(`${snapshot.size} words in the bank, ${shared.length} shared by two or more jobs. Asking GPT…`);

  const words: PlanWord[] = [];
  for (let i = 0; i < shared.length; i += BATCH) {
    const batch = shared.slice(i, i + BATCH);
    const answers = await openai.meanings(apiKey, batch);
    for (const item of batch) {
      const m = answers.get(item.word);
      words.push({ word: item.word, jobs: item.jobs, same: m?.same ?? true, names: m?.names ?? {}, reason: m?.reason ?? "no answer" });
    }
    console.log(`  ${Math.min(i + BATCH, shared.length)}/${shared.length}`);
  }

  const plan: Plan = { project, created: new Date().toISOString(), words };
  mkdirSync(path.dirname(planPath(project)), { recursive: true });
  writeFileSync(planPath(project), JSON.stringify(plan, null, 2));

  const split = words.filter((w) => !w.same);
  const newNames = new Set(split.flatMap((w) => Object.values(w.names).filter((n) => n !== w.word)));
  console.log(`\nDifferent meanings (${split.length}):`);
  for (const w of split) {
    console.log(`  ${w.word}: ${Object.entries(w.names).map(([job, name]) => `${job} -> ${name}`).join(", ")}  (${w.reason})`);
  }
  console.log(`\nSame meaning, left alone: ${words.length - split.length}`);
  console.log(`--apply would create or tag ${newNames.size} entries (a new picture for each one that doesn't exist yet).`);
  console.log(`Plan written to ${planPath(project)} — check it, edit names or set "same": true to skip, then run with --apply.`);
}

// MARK: - apply
// Carries out the plan file's "same": false words (see the top of this file).
async function apply(project: string, apiKey: string, store: typeof import("../store"),
                     openai: typeof import("../openai"), only?: string) {
  const plan = JSON.parse(readFileSync(planPath(project), "utf8")) as Plan;
  if (plan.project !== project) throw new Error(`The plan is for ${plan.project}, not ${project}`);
  const { FieldValue } = await import("firebase-admin/firestore");
  const todo = plan.words.filter((w) => !w.same && (!only || w.word === only));
  console.log(`Splitting ${todo.length} words…`);

  for (const w of todo) {
    for (const job of w.jobs) {
      const name = w.names[job]?.trim().toLowerCase();
      if (!name || name === w.word) continue;          // this job keeps the old word
      const existing = (await store.fetchWords([name])).get(name);
      const ref = store.db.collection("words").doc(store.docID(name));
      if (existing) {
        await ref.update({ professions: FieldValue.arrayUnion(job) });
      } else {
        await ref.set({ id: name, word: name, translation: {}, image: "", professions: [job] });
      }
      if (!existing?.image) {
        const description = await openai.describePicture(apiKey, name, job);
        await store.savePicture(name, await openai.image(apiKey, description));
        await store.saveImagePrompt(name, description);
      }
      await store.db.collection("words").doc(store.docID(w.word)).update({ professions: FieldValue.arrayRemove(job) });
      console.log(`  ${w.word} -> ${name} for ${job}${existing ? " (existing word, tagged)" : " (new word, picture drawn)"}`);
    }
    await store.db.collection("splits").doc(store.docID(w.word)).set({
      word: w.word, names: w.names, reason: w.reason, at: FieldValue.serverTimestamp(),
    });
  }
  console.log("Done.");
}

run(main);
