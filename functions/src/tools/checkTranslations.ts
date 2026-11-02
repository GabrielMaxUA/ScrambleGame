// checkTranslations.ts — one-off tool, run from a Mac, never deployed as a function (index.ts doesn't export it).
//
// Why: words and translations were made by GPT one batch at a time, sometimes from the bare English word, so some
// are wrong for the job they're taught for ("oil" -> "олія", cooking oil, for an auto mechanic) and some words don't
// belong to a job at all. This tool checks EVERY word against ALL the jobs it's tagged with.
//
// How to run (from the functions/ folder; also in functions/README.md "Checking translations"):
//   npm run build
//   node lib/tools/checkTranslations.js --project <project>            # 1. dry run: checks, writes the plan, changes nothing
//   node lib/tools/checkTranslations.js --project <project> --apply    # 2. applies the plan file (edit it first if needed)
// Options: --word "oil", --lang uk-UA (only that language's translations), --limit 50 (first 50 words).
// Needs `gcloud auth application-default login` once; the OpenAI key comes from Secret Manager (common.ts).
//
// 1. Dry run:
//    - every word in Firestore "words" with at least one job, with its jobs and its translations (English left out:
//      it's the word itself) -> GPT, 25 words per request (openai.reviewTranslations)
//    - a batch whose GPT reply is garbled is tried 3 times, then skipped (its words are listed in "skipped" and printed;
//      run again with --word for them); the plan is saved after every batch, so a stopped run keeps what it found
//    - writes plans/translation-plan-<project>.json with three lists, each entry with "apply": true:
//        fixes      — wrong translations: language, current word, the fix, the reason
//        notForJob  — a job the word doesn't belong to (its tag would be removed)
//        split      — words whose jobs mean different items: NOT changed here, run splitSharedWords for them
//      and prints them. Set "apply": false (or change "fix") in the file for anything you don't agree with.
// 2. --apply (only entries with "apply": true):
//    - fixes: the translation is replaced, unless it changed in Firestore since the dry run (then skipped)
//    - notForJob: the job tag is removed from the word (getWords no longer serves it for that job)
//    - each change is recorded in Firestore "translationFixes" (word, what changed, old and new, time)
//    Phones keep the words they already saved ("My words") until those are played again from the bank; new games
//    get the fixed words. Running --apply twice is safe.
// Cost: one GPT text request per 25 words (about 35 for 900 words), nothing for --apply.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import * as path from "node:path";
import { options, configureFirebase, openAIKey, planPath as toolPlanPath, run } from "./common";

interface Fix { word: string; lang: string; current: string; fix: string; reason: string; apply: boolean }
interface NotForJob { word: string; job: string; reason: string; apply: boolean }
interface Split { word: string; jobs: string[]; reason: string }
interface Plan { project: string; created: string; checked: number; fixes: Fix[]; notForJob: NotForJob[]; split: Split[];
               skipped?: string[] }

const BATCH = 25;                    // words per GPT request
const TRIES = 3;                     // a garbled GPT reply is asked again this many times in all
const planPath = (project: string) => toolPlanPath("translation-plan", project);

// MARK: - main
async function main() {
  const opts = options();
  configureFirebase(opts.project);
  const apiKey = opts.apply ? "" : openAIKey(opts.project);   // --apply doesn't call OpenAI
  const store = await import("../store");                    // only now: it starts Firebase Admin with the settings above
  if (opts.apply) await apply(opts.project, store, opts.word);
  else await dryRun(opts.project, apiKey, store, await import("../openai"), opts.word, opts.lang, opts.limit);
}

