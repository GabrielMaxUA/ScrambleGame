# LearnScrumble Cloud Functions

Server code for the app (TypeScript, Node 22, region `us-central1`). The app calls these instead of OpenAI,
so the OpenAI key never ships inside the app and only the server writes to the shared word bank.
What's left: `Docs/remaining.md` §3. (The server migration plan was finished and removed on 30 Oct 2026; see git history.)

| Function | What it does | Replaces in the app |
|---|---|---|
| `getWords` | Next batch for a job (a menu job's word list ends: GPT says "exhausted", or 500 words; then `jobs/{key}` is `complete` and only bank words are served — see "Profession word lists") — word bank first (bank words missing the player's languages are only translated by GPT, no new pictures), GPT new words only for the missing number; tags words with the job; counts the job | `RequestModel.nextBatch`, `generateUniqueWordList`, `FirebaseWordStore.saveIfNeeded`, `ProfessionStore` |
| `getPicture` | One word's picture: the stored one, a repaired link when the app reports it broken, or a new one (GPT → WebP → Storage → saved on the word) | `RequestModel.generateImage`, `FirebaseImageStore` |
| `getReviewWords` | Known words with translations and picture links. Not used by the app since 28 Oct 2026 ("My words" plays from the phone) | `RequestModel.generateStruggleReview`'s Firestore read |
| `reportPicture` | A user flags a wrong picture: a new picture is drawn for that user only, and the report is recorded (see "Reported pictures") | — (new) |
| `reviewReport` | Firestore trigger: you set a report's `status` to `approve` or `reject` | — (new) |
| `mailReports` | Every morning: email to support@learnscrumble.com with the new reports | — (new) |
| `mailAlert` | Right away, at most once per kind per day: email when OpenAI credits are used up or a user hits the daily picture cap (`alerts.ts`) | — (new) |

Files: `src/index.ts` (the callable functions), `src/openai.ts` (all OpenAI calls), `src/store.ts` (Firestore + Storage),
`src/errors.ts` (error codes the app maps to `GenerationError`).

## Filling the bank in the background (`prepareProfession`, `src/prepare.ts`)

Makes about 100 English words with pictures per menu job, so players get words straight from the bank.
Translations are added when a player first needs them (getWords translates bank words).

Start it in the Firebase console → Firestore → collection `prepare`:
- **one job:** document ID = the menu name in lowercase (e.g. `cook`), field `status` = `run`; optional `target` = 20
  for a small test.
- **all menu jobs:** document `_all` with `status` = `run`; the 32 jobs are queued and filled one after another.
- **pause:** `status` = `paused`; **resume** or **retry after "failed"**: `status` = `run`.
- **refused pictures:** when OpenAI's safety system refuses a picture (e.g. "violence" for swarf or a reamer), the word
  gets `pictureRefused: true` and is skipped; the log shows the word and the prompt ("picture refused"). `getPicture`
  still tries again when a player reaches it. A job that fails for another reason no longer stops the queue: the next
  queued job starts (since 29 Oct 2026).
- **OpenAI credits used up** (429 `insufficient_quota`, not retried): the running job goes to `paused` with the error
  "OpenAI credits used up…" and the rest stay `queued`. Add credits (platform.openai.com → Billing), then set that
  job's `status` to `run`; the queue continues by itself. Players see "We can't prepare new words right now" instead
  of "Our servers are busy" (since 29 Oct 2026). Jobs left `failed` by an earlier stop: set them to `queued`.

Each job's document shows `words` (with pictures), `steps`, `lastStep` and any `error`. One step = 10 new words and
up to 15 pictures; it ends with `done`. Costs roughly one low-quality OpenAI picture per new word: watch the OpenAI
usage page during a big run. When the menu changes, update `MENU_JOBS` in `src/prepare.ts`.

## Profession word lists (since 30 Oct 2026)

A menu job's vocabulary is the common, everyday items of that job, so it has an end. Players fill it on the fly:
- the bank is played first (about 100 prepared words per job); only when a player has played them all does `getWords`
  ask GPT for new words, and then only paying users get that far (free users get 10 words);
