# LearnScrumble: moving the AI to the server (plan)

*Written 15 October 2026. Progress updated 16 October: Phases 0–2 done. **Updated 27 October: Phases 3, 4, 5, 7 (monitoring) and 8 done** — the app gets its words and pictures from Cloud Functions in both projects, the OpenAI key is only on the server (new key; the old one is deleted), anonymous sign-in and App Check run. Left: deploy the getPicture link repair (Phase 6), fix App Attest on real iPhones ("App attestation failed": check the Team ID 7XZJ4BCPR6 in App Check) and then enforcement (Phase 7), server alerts (Phase 8), Phase 9 and the App Store answers (Phase 10). Tick items off as we finish them, the same way as `checklist.md`.*

**Where this stands against `checklist.md`**
- ✅ **Can go ahead now:** Phases 0–2. Crash reporting and analytics are an open ⬜ **to do** in the checklist (§4.4, §9), and they don't depend on any decision.
- ✅ *(27 October: we went ahead with the hybrid bank, see `AppFlowIdeas.md` §1; packs can still be added on top)* ~~**Waits for Konstantin:** Phases 3–9.~~ The checklist marks "OpenAI key off the phone" and "lock down Firebase" as ❓ **need discussion**, because they depend on **packs vs live AI** (§5, §8 Q1). Konstantin asked to settle that first, "so you don't build a server you won't need". `AppFlowIdeas.md` §1 has the hybrid bank agreed between us, but it still needs his OK.

**Goal:** the OpenAI key leaves the phone. All AI calls and all writes to the shared word library happen in Firebase Cloud Functions. The app only asks and reads. We add crash reports, analytics and server logging along the way.

**Decisions so far**

| Topic | Decision |
|---|---|
| Server | Cloud Functions for Firebase (2nd gen), **TypeScript** |
| Region | **`us-central1`** for the functions, next to Firestore (`nam5`, United States) and the Storage buckets (US). *(Planned as `europe-west1`; changed on 27 October because the existing database is already in the US. The privacy page covers the transfer, §7)* |
| Projects | **`scrumblegame-dev`** (new, for testing) + `scrumblegame` (production) |
| Answers / progress | **Stay on the iPhone in SwiftData**, as today. The server never stores what a user answered |
| Daily limit | **10 words** (was 20 until 27 October). The Keychain counter enforces it on the phone; the server counts words per anonymous user per day (`usage/{uid}`) but doesn't refuse yet — it can't see subscriptions until the paywall exists |
| Typed professions | Saved **in English**, without any user ID, so we can see which jobs to add to the list |
| Analytics consent | On/off switch in onboarding and Settings |

---

## How it works after the move

```
iPhone (anonymous sign-in + App Check token, both attached automatically)
   │  getWords("kucharz", pl → de, already seen: [...from SwiftData...])
   ▼
Cloud Function (us-central1)
   1. Checks: real app? (App Check, monitoring for now) · who? (anonymous ID) · daily count (counted, not enforced yet)
   2. Moderation: is the typed job text OK?
   3. One OpenAI call returns the English job name ("cook") + the 5 words
   4. Saves "cook" to the professions list (count +1) if it was typed, not picked
   5. Uses words from the bank (Firestore) first, OpenAI only for what's missing
   6. Pictures: from Storage, or generated → WebP → uploaded → saved
   ▼
iPhone gets words + picture links → downloads pictures → plays → SwiftData records answers
```

**What stays exactly as today:** SwiftData progress, the "already seen" list built from it, review of struggle words (the list of words comes from SwiftData; only the translations and pictures come from the server), settings, reminders, the tutorial and all the screens.

### About the typed profession

Today the app doesn't translate the job separately: it puts the typed text straight into the word prompt, and OpenAI understands it there. After the move, the same OpenAI call returns one extra field, the job's English name. That costs nothing extra and gives us two things:

