# LearnScrumble: moving the AI to the server (plan)

*Written 15 October 2026. Progress updated 15 October (evening): Phase 0 mostly done. Tick items off as we finish them, the same way as `checklist.md`.*

**Where this stands against `checklist.md`**
- ✅ **Can go ahead now:** Phases 0–2. Crash reporting and analytics are an open ⬜ **to do** in the checklist (§4.4, §9), and they don't depend on any decision.
- ❓ **Waits for Konstantin:** Phases 3–9. The checklist marks "OpenAI key off the phone" and "lock down Firebase" as ❓ **need discussion**, because they depend on **packs vs live AI** (§5, §8 Q1). Konstantin asked to settle that first, "so you don't build a server you won't need". `AppFlowIdeas.md` §1 has the hybrid bank agreed between us, but it still needs his OK.

**Goal:** the OpenAI key leaves the phone. All AI calls and all writes to the shared word library happen in Firebase Cloud Functions. The app only asks and reads. We add crash reports, analytics and server logging along the way.

**Decisions so far**

| Topic | Decision |
|---|---|
| Server | Cloud Functions for Firebase (2nd gen), **TypeScript** |
| Region | **`europe-west1`** (Belgium), for functions, Firestore and Storage where possible |
| Projects | **`scrumblegame-dev`** (new, for testing) + `scrumblegame` (production) |
| Answers / progress | **Stay on the iPhone in SwiftData**, as today. The server never stores what a user answered |
| Daily limit | Enforced on the server; the Keychain counter stays as a quick local display |
| Typed professions | Saved **in English**, without any user ID, so we can see which jobs to add to the list |
| Analytics consent | On/off switch in onboarding and Settings |

---

## How it works after the move

```
iPhone (anonymous sign-in + App Check token, both attached automatically)
   │  getWords("kucharz", pl → de, already seen: [...from SwiftData...])
   ▼
Cloud Function (europe-west1)
   1. Checks: real app? (App Check) · who? (anonymous ID) · daily limit · rate limit
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
  - To fill the **production** bank while playing, as before: Edit Scheme → Run → Build Configuration → **Release**. Switch back to Debug for coding.
- ✅ **You:** Firestore in `scrumblegame-dev`: `(default)` database, Standard edition, **test mode**, no backups. *(15 October)* ⚠️ Test mode ends around **14 November 2026**; extend it or write the rules (Phase 6) before then.
- ✅ **You:** Storage in `scrumblegame-dev`: default bucket `scrumblegame-dev.firebasestorage.app` (no-cost US region, test data only), test mode. *(15 October; needed Blaze, see Phase 2)*
- ✅ **You:** `FirebaseImageStore` had the production bucket `gs://scrumblegame-tools` hard-coded, so dev pictures would still have gone to production. Now `#if DEBUG` uses the dev plist's default bucket, and Release keeps `scrumblegame-tools`. *(15 October, commit `a43ee47`)*
- ✅ **Both:** confirmed that Debug runs fill the dev Firestore and Storage and leave production untouched. *(15 October)*
- ⬜ **You:** upgrade Node first: you have **Node 18**, and the current Firebase CLI and Cloud Functions need **Node 20 or newer** (`nvm install 22`). Then install the Firebase CLI and log in.
- ⬜ **Me:** add a `functions/` folder (TypeScript) and Firebase config files to the repo, outside the app folder. *(Only once Phases 3–9 are agreed)*

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
- ⚠️ Analytics now starts collecting on launch by default, before the consent switch below exists. That's fine on dev, but no TestFlight or App Store build should go out until the consent switch and the privacy updates are done.
- ⬜ **Me:** turn the `print` lines into proper logs, add crash breadcrumbs ("round finished", "generation failed") and report every `GenerationError` as a non-fatal error.
- ⬜ **Me:** analytics events: `onboarding_completed`, `tutorial_completed`, `tutorial_skipped`, `round_completed`, `daily_limit_reached`, `paywall_shown`, `trial_started`, `review_started`, `reminder_enabled`, `generation_failed` (error type only). The checklist requires at least onboarding finished, round finished, paywall shown and trial started (§4.4). `paywall_shown` and `trial_started` only start firing once the paywall exists (checklist §4.3).
- ⬜ **Me:** analytics consent switch in onboarding and Settings, connected to Firebase's consent settings; off until the user agrees (EU).
- ⬜ **Both:** check the events arrive in the dev project (DebugView).
- ⬜ **Me:** before any build with Crashlytics or Analytics goes to TestFlight, update `PrivacyInfo.xcprivacy`, `privacy.html` and the App Store privacy answers together (`AppStoreReadiness.md` §1.1 says to keep them in sync). Don't wait for Phase 10.