- GPT answers `"exhausted": true` when no common items are left, and `checkWords` drops new words that don't belong
  to the job or repeat a bank word;
- the job becomes **complete** (Firestore `jobs/{key}`: `status`, `words`, `reason`) when GPT says exhausted or brings
  nothing usable in 3 tries (once the job has 100 words), or at 500 words (`MAX_WORDS_PER_JOB`);
- after that no more GPT words for the job; a player who has played everything gets `not-found "jobComplete"` → the
  app's "🎉 You've played every word for this profession" screen. Translations for new language pairs still work;
- to let a job grow again: set `jobs/{key}.status` to `open` in the console.
A player over 100 new pictures today gets `resource-exhausted "pictureLimit"` → "You've reached today's limit of new
pictures" (older app builds show "busy").

## Secret

The OpenAI key is in Google Secret Manager as `OPENAI_API_KEY` (projects `scrumblegame` and `scrumblegame-dev`).
Never put it in a file. To replace it: `firebase functions:secrets:set OPENAI_API_KEY --project <project>`,
then deploy again so the functions pick up the new version.

## Everyday commands (from this `functions/` folder)

`npm install` first on every Mac (and after a pull that changes `package.json`): `node_modules` isn't in git, and
without it the build stops with "Cannot find module 'nodemailer'".

```
npm install                      # once per Mac, and after package.json changes
npm run build                    # TypeScript -> lib/ (deploy does this by itself)
firebase deploy --only functions --project scrumblegame-dev    # test project first
firebase deploy --only functions --project scrumblegame        # production
firebase functions:log --project scrumblegame                  # recent logs (or Firebase console -> Functions -> Logs)
```

## Emulator (free, local, nothing real touched)

```
firebase emulators:start --only functions,firestore,storage,auth --project scrumblegame-dev
```
Emulator UI: http://localhost:4000. The functions in the emulator still call the real OpenAI API (costs money),
using the key from a local file `functions/.secret.local` with one line `OPENAI_API_KEY=...` — that file is
git-ignored; delete it when you're done.

## Stale picture links

Some old words have picture links with an outdated download token (the file was uploaded again later), which the
closed Storage rules refuse (403). When the app can't download a stored picture, it calls `getPicture` with
`broken: true`; the server rebuilds the link with the file's current token and saves it (no new picture, no cost),
or draws a new picture if the file is gone. Each word is fixed the first time someone plays it.

## Reported pictures (`reportPicture`, `reports.ts`)

The flag on a game picture calls `reportPicture` with the word, the menu job and the picture link the user saw.
- **For the reporter, right away:** GPT writes a clear description for that job (`describePicture`, e.g. "a bottle of
  motor oil … NOT an egg"), a picture is drawn and saved in Storage `reports/<id>/…`, and only the reporting phone
  gets it (kept with the word in "My words"). **The bank picture doesn't change.**
- **For you, every morning at 8:00 (Toronto):** `mailReports` emails support@learnscrumble.com the reports since the
  last email: word, jobs, reports and different users, the current and the suggested picture, and a **Review** link.
  No new reports, no email. Sent through Namecheap Private Email (needs the secret below). To send it right away:
  Google Cloud console → Cloud Scheduler (project `scrumblegame`) → job `firebase-schedule-mailReports-us-central1` →
  ⋮ → **Force run** (tested 28 Oct 2026).
- **Your decision:** open the Review link (Firestore → `reports` → the word) and set `status` to
  - `approve` → `reviewReport` copies the suggested picture over the word's picture for everyone (the old one goes to
    `rejected/`), saves its description on the word, and sets `status` to `approved`;
  - `reject` → `status` becomes `rejected`, nothing changes for others (the reporter keeps their picture).

  A new report on the same word sets it back to `new` and it comes in the next email.