1. **A list of jobs people actually type**, for example "cook: 14 times, first seen 3 Nov, last seen today". That's the list we review to decide which jobs to add to the menu (AppFlowIdeas: normalization and analyst review).
2. **Shared word banks across languages.** "kucharz", "cuisinier" and "Koch" all become "cook", so they reuse the same words and pictures instead of generating new ones.

Stored per job (Firestore `professions/{english-name}`): English name, how many times typed, first and last seen, picked from the list or typed, review status (new / added to the list / rejected). **No user ID and no original text**, and only after it passes moderation.

---

## The steps

Who does it: **You** = Firebase/Google/OpenAI consoles, card, Apple account. **Me** = code and files. **Both** = testing together. *(Since 15 October you do the "Me" steps yourself too, guided one step at a time, so you learn the setup.)*

### Phase 0: preparation

- ✅ **You:** the iOS app (bundle ID) is registered in `scrumblegame` (production) *(already done)*.
- ✅ **You:** create the Firebase project `scrumblegame-dev` with Google Analytics, and add the iOS app (same bundle ID, `com.MaxGabriel.LearnScrumble`) to it; download its `GoogleService-Info.plist`. *(15 October)*
- ✅ **You:** set up the app to use the dev plist in Debug builds and the production plist in Release builds. *(15 October, commit `a43ee47`)*
  - The plists live outside the app folder: `FirebaseConfig/Dev/` and `FirebaseConfig/Prod/`, both named `GoogleService-Info.plist`. They have to stay outside, because everything in `LearnScrumble/` is a synced folder that goes into the app.
  - A **Copy Firebase plist** Run Script build phase copies the right one into the app: `Release` (Archive) → Prod, anything else (Run) → Dev. Its input and output files are declared, because the project has User Script Sandboxing on.
  - The plists are **not in git** (`.gitignore`). Keep a backup; on a new Mac, download them again from the console.
  - ⚠️ *(16 October)* **Every Mac needs its own `FirebaseConfig/` folder.** After pulling the project onto the second Mac, the folder was missing: the copy step failed without stopping the build, and the only sign was "Could not get GOOGLE_APP_ID" from the dSYM upload step. Fixed by downloading the plists again. The dSYM zip, by contrast, is per Debug build, not per Mac.
  - ✅ *(16 October)* The **Copy Firebase plist** script now stops the build when the plist is missing, with a red Xcode error naming the file and the console to download it from (`scrumblegame-dev` for Debug, `scrumblegame` for Release).
  - ~~To fill the **production** bank while playing: Edit Scheme → Release.~~ *(27 October: replaced by the `FIREBASE_ENV` build setting, `Prod` by default for Debug too; Release is always Prod. See `README.md` → Dev and production)*
- ✅ **You:** Firestore in `scrumblegame-dev`: `(default)` database, Standard edition, **test mode**, no backups. *(15 October)* ⚠️ Test mode ends around **14 November 2026**; the closed rules of Phase 6 replace it.
- ✅ **You:** Storage in `scrumblegame-dev`: default bucket `scrumblegame-dev.firebasestorage.app` (no-cost US region, test data only), test mode. *(15 October; needed Blaze, see Phase 2)*
- ✅ **You:** `FirebaseImageStore` had the production bucket `gs://scrumblegame-tools` hard-coded, so dev pictures would still have gone to production. Now `#if DEBUG` uses the dev plist's default bucket, and Release keeps `scrumblegame-tools`. *(15 October, commit `a43ee47`)*
- ✅ **Both:** confirmed that Debug runs fill the dev Firestore and Storage and leave production untouched. *(15 October)*
- ✅ *(partly)* **You:** upgrade Node first: you have **Node 18**, and the current Firebase CLI and Cloud Functions need **Node 20 or newer** (`nvm install 22`). Then install the Firebase CLI and log in. *(16 October, on the main Mac: Node 22.15 was already there; `npm install -g firebase-tools` (CLI 15.34), `firebase login`, and `firebase projects:list` shows both projects. The CLI is a developer tool only: nothing of it goes into the app. Still to do on the second Mac, which has Node 18)*
- ✅ **Me:** add a `functions/` folder (TypeScript) and Firebase config files to the repo, outside the app folder. *(27 October: `functions/` with its own README; `firebase.json` has the functions and emulator settings)*

