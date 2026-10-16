# LearnScrumble: moving the AI to the server (plan)

*Written 15 October 2026. Nothing here is built yet. Tick items off as we finish them, the same way as `checklist.md`.*

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

Who does it: **You** = Firebase/Google/OpenAI consoles, card, Apple account. **Me** = code and files. **Both** = testing together.

### Phase 0: preparation

- ✅ **You:** the iOS app (bundle ID) is registered in `scrumblegame` (production) *(already done)*.
- ⬜ **You:** create the Firebase project `scrumblegame-dev` and add the iOS app (same bundle ID) to it; download its `GoogleService-Info.plist`.
- ⬜ **Me:** set up the app to use the dev plist in Debug builds and the production plist in Release builds.
- ⬜ **You:** install the Firebase CLI and log in (I'll give you the exact commands).
- ⬜ **Me:** add a `functions/` folder (TypeScript) and Firebase config files to the repo, outside the app folder.

### Phase 1: crash reports and analytics (small, useful straight away)

- ⬜ **Me:** add FirebaseCrashlytics and FirebaseAnalytics (without the advertising ID parts), plus the dSYM upload build step.
- ⬜ **Me:** turn the `print` lines into proper logs, add crash breadcrumbs ("round finished", "generation failed") and report every `GenerationError` as a non-fatal error.
- ⬜ **Me:** analytics events: `onboarding_completed`, `tutorial_completed`, `tutorial_skipped`, `round_completed`, `daily_limit_reached`, `paywall_shown`, `trial_started`, `review_started`, `reminder_enabled`, `generation_failed` (error type only).
- ⬜ **Me:** analytics consent switch in onboarding and Settings, connected to Firebase's consent settings; off until the user agrees (EU).
- ⬜ **Both:** check the events arrive in the dev project (DebugView).

### Phase 2: billing and safety limits

- ✅ **You:** `scrumblegame` (production) is on the **Blaze** plan *(already done)*.
- ⬜ **You:** switch `scrumblegame-dev` to Blaze too, once it exists (needed to run functions there).
- ⬜ **You:** set a **budget alert** in Google Cloud Billing (for example €10 / €25 / €50 emails).
- ⬜ **You:** set a **monthly spend limit** on the OpenAI dashboard.

### Phase 3: anonymous sign-in

- ⬜ **You:** enable Anonymous sign-in in Firebase Authentication (both projects).
- ⬜ **Me:** sign in silently at launch, next to the existing Firebase setup in `AppDelegate`. No screen, no email.

### Phase 4: Cloud Functions (on dev first)

- ⬜ **You:** put the OpenAI key into Secret Manager with one CLI command (I give you the command; the key never goes into the repo or the chat).
- ⬜ **Me:** `getWords`: job + languages + seen words in, 5 words out; English job name, bank first, OpenAI for the rest; saves typed jobs to `professions`.
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
- ⬜ **Me:** background job `prepareProfession`: when a job is added to the menu, build its 100-word bank (first 10 fast, the rest after), plus 50 more on demand (AppFlowIdeas §1).
- ⬜ **Both:** decide the rule for adding a job (for example "typed 10+ times and looks right").

### Phase 10: privacy and App Store updates (before release)

- ⬜ **Me:** `PrivacyInfo.xcprivacy`: add crash data, product interaction (analytics), user ID (anonymous); profession text gets the extra purpose "Analytics" (improving the job list).
- ⬜ **Me:** `privacy.html`: OpenAI now called from our server; anonymous ID; crash reports; analytics with consent; typed jobs stored in English without a user ID; server region `europe-west1`.
- ⬜ **Me:** `WebsiteContent/README.md` privacy table and App Store answers updated.
- ⬜ **You:** update the App Store Connect privacy answers to match.
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

- Consent step for sending the job to OpenAI (App Review 5.1.2). It could share a screen with the analytics consent.
- Paywall with RevenueCat; it can use the same anonymous ID.
- Report button for wrong words or pictures; it would write to a `reports` collection through a function.
- "Delete my data": with the server it also needs to delete the user's limit documents.