### Phase 2: billing and safety limits

- ✅ **You:** `scrumblegame` (production) is on the **Blaze** plan *(already done)*.
- ✅ **You:** switch `scrumblegame-dev` to Blaze too (needed for its Storage bucket, and later for functions). *(15 October)*
- ✅ **You:** set a **budget alert** in Google Cloud Billing: **€10** for `scrumblegame`, **€5** for `scrumblegame-dev`, emails at 50%, 90% and 100% to billing admins. *(15 October)* These are alerts only; they don't stop spending.
- ✅ **You:** set a **monthly spend limit** on the OpenAI dashboard (Settings → Limits, e.g. $20 with an email at $10). *(15 October)* This is an alert too, not a hard stop. The real cap is **prepaid credit with auto recharge off** (Settings → Billing). *(Auto recharge turned off on 15 October.)* When the credit runs out, the app shows "service unavailable" to everyone, which is fine while testing.

### Phase 3: anonymous sign-in

- ⬜ **You:** enable Anonymous sign-in in Firebase Authentication (both projects).
- ⬜ **Me:** sign in silently at launch, next to the existing Firebase setup in `AppDelegate`. No screen, no email.

### Phase 4: Cloud Functions (on dev first)

- ⬜ **You:** put the OpenAI key into Secret Manager with one CLI command (I give you the command; the key never goes into the repo or the chat).
- ⬜ **Me:** `getWords`: job + languages + seen words in, 5 words out; English job name, bank first, OpenAI for the rest; saves typed jobs to `professions`.
- ⬜ **Me:** a meaning-aware bank key, for example "pipe (plumbing)" instead of just "pipe", so the same English name with another meaning in another job doesn't share translations and a picture (`AppFlowIdeas.md` §2). Easiest to decide before the server bank fills up.
- ⬜ **Me:** `getPicture`: one word in, picture link out; generates, converts to WebP, uploads and saves only if missing.
- ⬜ **Me:** `getReviewWords`: struggle words in, translations + pictures out.
- ⬜ **Me:** moderation of typed job text before anything is generated.
- ⬜ **Me:** daily limit (20 words) and per-user rate limits stored per anonymous user on the server.
- ⬜ **Me:** clear error codes that map to the app's existing `GenerationError` cases (busy, offline, limit reached, refused text).
- ⬜ **Both:** test everything on the Mac with the Firebase Emulator Suite (no cost, no risk), then deploy to `scrumblegame-dev`.

### Phase 5: switch the app to the functions

- ⬜ **Me:** `RequestModel` calls the functions instead of OpenAI; prompts, image conversion, uploads and the API key line are removed from the app.
- ⬜ **Me:** remove `FirebaseImageStore` and the writing half of `FirebaseWordStore`.
- ⬜ **Me:** `FreeAllowance` shows the server's count; the Keychain stays as the offline/local check.
- ⬜ **Me:** loading bar still moves per finished picture (2 picture calls at a time, as today).
- ⬜ **Both:** full test on a device: new job, picked job, review, daily limit, airplane mode, server error.

### Phase 6: lock down Firebase

- ⬜ **Me:** Firestore rules: signed-in users can **read** the word library; nobody can write. Per-user limit documents are written only by the server. `professions` can't be read or written by the app.
- ⬜ **Me:** Storage rules: read-only for signed-in users.
- ⬜ **Both:** confirm with the rules test tool that a phone can no longer write.