### Phase 1: crash reports and analytics (small, useful straight away)

- ✅ **You:** add FirebaseCrashlytics and FirebaseAnalytics (without the advertising ID parts), plus the dSYM upload build step. The app must keep "no tracking, no advertising identifier" (`AppStoreReadiness.md` §4). The dSYM upload script reads the plist from inside the app, so it must come **after** the Copy Firebase plist phase. *(15 October)*
  - Added `FirebaseAnalytics` and `FirebaseCrashlytics` from the existing `firebase-ios-sdk` package. `FirebaseAnalyticsIdentitySupport` (the advertising ID part) was left out on purpose.
  - An **Upload Crashlytics dSYM** Run Script phase sits last, after Copy Firebase plist, with its 5 input files declared for the sandbox.
  - Debug Information Format = **DWARF with dSYM File** for Debug and Release, so crashes during testing show file and line too.
  - Crashlytics is enabled in the `scrumblegame-dev` console and sees the app. In `scrumblegame` it switches on by itself with the first Release build (TestFlight, or Run with the scheme set to Release).
- ✅ **Both:** see a test crash arrive in dev Crashlytics. *(15 October: the issue shows "closure in SettingsView.body" and the reason "Test crash for Crashlytics")*
  - The test used a temporary **Test crash** button (`#if DEBUG`) at the bottom of `SettingsView`, calling `fatalError("Test crash for Crashlytics")`. It was **removed** after the test.
  - How to test again (add the button back for a moment): open the app from the simulator icon (a crash isn't recorded while Xcode's debugger is attached), crash it, then reopen it and leave it open for a minute, because the report is sent on the next launch.
  - **Debug quirk:** in Debug, Xcode puts your code in a separate `LearnScrumble.debug.dylib`, and the upload script doesn't send its decoder, so Crashlytics shows "Missing (required)" under dSYMs. For a Debug test, zip `LearnScrumble.app.dSYM` from DerivedData (`Build/Products/Debug-iphonesimulator`) and drag it onto the dSYMs page. Every new build needs a new upload. Release builds don't have this split.