- **Limits:** 10 reports per user per day (`reportUsage/{uid}`); separately, 100 new pictures per user per day in
  `getPicture` (`pictureUsage/{uid}`, `PICTURES_PER_DAY`; over it `getWords` serves bank words only and an alert
  email goes out). If the bank picture was already replaced since the
  user saw it, they get that one and nothing is drawn. Each report costs one text request + one low-quality picture.
- **Email secret (once per project):** the support@learnscrumble.com mailbox password —
  `firebase functions:secrets:set SUPPORT_EMAIL_PASSWORD --project scrumblegame` (and `--project scrumblegame-dev`).
  If you change the mailbox password in Namecheap, set the secret again and redeploy.

## Splitting shared words (`src/tools/splitSharedWords.ts`, one-off)

Before 28 October 2026 GPT named words plainly, so jobs share entries like "oil" (one picture, one translation for
the cook AND the auto mechanic — "олія" is wrong for a mechanic). New words are named per job ("motor oil"); this
tool splits the old shared ones. Run it from this folder on your Mac, dev first:

```bash
npm run build
gcloud auth application-default login
node lib/tools/splitSharedWords.js --project scrumblegame-dev
```

1. **Dry run** (the command above): lists the words two or more jobs share, asks GPT which mean different things,
   and writes `plans/split-plan-<project>.json` (not in git, not deployed). Nothing in Firebase changes. Read the
   printed list; in the file you can change a new name, or set `"same": true` to leave a word alone.
2. **Apply:** `node lib/tools/splitSharedWords.js --project scrumblegame-dev --apply`. Each job gets its own entry
   ("motor oil" for the auto mechanic) with a new picture; the old word loses that job's tag. Translations are made
   when a player first needs them, in the job's meaning. A record per word goes to Firestore `splits`.
3. Check in the app (dev), then repeat both steps with `--project scrumblegame`.

The OpenAI key is the functions' own secret `OPENAI_API_KEY`: the tool reads it from Secret Manager through the
Firebase CLI (`firebase login`), keeps it in memory only and never prints it.

`--word oil` limits it to one word (try that first), `--limit 50` to the first 50 shared words. Running `--apply`
twice is safe. Cost: one text request per 30 shared words, plus one text request and one cheap picture per new word.

## Checking translations (`src/tools/checkTranslations.ts`, one-off)

Checks EVERY word against all the jobs it's tagged with: wrong translations for those jobs ("олія" for an auto
mechanic), words that don't belong to a job, and words whose jobs mean different items (those go to the split tool).

```bash
npm run build
node lib/tools/checkTranslations.js --project scrumblegame
```

The dry run writes `plans/translation-plan-<project>.json` and prints three lists. **Read every suggestion** — GPT
is sometimes wrong itself (on 28 October 2026 it suggested Russian "противень" for Ukrainian, and "рокла", a
pallet jack, for a hand truck). In the file set `"apply": false` or change `"fix"`, then
`node lib/tools/checkTranslations.js --project scrumblegame --apply`. Changes are logged in Firestore
`translationFixes`. Options: `--word`, `--lang uk-UA`, `--limit`. Cost: one text request per 25 words.

## Notes

- App Check is enforced (`enforceAppCheck: true` in `src/index.ts`, 29 Oct 2026, after the TestFlight build was verified
  on a real iPhone). A simulator or Xcode run without a registered debug token is refused.
- No word counting on the server (removed 28 Oct 2026): the 10 free words are once per install and the job unlocks are
  checked on the phone (`FreeAllowance`, `Purchases`). The server doesn't verify purchases yet. `getWords` is deployed
  without the count (28 Oct 2026), so the old `usage` collection can be deleted; `reportUsage/{uid}` (10 reports a day) stays.
- The first deploy to a project can fail for one function with "Build failed … An unexpected error occurred" (Cloud Build
  setting itself up). Deploy just that function again: `firebase deploy --only functions:<name> --project <project>`.
- The app needs nothing else: Firestore and Storage rules can stay closed to phones (`allow read, write: if false`),
  because the functions use the Admin SDK, which ignores rules.
- `gpt-image-1-mini` is marked deprecated by OpenAI: plan the replacement model before it's switched off.