// MARK: - dryRun
// Every tagged word -> GPT review -> plan file. Changes nothing in Firebase.
async function dryRun(project: string, apiKey: string, store: typeof import("../store"),
                      openai: typeof import("../openai"), only?: string, lang?: string, limit?: number) {
  const snapshot = await store.db.collection("words").get();
  let words = snapshot.docs
    .map((d) => d.data() as import("../store").WordDoc)
    .filter((d) => (d.professions ?? []).length > 0 && (!only || d.word === only))
    .map((d) => ({
      word: d.word,
      jobs: [...new Set(d.professions)],
      translations: Object.fromEntries(Object.entries(d.translation ?? {})
        .filter(([code, text]) => !code.startsWith("en") && text && (!lang || code === lang))),
    }));
  if (limit) words = words.slice(0, limit);
  const count = words.reduce((n, w) => n + Object.keys(w.translations).length, 0);
  console.log(`${snapshot.size} words in the bank; checking ${words.length} words with a job and ${count} translations…`);

  const plan: Plan = { project, created: new Date().toISOString(), checked: words.length, fixes: [], notForJob: [], split: [],
                       skipped: [] };
  const jobsOf = new Map(words.map((w) => [w.word, w.jobs]));
  const save = () => {
    mkdirSync(path.dirname(planPath(project)), { recursive: true });
    writeFileSync(planPath(project), JSON.stringify(plan, null, 2));
  };
  for (let i = 0; i < words.length; i += BATCH) {
    const batch = words.slice(i, i + BATCH);
    let review: Awaited<ReturnType<typeof openai.reviewTranslations>> | undefined;
    for (let attempt = 1; attempt <= TRIES && !review; attempt++) {
      try {
        review = await openai.reviewTranslations(apiKey, batch);
      } catch (error) {
        if (String(error).includes("outOfCredits")) throw error;      // no point trying again
        console.log(`  batch ${i + 1}–${i + batch.length}: try ${attempt} failed (${error instanceof Error ? error.message : error})`);
      }
    }
    if (review) {
      plan.fixes.push(...review.wrong.map((f) => ({ ...f, apply: true })));
      plan.notForJob.push(...review.notForJob.map((n) => ({ ...n, apply: true })));
      plan.split.push(...review.split.map((s) => ({ ...s, jobs: jobsOf.get(s.word) ?? [] })));
    } else {
      plan.skipped!.push(...batch.map((w) => w.word));
    }
    save();                                                         // a stopped run keeps what it found
    console.log(`  ${Math.min(i + BATCH, words.length)}/${words.length}`);
  }

  console.log(`\nWrong translations (${plan.fixes.length}):`);
  for (const f of plan.fixes) console.log(`  ${f.word} [${f.lang}]: ${f.current} -> ${f.fix}  (${f.reason})`);
  console.log(`\nNot for this job (${plan.notForJob.length}):`);
  for (const n of plan.notForJob) console.log(`  ${n.word} — ${n.job}  (${n.reason})`);
  console.log(`\nJobs mean different items, run splitSharedWords (${plan.split.length}):`);
  for (const s of plan.split) console.log(`  ${s.word}: ${s.jobs.join(", ")}  (${s.reason})`);
  if (plan.skipped!.length) console.log(`\nNot checked, GPT kept failing (${plan.skipped!.length}): ${plan.skipped!.join(", ")}`);
  console.log(`\nPlan written to ${planPath(project)} — set "apply": false or change "fix" where you disagree, then run with --apply.`);
}

// MARK: - apply
// The plan's entries with "apply": true (see the top of this file).
async function apply(project: string, store: typeof import("../store"), only?: string) {
  const plan = JSON.parse(readFileSync(planPath(project), "utf8")) as Plan;
  if (plan.project !== project) throw new Error(`The plan is for ${plan.project}, not ${project}`);
  const { FieldValue, FieldPath } = await import("firebase-admin/firestore");
  const log = store.db.collection("translationFixes");
  let fixed = 0, skipped = 0, untagged = 0;

  for (const f of plan.fixes.filter((f) => f.apply && (!only || f.word === only))) {
    const doc = (await store.fetchWords([f.word])).get(f.word);
    if (doc?.translation?.[f.lang] !== f.current) {
      console.log(`  skipped ${f.word} [${f.lang}]: changed since the dry run`);
      skipped++;
      continue;
    }
    await store.db.collection("words").doc(store.docID(f.word)).update(new FieldPath("translation", f.lang), f.fix);
    await log.add({ word: f.word, kind: "translation", lang: f.lang, from: f.current, to: f.fix, reason: f.reason, at: FieldValue.serverTimestamp() });
    console.log(`  ${f.word} [${f.lang}]: ${f.current} -> ${f.fix}`);
    fixed++;
  }
  for (const n of plan.notForJob.filter((n) => n.apply && (!only || n.word === only))) {
    await store.db.collection("words").doc(store.docID(n.word)).update({ professions: FieldValue.arrayRemove(n.job) });
    await log.add({ word: n.word, kind: "removedJob", job: n.job, reason: n.reason, at: FieldValue.serverTimestamp() });
    console.log(`  ${n.word}: no longer taught for ${n.job}`);
    untagged++;
  }
  console.log(`Done: ${fixed} translations fixed, ${skipped} skipped, ${untagged} job tags removed.`);
  if (plan.split.length) console.log(`${plan.split.length} words need splitting: node lib/tools/splitSharedWords.js --project ${project}`);
}

run(main);