- ✅ ~~Analytics starts collecting on launch by default.~~ Fixed 15 October: `LearnScrumble-Info.plist` (outside the synced app folder, merged into the generated Info.plist) sets `FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO`, so nothing is collected until the user agrees.
- ✅ **Me:** turn the `print` lines into proper logs, add crash breadcrumbs ("round finished", "generation failed") and report every `GenerationError` as a non-fatal error. *(16 October: `Services/Log.swift`)*
  - All `print` lines are now `Log.debug` / `Log.info` / `Log.error` (Apple's `os.Logger`), each with a category (`game`, `words`, `app`, ...). They show in Xcode's console as before, and in Console.app without Xcode (search `subsystem:com.MaxGabriel.LearnScrumble`).
  - `info` and `error` lines are also Crashlytics breadcrumbs, so a crash report shows the steps before it. `debug` lines (every tap) aren't.
  - When a load fails for the user (`generate`, `generateMore`, `generateStruggleReview`), the `GenerationError` is recorded as a non-fatal issue: one issue per case (fixed `reportCode`), with the step, both languages and the original error.
  - The typed profession is logged only as private detail: Xcode shows it, device logs show `<private>`, and it never goes to Crashlytics.
  - ✅ **Both:** tested 16 October. With no OpenAI key, starting a game failed with 401 → `serviceUnavailable`. The Xcode console showed the lines, and dev Crashlytics → **Non-fatals** got the issue *Domain: GenerationError, Code: 5*, with the keys (step, origin, target, underlying) and the breadcrumbs in its Logs tab.
  - Reading a non-fatal: the issue title is Crashlytics' own line (`FIRCLSNonFatalError.m`), ignore it. In the stack trace, the first **bold** lines are ours (`Log.report` → `reportFailure` → `generate()` → `AppManager.startGame()`): that says which load failed. *Why* it failed is in the **Logs** tab (e.g. `🚨 send — status=401…`) and the `underlying` key.
  - A non-fatal is sent on the **next launch**, like a crash; it can take 5–30 minutes to show. Debug builds need the dSYM zipped and uploaded by hand for line numbers (see the Debug quirk above).
- ✅ *(partly)* **Me:** analytics events: `onboarding_completed`, `tutorial_completed`, `tutorial_skipped`, `round_completed`, `daily_limit_reached`, `paywall_shown`, `trial_started`, `review_started`, `reminder_enabled`, `generation_failed` (error type only). The checklist requires at least onboarding finished, round finished, paywall shown and trial started (§4.4). `paywall_shown` and `trial_started` only start firing once the paywall exists (checklist §4.3). *(16 October: `Services/Track.swift`, one function per event. All are wired except `paywall_shown` and `trial_started`, which wait for the paywall. Parameters are languages, counts and error names only, never the profession. Sent only with the user's consent)*
  - Where they fire: `onboarding_completed` (+ origin, target) on the first Start Learning; `tutorial_completed` / `tutorial_skipped` when the tutorial closes; `round_completed` (mode game/review) at every checkpoint; `daily_limit_reached` when a round ends on the free limit; `review_started` (word count); `reminder_enabled` (source onboarding/settings) only when iOS allows notifications; `generation_failed` (error, step) next to the Crashlytics non-fatal.
- ✅ **Me:** analytics consent switch in onboarding and Settings, connected to Firebase's consent settings; off until the user agrees (EU). *(15 October: an optional "Share usage statistics" checkbox in the setup screen's "Your data" card and a toggle in Settings → Legal and support, both calling `AnalyticsConsent.apply`; AppDelegate applies the saved choice at every launch)*
- ✅ **Both:** check the events arrive in the dev project (DebugView). *(16 October: with statistics off nothing arrives; once switched on, `first_open`, `session_start` and `user_engagement` show in DebugView within seconds, and the app's own events fire at their moments. How to test: `README.md` → Testing tricks)*
- ✅ **Both:** see a non-fatal arrive decoded. *(16 October: an offline test shows as `GenerationError (1) offline` in Crashlytics → Non-fatals, with Keys and Logs)*
- ✅ **Me:** keep word names out of crash and error reports. *(16 October: every `Log.info` / `Log.error` line that named words, struggle words or OpenAI error bodies now puts them in the `private:` detail, so they show in Xcode but never in Crashlytics breadcrumbs. Reports carry steps, counts, languages and error types only, as `privacy.html` says)*
- ✅ **Me:** count the jobs people learn for, ahead of the server (pulled forward from Phase 4/9). *(16 October: `Services/ProfessionStore.swift`. The existing OpenAI word request also returns `job`, the profession's English name, or "invalid". When a game's first batch works, the job is counted once per install and job in Firestore `professions/{english name}`: `typed` (Not listed?) or `picked` (menu), `firstSeen`, `lastSeen`, `status` (`"in menu"` for jobs already in the menu, `"new"` for jobs missing from it; set `"added"` or `"rejected"` by hand after review). Review list: Firestore console → `professions` → Query → filter `status == "new"`, order by `typed` descending. No user ID, never the typed text. Plus the Analytics event `profession_selected` (menu name or "custom"). Tested on dev: menu "Cook" created `professions/cook` with picked = 1, and a second game with the same job didn't count again. The typed path works too: Ukrainian "Кухар" added typed +1 to the same `cook` document, and "Різноробочий" created `general laborer`. Privacy policy, manifest and README updated)*
- ✅ *(partly)* **Me:** before any build with Crashlytics or Analytics goes to TestFlight, update `PrivacyInfo.xcprivacy`, `privacy.html` and the App Store privacy answers together (`AppStoreReadiness.md` §1.1 says to keep them in sync). Don't wait for Phase 10. *(15 October: the manifest, `privacy.html`, `support.html` and the suggested App Store answers in `WebsiteContent/README.md` are updated. Still to do: **You** enter the answers in App Store Connect once the app exists there)*

### Phase 2: billing and safety limits

- ✅ **You:** `scrumblegame` (production) is on the **Blaze** plan *(already done)*.
- ✅ **You:** switch `scrumblegame-dev` to Blaze too (needed for its Storage bucket, and later for functions). *(15 October)*
- ✅ **You:** set a **budget alert** in Google Cloud Billing: **€10** for `scrumblegame`, **€5** for `scrumblegame-dev`, emails at 50%, 90% and 100% to billing admins. *(15 October)* These are alerts only; they don't stop spending.
- ✅ **You:** set a **monthly spend limit** on the OpenAI dashboard (Settings → Limits, e.g. $20 with an email at $10). *(15 October)* This is an alert too, not a hard stop. The real cap is **prepaid credit with auto recharge off** (Settings → Billing). *(Auto recharge turned off on 15 October.)* When the credit runs out, the app shows "service unavailable" to everyone, which is fine while testing.

### Phase 3: anonymous sign-in

- ✅ **You:** enable Anonymous sign-in in Firebase Authentication (both projects), with **auto clean-up** (anonymous accounts are deleted 30 days after they're created). *(27 October)*
- ✅ **Me:** sign in silently at launch, next to the existing Firebase setup in `AppDelegate`. No screen, no email. *(27 October: `Services/AnonymousAuth.swift`. `ensureSignedIn()` runs at launch and before every function call; if the account was cleaned up or disabled, it signs out and gets a new anonymous ID)*

### Phase 4: Cloud Functions (on dev first)

- ✅ **You:** put the OpenAI key into Secret Manager with one CLI command (I give you the command; the key never goes into the repo or the chat). *(27 October: `OPENAI_API_KEY` in both projects; production's was created during its first deploy)*
- ✅ **Me:** `getWords`: job + languages + seen words in, 5 words out; English job name, bank first, OpenAI for the rest; saves typed jobs to `professions`. *(27 October: `functions/src/index.ts`. Bank words need a picture and both languages; GPT words that already exist are reused, get missing translations and the job tag; new ones are created without a picture. Counts the job when the app sends `countJob`, same document format as before)*
- ⬜ **Me:** a meaning-aware bank key, for example "pipe (plumbing)" instead of just "pipe", so the same English name with another meaning in another job doesn't share translations and a picture (`AppFlowIdeas.md` §2). Easiest to decide before the server bank fills up.
- ✅ **Me:** `getPicture`: one word in, picture link out; generates, converts to WebP, uploads and saves only if missing. *(27 October; production bucket `scrumblegame-tools`)*
- ✅ **Me:** `getReviewWords`: struggle words in, translations + pictures out. *(27 October)*
- ✅ **Me:** moderation of typed job text before anything is generated. *(27 October: OpenAI `omni-moderation-latest`, only for a typed job the server hasn't named yet; refused → the app's "change your job" screen)*
- ✅ *(partly)* **Me:** daily limit (10 words) and per-user rate limits stored per anonymous user on the server. *(27 October: words per anonymous user per UTC day are counted in `usage/{uid}` and over-limit calls are logged, but not refused until the server can see subscriptions (paywall). Rate limits: not yet; `maxInstances: 10` caps the spend)*
- ✅ **Me:** clear error codes that map to the app's existing `GenerationError` cases (busy, offline, limit reached, refused text). *(27 October: `functions/src/errors.ts` ↔ `RequestModel.functionError`. "Limit reached" comes with enforcement)*
- ✅ **Both:** test everything on the Mac with the Firebase Emulator Suite (no cost, no risk), then deploy to `scrumblegame-dev`. *(27 October: deployed straight to `scrumblegame-dev` and tested there with the app; the emulator setup is in `functions/README.md` for later)*

### Phase 5: switch the app to the functions

- ✅ **Me:** `RequestModel` calls the functions instead of OpenAI; prompts, image conversion, uploads and the API key line are removed from the app. *(27 October: the key line is gone; the old OpenAI code is kept commented out in a LEGACY block for now)*
- ✅ *(partly)* **Me:** remove `FirebaseImageStore` and the writing half of `FirebaseWordStore`. *(27 October: no longer called and marked LEGACY; delete them together with RequestModel's LEGACY block once production has run a while)*
- ⬜ **Me:** `FreeAllowance` shows the server's count; the Keychain stays as the offline/local check.
- ✅ **Me:** loading bar still moves per finished picture (2 picture calls at a time, as today). *(27 October)*
- ✅ *(partly)* **Both:** full test on a device: new job, picked job, review, daily limit, airplane mode, server error. *(27 October, simulator, dev and production: a picked job (Cook), prefetch and the daily limit work. Still to test: a typed job, review, airplane mode, a real iPhone)*

### Phase 6: lock down Firebase

- ✅ **You:** Firestore rules: ~~signed-in users can read the word library;~~ nobody can read or write from a phone, because the app no longer touches Firestore (the functions bypass rules). Rules text: `match /{document=**} { allow read, write: if false; }`. Publish in both projects. *(27 October: published in both projects; `getWords` now does the `professions` write)*
- ✅ **You:** Storage rules: closed as well (`match /{allPaths=**} { allow read, write: if false; }`), for every bucket (production has two: the default one and `scrumblegame-tools`). Pictures still load, because the app uses their download links with a token. *(27 October: published. It showed that some old words had links with an outdated token (the file had been uploaded again), refused with 403: `getPicture` now repairs those links when the app reports them, each word the first time someone plays it. Also: production's `getPicture` had to be set to **Allow public access** in Cloud Run after its failed first deploy — our code still requires the app's sign-in)*
- ✅ *(partly)* **Both:** confirm with the rules test tool that a phone can no longer write, and play a round on each project after publishing. *(27 October: played on a real iPhone against production; the rules test tool check is still open)*

### Phase 7: App Check

- ✅ **You:** register the app for App Attest in Firebase App Check; add the simulator debug token. *(27 October, both projects, token time to live 1 hour)*
- ✅ **Me:** add App Check (App Attest) to the app; debug provider for the simulator. *(27 October: `Services/AppCheckSetup.swift`, installed before `FirebaseApp.configure()`; App Attest capability added. The Apple Program License Agreement had to be accepted first)*
- ✅ **You:** turn on **monitoring only** and watch the numbers for a few days. *(27 October: the functions run with `enforceAppCheck: false`; nothing enforced in the console)*
- ⬜ **You:** switch on **enforcement** for Functions, Firestore and Storage once almost all requests are verified. *(Check App Check → APIs after a day or two. Functions: `enforceAppCheck: true` in `functions/src/index.ts`, then deploy to both projects)*

### Phase 8: go live on production

- ✅ *(partly)* **Both:** deploy the functions and rules to `scrumblegame`; move the existing word library if needed (the current words and pictures stay usable). *(27 October: functions deployed — `getPicture` failed once with a Cloud Build error and worked on the retry; container images are cleaned up after 1 day. No move needed: the words and pictures stay where they were. Rules: Phase 6)*
- ✅ **You:** create a **new OpenAI key** for the server and **delete the old one**. The old key has been inside app builds, so treat it as exposed. *(27 October: new key in Secret Manager only; old key deleted)*
- ⬜ **Me:** server alerts: an email when OpenAI starts refusing requests or errors suddenly climb (Cloud Logging + Error Reporting).

### Phase 9: the profession list in practice

- ⬜ **Me:** a simple way for you to see the `professions` list sorted by count (Firestore console view to start; a small admin page later if useful). *(16 October: works now: Firebase console → Firestore → `professions`, sort by `typed` or `picked`)*
- ⬜ **Me:** background job `prepareProfession`: when a job is added to the menu, build its 100-word bank (first 10 fast, the rest after), plus 50 more on demand (AppFlowIdeas §1). Run it once for **every profession already in the picker** too (AppFlowIdeas §1, "Pre-generate the listed professions"). This replaces filling the bank by playing.
- ⬜ **Both:** decide the rule for adding a job (for example "typed 10+ times and looks right").

### Phase 10: privacy and App Store updates (before release)

- ✅ **Me:** `PrivacyInfo.xcprivacy`: add crash data, product interaction (analytics), user ID (anonymous); *(15 October: Crash Data, Device ID and Product Interaction added; 27 October: User ID, not linked, App Functionality)* profession text gets the extra purpose "Analytics" (improving the job list).
- ✅ **Me:** `privacy.html`: OpenAI now called from our server; anonymous ID; crash reports; analytics with consent; *(15 October: crash reports and analytics with consent; 27 October: our server, moderation, the anonymous ID and daily count, App Check, retention; `support.html` FAQ too. Not live until `firebase deploy --only hosting`)* typed jobs stored in English without a user ID; server region ~~`europe-west1`~~ United States (`us-central1`).
- ✅ **Me:** `WebsiteContent/README.md` privacy table and App Store answers updated. *(15 October: Crashlytics and Analytics; 27 October: the server, anonymous ID, daily count and App Check)*
- ⬜ **You:** update the App Store Connect privacy answers to match. Today they say "not linked to the user"; with an anonymous ID and server-side limits, check again whether that still holds.
- ✅ **Me:** move the internal docs (`checklist.md`, `AppFlowIdeas.md`, `AppStoreReadiness.md`, this file) out of `LearnScrumble/`. That folder is synced to the app, so they shipped inside it and anyone could read them (`AppStoreReadiness.md` §3). *(16 October: now in `Docs/` at the repository root: still in the repo for Konstantin, never in the app)*
- ✅ **Me:** update `checklist.md` and `AppStoreReadiness.md` (key off the phone, Firebase lock-down, crash reports and analytics → done). *(27 October; the lock-down stays open until the rules are published)*

---

## Costs to expect

| What | Roughly |
|---|---|
| Cloud Functions | Free up to about 2 million calls a month, then cents |
| Firestore / Storage | Free tier covers early use; grows slowly with the word library |
| App Check, Auth (anonymous), Crashlytics, Analytics | Free |
| OpenAI | The real cost, and it drops as the shared bank grows, because known words are never generated again |

## Still open (not part of this plan)

- ✅ ~~Consent step for sending the job to OpenAI (App Review 5.1.2).~~ Done 15 October, on the same setup-screen card as the analytics consent (`AppStoreReadiness.md` §1.4).
- Paywall with RevenueCat; it can use the same anonymous ID. Sandbox only, with no live products in your own App Store Connect account (checklist §4.3).
- Report button for wrong words or pictures; it would write to a `reports` collection through a function. App Review may expect it for AI content (`AppStoreReadiness.md` §2.1).
- "Delete my data": with the server it also needs to delete the user's limit documents (`usage/{uid}`). Old `usage` documents of cleaned-up anonymous IDs stay behind too; a scheduled clean-up function can remove them later. It's built but commented out today (`SettingsView.swift:68`, `AppManager.swift`).
- ✅ ~~Privacy policy, terms and support pages on Firebase Hosting in `scrumblegame`.~~ Live at https://learnscrumble.com since 18 October (`WebsiteContent/README.md`).
- Scheduled Firestore backups for **production** once real users are in the bank (none for dev).
- ✅ ~~The OpenAI key still lives in `RequestModel.swift`.~~ Gone from the app on 27 October; the new key is only in Secret Manager and the old one is deleted.
