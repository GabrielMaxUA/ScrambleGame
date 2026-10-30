// cleanSpaces.ts — one-off tool, run from a Mac, never deployed as a function (index.ts doesn't export it).
//
// Why: GPT sometimes puts odd characters into words — a non-breaking space between two words, a soft hyphen inside
// one ("Brot­teller"), a zero-width space, double spaces. In the game each became an empty tile or glued two words
// together. New words are cleaned when they're saved (openai.ts plainSpaces, since 30 October 2026); this tool cleans
// the words already in the bank, with the very same function.
//
// How to run (from the functions/ folder; also in functions/README.md "Cleaning odd spaces"):
//   npm run build
//   node lib/tools/cleanSpaces.js --project <project>            # 1. dry run: lists every bad value, changes nothing
//   node lib/tools/cleanSpaces.js --project <project> --apply    # 2. writes the cleaned values
// Needs `gcloud auth application-default login` once. No OpenAI call.
//
// What is checked: every translation of every word in Firestore "words" (the English word too). A value is "bad" when
// plainSpaces changes it: an odd or repeated space, a space at either end, or an invisible mark (soft hyphen,
// zero-width space, word joiner, BOM). Joiners that belong to the spelling (ZWNJ/ZWJ in Persian or Indian scripts)
// are not touched. The English name (`word`, also the document ID) is only reported, never renamed here — renaming a
// word would split it from the phones that already saved it.
// --apply: one update per bad translation, only if the value is still the one the dry run saw.

import { options, configureFirebase, run } from "./common";

// MARK: - main
async function main() {
  const opts = options();
  configureFirebase(opts.project);
  const store = await import("../store");            // only now: it starts Firebase Admin with the settings above
  const { plainSpaces } = await import("../openai");
  const { FieldPath } = await import("firebase-admin/firestore");

  const snapshot = await store.db.collection("words").get();
  const fixes: { id: string; lang: string; from: string; to: string }[] = [];
  const badNames: string[] = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() as import("../store").WordDoc;
    if (opts.word && data.word !== opts.word) continue;
    if (typeof data.word === "string" && plainSpaces(data.word) !== data.word) badNames.push(doc.id);
    for (const [lang, value] of Object.entries(data.translation ?? {})) {
      if (typeof value !== "string") continue;
      const clean = plainSpaces(value);
      if (clean !== value && clean) fixes.push({ id: doc.id, lang, from: value, to: clean });
    }
  }

  const visible = (text: string) => JSON.stringify(text).replace(/[­​⁠﻿]|[^\S ]/gu,
    (c) => `⟨U+${c.codePointAt(0)!.toString(16).toUpperCase().padStart(4, "0")}⟩`);
  console.log(`${snapshot.size} words checked: ${fixes.length} translations to clean, ${badNames.length} English names with odd spaces.`);
  for (const f of fixes) console.log(`  ${f.id} [${f.lang}]: ${visible(f.from)} -> ${visible(f.to)}`);
  for (const id of badNames) console.log(`  English name (not changed, fix by hand if needed): ${visible(id)}`);

  if (!opts.apply) {
    if (fixes.length) console.log(`\nDry run: nothing changed. Run again with --apply to write the ${fixes.length} cleaned values.`);
    return;
  }
  let written = 0;
  for (const f of fixes) {
    const ref = store.db.collection("words").doc(f.id);
    const current = (await ref.get()).get(new FieldPath("translation", f.lang));
    if (current !== f.from) {
      console.log(`  skipped ${f.id} [${f.lang}]: changed meanwhile`);
      continue;
    }
    await ref.update(new FieldPath("translation", f.lang), f.to);
    written++;
  }
  console.log(`Done: ${written} translations cleaned.`);
}

run(main);