### Phase 7: App Check

- ⬜ **You:** register the app for App Attest in Firebase App Check; add the simulator debug token.
- ⬜ **Me:** add App Check (App Attest) to the app; debug provider for the simulator.
- ⬜ **You:** turn on **monitoring only** and watch the numbers for a few days.
- ⬜ **You:** switch on **enforcement** for Functions, Firestore and Storage once almost all requests are verified.

### Phase 8: go live on production

- ⬜ **Both:** deploy the functions and rules to `scrumblegame`; move the existing word library if needed (the current words and pictures stay usable).
- ⬜ **You:** create a **new OpenAI key** for the server and **delete the old one**. The old key has been inside app builds, so treat it as exposed.
- ⬜ **Me:** server alerts: an email when OpenAI starts refusing requests or errors suddenly climb (Cloud Logging + Error Reporting).

### Phase 9: the profession list in practice

- ⬜ **Me:** a simple way for you to see the `professions` list sorted by count (Firestore console view to start; a small admin page later if useful).
- ⬜ **Me:** background job `prepareProfession`: when a job is added to the menu, build its 100-word bank (first 10 fast, the rest after), plus 50 more on demand (AppFlowIdeas §1). Run it once for **every profession already in the picker** too (AppFlowIdeas §1, "Pre-generate the listed professions"). This replaces filling the bank by playing.
- ⬜ **Both:** decide the rule for adding a job (for example "typed 10+ times and looks right").

### Phase 10: privacy and App Store updates (before release)

- ⬜ **Me:** `PrivacyInfo.xcprivacy`: add crash data, product interaction (analytics), user ID (anonymous); profession text gets the extra purpose "Analytics" (improving the job list).
- ⬜ **Me:** `privacy.html`: OpenAI now called from our server; anonymous ID; crash reports; analytics with consent; typed jobs stored in English without a user ID; server region `europe-west1`.
- ⬜ **Me:** `WebsiteContent/README.md` privacy table and App Store answers updated.
- ⬜ **You:** update the App Store Connect privacy answers to match. Today they say "not linked to the user"; with an anonymous ID and server-side limits, check again whether that still holds.
- ⬜ **Me:** move the internal docs (`checklist.md`, `AppFlowIdeas.md`, `AppStoreReadiness.md`, this file) out of `LearnScrumble/`. That folder is synced to the app, so they ship inside it and anyone can read them (`AppStoreReadiness.md` §3).
- ⬜ **Me:** update `checklist.md` and `AppStoreReadiness.md` (key off the phone, Firebase lock-down, crash reports and analytics → done).

---

## Costs to expect

| What | Roughly |
|---|---|
| Cloud Functions | Free up to about 2 million calls a month, then cents |
| Firestore / Storage | Free tier covers early use; grows slowly with the word library |
| App Check, Auth (anonymous), Crashlytics, Analytics | Free |
| OpenAI | The real cost, and it drops as the shared bank grows, because known words are never generated again |

## Still open (not part of this plan)

- Consent step for sending the job to OpenAI (App Review 5.1.2). It could share a screen with the analytics consent. The proposed design is in `AppStoreReadiness.md` §1.4 (a sentence and an "I agree" checkbox on the setup screen).
- Paywall with RevenueCat; it can use the same anonymous ID. Sandbox only, with no live products in your own App Store Connect account (checklist §4.3).
- Report button for wrong words or pictures; it would write to a `reports` collection through a function. App Review may expect it for AI content (`AppStoreReadiness.md` §2.1).
- "Delete my data": with the server it also needs to delete the user's limit documents. It's built but commented out today (`SettingsView.swift:68`, `AppManager.swift`).
- Privacy policy, terms and support pages on Firebase Hosting in `scrumblegame` (`AppStoreReadiness.md` §1.3). This needs the Firebase CLI from Phase 0.
- Scheduled Firestore backups for **production** once real users are in the bank (none for dev).
- The OpenAI key still lives in `RequestModel.swift` on your Mac only, not in git. Always add files to a commit by name until Phase 5 removes the key from the app.
