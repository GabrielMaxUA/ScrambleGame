# LearnScrumble: App Store readiness (October 2026)

> **1 November 2026:** `remaining.md` (launch tasks) moved into section 6 below, and `checklist.md` (October feedback
> and discussion questions, no longer current) was removed; both are in git history. This is now the one to-do file.

**Based on:** the code and project settings on 14 October 2026, checked against the App Store Review Guidelines and App Store Connect's upload checks.
**Status:** ✅ = done · ⬜ **to do** = not done yet · ⏳ = submitted, waiting for Apple · ❓ **need discussion** = waiting on a decision

> **30 October 2026:** `AppFlowIdeas.md` and `ServerMigrationPlan.md` were removed (no longer needed). Mentions of them below are history; the files are in git history.

---

## 1. Blockers: the app won't be accepted without these

### 1.1 ✅ Privacy manifest (upload check, error ITMS-91053)
- **Problem:** the app uses `UserDefaults` / `@AppStorage` (settings, reminder, tutorial flags). Apple requires a declared reason for this API in `PrivacyInfo.xcprivacy`; without it App Store Connect refuses the build.
- **Done (14 October):** `LearnScrumble/PrivacyInfo.xcprivacy`:
  - no tracking, no tracking domains;
  - UserDefaults, reason **CA92.1** (only this app reads and writes it);
  - collected, not linked to the user, for App Functionality: **Other User Content** (the job sent to OpenAI) and **Other Usage Data** (names of practised words sent to OpenAI).
- **Updated 27 October** for the Cloud Functions and anonymous sign-in: also **User ID** (the random anonymous Firebase ID, App Functionality, not linked — confirm at sign-off), and the job and practised words now go to our server, which passes them to OpenAI.
- **Updated 15 October** for Crashlytics and Analytics: also **Crash Data** (App Functionality), **Device ID** (Firebase's random IDs, not the advertising ID; App Functionality + Analytics) and **Product Interaction** (Analytics, only with consent). All not linked, no tracking. The App Store Connect privacy answers still need the same update (see `WebsiteContent/README.md`).
- Firebase 12.19 and SDWebImage include their own manifests.
- **Keep in sync** with `WebsiteContent/privacy.html` and the App Store privacy answers (3.2).

### 1.2 ✅ *(app side)* Premium buttons that do nothing (guidelines 2.1, 3.1.1)
- **Problem:** every "See plans" button only prints `💳 paywall — not built yet`, and `AppManager.hasAccess` is always `false`. After 10 words (20 until 27 October) the reviewer sees "Today's free words are done" with a "See plans" button that does nothing; review of mistakes and the voice picker are locked behind a subscription that can't be bought.
- **Plan:** handled when RevenueCat and the paywall are built (the October checklist, now removed). **Must be finished before the first submission.**
- **If the app has to ship before the paywall:** hide everything premium for 1.0 — no "See plans", no lock icons, review and voice either free or hidden, and at the daily limit a plain "Come back tomorrow" message.
- **Done (28 October):** the paywall is real. After **10 free words (once per install)** the app shows "Unlock your profession": a one-time **$9.99 in-app purchase per menu job** (non-consumable, StoreKit 2, `Purchases.swift` / `PaywallView.swift`) with the price in the user's currency, what's included, **Restore purchases** and "Not now". Unlocking gives the job's most-used workplace words (its word list ends when no common items are left, since 30 October), "My words" for that job, and the voice picker. Tested with the local `StoreKit/LearnScrumble.storekit` (Xcode test purchase works since the scheme path fix on 28 October).
- **Still needed before submitting (guideline 3.1.1):** create the **32 non-consumable products** in App Store Connect with exactly the IDs `com.MaxGabriel.LearnScrumble.job.<case name>` (list in the `.storekit` file), each with a display name, description, price ($9.99 tier) and a review screenshot of the paywall; submit them **together with** the app version. Create them in the account the app will be published from (decided: Max's personal account, see §6). Optional: Terms and Privacy links on the paywall (required only for subscriptions).

### 1.3 ✅ *(partly)* Working privacy policy, terms and support links (guideline 5.1.1(i))
- **Done (18 October):** the pages are live at **https://learnscrumble.com** (`/privacy`, `/terms`, `/support`) on Firebase Hosting, and the app's links come from `AppLinks.swift`; support email support@learnscrumble.com. **Left:** the yellow placeholders and a legal check (`WebsiteContent/TODO.md`), and entering the URLs in App Store Connect. The original plan below is kept for reference.
- **Problem:** the pages exist in `WebsiteContent/`, but they aren't online yet, so the app still points to placeholders:
  - `Views/EntryView.swift` → `privacyURL` = `https://your-site.com/privacy`
  - `Views/SettingsView.swift` → `privacyURL`, `termsURL` = `your-site.com`, `supportEmail` = `support@example.com`
- **How:**
  1. Fill in the yellow placeholders in `WebsiteContent/` (company name, address, emails, dates…) and get the privacy and terms pages checked.
  2. Publish with Firebase Hosting (same Firebase project, `scrumblegame`): `firebase init hosting` → public directory `WebsiteContent` → `firebase deploy --only hosting`. Free address: **https://scrumblegame.web.app** (a custom domain can be added later).
  3. Point the app at the live pages:
     - privacy → `https://scrumblegame.web.app/privacy.html`
     - terms → `https://scrumblegame.web.app/terms.html`
     - support → the real support email
  4. App Store Connect: **Privacy Policy URL** = the privacy page, **Support URL** = `https://scrumblegame.web.app/support.html`.

### 1.4 ✅ Ask before sending the job to OpenAI (guideline 5.1.2(i))
- **Done (15 October):** the proposal below is built.
  - Setup screen: a **"Your data"** card with the sentence and an **"I agree"** checkbox; Start Learning stays disabled until it's ticked. The date is saved (`AIConsent.key`), so it's asked once.
  - Existing users: `ConsentSheet` appears once, before their next game or review. "Not now" keeps them on the welcome screen.
  - Settings → Legal and support repeats the sentence.
  - The same card has the optional **"Share usage statistics"** checkbox (Analytics, off by default), also a toggle in Settings.
  - All new texts are translated into the app's 54 languages (AI-made, like the rest).
  - `privacy.html` and `support.html` explain both.
- **Problem:** the job the user picks or types goes to OpenAI. Apple's guideline requires a clear disclosure when personal data is shared with third parties, **including third-party AI**, and explicit permission first. Today there is only a small "generated by AI" line.
- **How (proposal):**
  1. **Setup screen:** above Start Learning, one clear sentence — "To create your words and pictures, your job and your two languages are sent to OpenAI." — with a link to the Privacy Policy, and an **"I agree"** checkbox. Start Learning stays disabled until it's ticked.
  2. **Save the answer** (agreed + date), so it's asked once.
  3. **Existing users** (set up before this): a one-time sheet with the same sentence before the next game starts.
  4. **Settings → Legal and support:** a line explaining what goes to OpenAI.
  5. **Without agreement** the app can't create words, so it explains that and stays on the setup screen. That's acceptable, because the AI is the app's core function and it's clearly explained.
  6. All texts translated like the rest.

---

## 2. Risks: may cause a rejection

### 2.1 ✅ A way to report AI content (guideline 1.2)
- Words and pictures made from what users type are shared with all users. A reviewer may treat this as user-generated content, which needs a way to report problems.
- **How:** the planned Report button (`AppFlowIdeas.md` §2). Until then, the support email in Settings plus the support page's "A word, translation or picture looks wrong" answer.
- **Done (28 October):** a **flag on every game picture** → "Report this picture?" → `reportPicture` draws a new picture for that user right away, records the report, and `mailReports` emails the day's reports to support@learnscrumble.com every morning; approve or reject in Firestore `reports` (`functions/README.md` "Reported pictures"). **Since 1 November 2026** wrong **words or translations** are reported in the app too: "Wrong word?" after an answer, or the flag in My words → "Wrong word or translation" → the user types the correct version → `reportWord` records it with OpenAI's opinion → in the same morning email → approve (writes `fix` into the bank) or reject in Firestore `wordReports` (`functions/README.md`).

### 2.2 ✅ The OpenAI key inside the app (guideline 2.1 in practice)
- **Done (27 October):** all generation runs in Firebase Cloud Functions; the new key is only in Secret Manager and the old one is deleted. Anonymous sign-in and App Check (monitoring, enforcement later) protect the functions.
- If the key is extracted and abused, OpenAI can block it, and the app shows "We can't prepare new words" during review: an instant rejection, and the same failure for all users later.
- **How:** move generation to Firebase Cloud Functions (`AppFlowIdeas.md` §9, step 2).

### 2.3 ⬜ **to do** Notes for the reviewer (App Store Connect → App Review Information)
- ✅ *(1 November 2026)* **Text ready:** the README, **App Store review guide → "Notes for the reviewer"** (about 3,000
  of the 4,000 characters). It covers the setup and suggested test (English, Cook, Polish), the tutorial with its demo
  of both tests, the one-time unlocks and the sandbox purchase, the start screen's three cards, the pronunciation test
  (permissions, test on a device), the listening test (appears after 4 played words, no purchase, no microphone), Test
  all, reporting wrong pictures and wrong words, the end of a word list and the daily picture limit.
- ⬜ Paste it into App Store Connect → the version → App Review Information → Notes. Check first that the bank has
  "Cook" words with Polish translations, and that the 32 products are attached to the version.
- Older versions of the notes (28 and 30 October) are in git history.

---

## 3. Smaller items and App Store Connect tasks

- ✅ **Launch screen** shortened from 5 to 2 seconds (`RootView`). Apple discourages long forced splash screens.
- ✅ **Sounds follow the silent switch** — the audio session is now `.ambient` (`SoundManager`), still mixed with the user's music. Fixed together with the earlier main-thread audio warnings.
- ✅ **Export compliance:** add `ITSAppUsesNonExemptEncryption = NO` to the target's Info settings (the app only uses standard HTTPS), so App Store Connect stops asking for every build. *(16 October: in `LearnScrumble-Info.plist`, confirmed in the built app's Info.plist. 27 October: Xcode moved it to the build settings, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`)*
- ⬜ **to do** **App privacy answers** (App Store Connect → App Privacy): no tracking; data not linked to the user: Other User Content and Other Usage Data (App Functionality), plus Crash Data, Device ID and Product Interaction since 15 October, and User ID since 27 October (see 1.1) — the same as the privacy manifest. See `WebsiteContent/README.md`.
  *(1 November 2026: no change needed for the new features — word reports, the correction the user types, fall under
  Other User Content, already declared; listening results stay on the phone.)*
- ⬜ **to do** **Age rating questionnaire:** answer the questions about AI-generated content and user-created content honestly.
  *(Word reports: what a user types goes only to us for checking; other users only ever see a correction after a person
  approves it, so there's no unmoderated user content in the app.)*
- ⬜ **to do** **Store listing:** name, subtitle, description, keywords, category (Education), copyright, and screenshots in the required iPhone sizes (the `WebsiteContent/images/how-to-play/` captures are a starting point, but App Store screenshots need the full device resolution).
- ✅ **Internal notes ship inside the app:** `checklist.md`, `AppFlowIdeas.md` and this file sit in the `LearnScrumble/` folder, which is synced to the app target, so they're copied into the app and anyone can read them from the downloaded app (business plans, prices, feedback). Move them to a folder outside the app target, e.g. `Docs/` at the repository root. *(16 October: moved to `Docs/` at the repository root, so they stay in the repo but never ship in the app; the built app has no `.md` files)*
- ⬜ **to do** **TestFlight round** on a real iPhone before submitting: first launch, tutorial, a full round, the 10 free words → paywall → sandbox purchase → more words, My words (also offline), Restore purchases, reporting a picture, reminder, offline screen, Settings. Also confirm **App Attest** works in the TestFlight build (Debug builds use App Check debug tokens since 28 October).

---

## 4. Already fine

- ✅ Notification permission asked in context (on Start Learning, with the reason shown), and the app works without it.
- ✅ *(1 November 2026)* Microphone and speech recognition asked in context (first "Tap to speak" in the pronunciation test), with purpose texts in 53 languages + English (`InfoPlist.xcstrings`); denied → a note with Open Settings, and the rest of the app works without them (guideline 5.1.1).
- ✅ No account, so no account-deletion requirement.
- ✅ iPhone only, portrait, minimum iOS 18.
- ✅ App icon has no transparency.
- ✅ No tracking, no advertising identifier.
- ✅ Restore purchases in Settings and on the paywall (required for non-consumables). *("Manage subscription" was removed on 28 October: there's no subscription)*
- ✅ Every screen localized into the app's languages, including right-to-left. *(29 October: the 28 new texts — paywall, My words, reports, streak — are translated into all 53 languages (AI-made, native review recommended); 22 stale catalog entries removed; 0 untranslated. 1 November: the listening test, Test all, the tutorial's test pages
  and word reports — all new texts in 53 languages, 0 untranslated)*
- ✅ Offline and error states with clear recovery (no blank screens or endless spinners).

---

## 5. Order of work

1. ✅ Privacy manifest (1.1)
2. ✅ Consent step on the setup screen (1.4) *(15 October)*
3. ✅ Publish the website and update the app's links (1.3) *(18 October; placeholders left)*
4. ✅ *(app side)* Paywall with RevenueCat, or 1.0 without premium (1.2) *(28 October: one-time unlock per profession with StoreKit 2; the products in App Store Connect are left)*
5. ⬜ ~~Export compliance key~~ *(done 16 October)*, App Store Connect answers, store listing (3)
6. ⬜ Reviewer notes (2.3: text ready, paste it) and a TestFlight round with a new build (the listening test, Test all
   and word reports are in no uploaded build yet)
7. ✅ Cloud Functions and the Report button (2.1, 2.2) — strongly recommended before launch, needed soon after at the latest *(Cloud Functions done 27 October; picture reports done 28 October; word and translation reports done 1 November)*

## 6. Launch tasks: account, products, server, website, testing, submit

The app is published from **Max's personal developer account** (individual, team `7XZJ4BCPR6`). Website details:
`WebsiteContent/TODO.md`; release steps: the README section "Release: App Store Connect and TestFlight".

### 6.1 Account: Paid Apps Agreement (App Store Connect → Business)

Nothing can be bought, not even in TestFlight, until this agreement is **Active**.

- ✅ Paid Apps Agreement signed (29 October).
- ✅ *(1 November 2026)* Bank account (RBC, CAD) entered. ⏳ Waiting for Apple to verify it.
- ✅ *(1 November 2026)* W-8BEN (individual, Canada, SIN, treaty benefits) submitted. ⏳ Waiting for Apple.
- ✅ *(1 November 2026)* **CRA business registration** active: Max Gabriel, sole proprietor, business name **PawIT**.
  ✅ Ontario Business Registry: business name PAWIT registered (sole proprietorship, 1 November 2026; renew in 5 years).
  ⏳ The GST/HST account (`RT0001`) on the CRA Business Number: waiting for confirmation; the OBR profile shows no Business
  Number linked yet, which is fine for Apple's form (it asks for the CRA number).
- ✅ *(1 November 2026)* GST/HST Form 506 in App Store Connect: CRA Business Number + RT 0001 entered. ⏳ Waiting for
  Apple to accept it (Business page → Tax Forms).
- ✅ *(1 November 2026)* EU trader status (Digital Services Act) answered. ⏳ Waiting for Apple.
- ⬜ **App Store Small Business Program** — 15% commission instead of 30% (on everything up to 1 million USD of
  proceeds a year). How to apply, about 5 minutes:
  1. Open https://developer.apple.com/app-store/small-business-program/enroll/ and sign in with the **Account Holder**
     Apple ID (Max's — the account that publishes the app).
  2. Apple checks that the **Paid Apps Agreement** is accepted (it is, since 29 October). If the page says it isn't,
     accept the latest version in App Store Connect → Business first.
  3. **Associated Developer Accounts:** answer **0** — no other developer account owns or controls this one, or is
     owned or controlled by it.
  4. Confirm the program terms and submit.
  5. Apple emails the result (usually within a few days). The 15% applies **15 days after the end of the Apple fiscal
     month** in which the enrolment is approved, so apply before the first sales.
  6. When approved: tick this item off. Nothing else to do; it renews automatically each year while proceeds stay
     under 1 million USD.

### 6.2 The 32 products (App Store Connect → the app → Monetization → In-App Purchases)

For each: **Type** Non-Consumable · **Price** $9.99 (USD base, other countries automatic) · **Availability** all
countries · **Review screenshot**: the paywall (the same screenshot can be used for all 32) · **Review note**: "Unlocks
the most-used workplace words of this profession, with pictures, and My words. Bought on the Unlock screen after the 10 free words."

Apple's limits: display name 30 characters, description 45. Two names are shortened for the store (the app still shows
its own full name, so nothing changes in the app). The Product ID must be **exactly** as below: it can't be changed or
reused after it's created.

| # | ✓ | Product ID | Reference name | Display name | Description |
|---|---|---|---|---|---|
| 1 | ✅ | `com.MaxGabriel.LearnScrumble.job.warehouseWorker` | Job: Warehouse worker | Warehouse worker | Most-used work words, pictures and My words |
| 2 | ✅ | `com.MaxGabriel.LearnScrumble.job.forkliftOperator` | Job: Forklift operator | Forklift operator | Most-used work words, pictures and My words |
| 3 | ✅ | `com.MaxGabriel.LearnScrumble.job.truckDriver` | Job: Truck driver | Truck driver | Most-used work words, pictures and My words |
| 4 | ✅ | `com.MaxGabriel.LearnScrumble.job.deliveryDriver` | Job: Delivery driver | Delivery driver | Most-used work words, pictures and My words |
| 5 | ✅ | `com.MaxGabriel.LearnScrumble.job.constructionWorker` | Job: Construction worker | Construction worker | Most-used work words, pictures and My words |
| 6 | ✅ | `com.MaxGabriel.LearnScrumble.job.carpenter` | Job: Carpenter | Carpenter | Most-used work words, pictures and My words |
| 7 | ✅ | `com.MaxGabriel.LearnScrumble.job.electrician` | Job: Electrician | Electrician | Most-used work words, pictures and My words |
| 8 | ✅ | `com.MaxGabriel.LearnScrumble.job.plumber` | Job: Plumber | Plumber | Most-used work words, pictures and My words |
| 9 | ✅ | `com.MaxGabriel.LearnScrumble.job.painter` | Job: Painter | Painter | Most-used work words, pictures and My words |
| 10 | ✅ | `com.MaxGabriel.LearnScrumble.job.bricklayerConcrete` | Job: Bricklayer & concrete worker | Bricklayer & concrete worker | Most-used work words, pictures and My words |
| 11 | ✅ | `com.MaxGabriel.LearnScrumble.job.finishingWorker` | Job: Finishing worker (tiles, drywall, plaster) | **Finishing worker** | Most-used work words, pictures and My words |
| 12 | ✅ | `com.MaxGabriel.LearnScrumble.job.metalworkerWelder` | Job: Metalworker & welder | Metalworker & welder | Most-used work words, pictures and My words |
| 13 | ✅ | `com.MaxGabriel.LearnScrumble.job.handyman` | Job: Handyman & maintenance worker | Handyman & maintenance worker | Most-used work words, pictures and My words |
| 14 | ✅ | `com.MaxGabriel.LearnScrumble.job.roofer` | Job: Roofer | Roofer | Most-used work words, pictures and My words |
| 15 | ✅ | `com.MaxGabriel.LearnScrumble.job.autoMechanic` | Job: Auto mechanic | Auto mechanic | Most-used work words, pictures and My words |
| 16 | ✅ | `com.MaxGabriel.LearnScrumble.job.factoryWorker` | Job: Factory worker | Factory worker | Most-used work words, pictures and My words |
| 17 | ✅ | `com.MaxGabriel.LearnScrumble.job.machineOperator` | Job: Machine operator | Machine operator | Most-used work words, pictures and My words |
| 18 | ✅ | `com.MaxGabriel.LearnScrumble.job.cncOperator` | Job: CNC operator & machine setter | CNC operator & machine setter | Most-used work words, pictures and My words |
| 19 | ✅ | `com.MaxGabriel.LearnScrumble.job.foodProductionWorker` | Job: Food production worker | Food production worker | Most-used work words, pictures and My words |
| 20 | ✅ | `com.MaxGabriel.LearnScrumble.job.baker` | Job: Baker | Baker | Most-used work words, pictures and My words |
| 21 | ✅ | `com.MaxGabriel.LearnScrumble.job.sewingMachineOperator` | Job: Sewing machine operator & tailor | **Sewing operator & tailor** | Most-used work words, pictures and My words |
| 22 | ✅ | `com.MaxGabriel.LearnScrumble.job.cook` | Job: Cook | Cook | Most-used work words, pictures and My words |
| 23 | ✅ | `com.MaxGabriel.LearnScrumble.job.kitchenAssistant` | Job: Kitchen assistant | Kitchen assistant | Most-used work words, pictures and My words |
| 24 | ✅ | `com.MaxGabriel.LearnScrumble.job.waiter` | Job: Waiter | Waiter | Most-used work words, pictures and My words |
| 25 | ✅ | `com.MaxGabriel.LearnScrumble.job.bartender` | Job: Bartender & barista | Bartender & barista | Most-used work words, pictures and My words |
| 26 | ✅ | `com.MaxGabriel.LearnScrumble.job.hotelHousekeeper` | Job: Hotel housekeeper | Hotel housekeeper | Most-used work words, pictures and My words |
| 27 | ✅ | `com.MaxGabriel.LearnScrumble.job.cleaner` | Job: Cleaner | Cleaner | Most-used work words, pictures and My words |
| 28 | ✅ | `com.MaxGabriel.LearnScrumble.job.caregiver` | Job: Caregiver | Caregiver | Most-used work words, pictures and My words |
| 29 | ✅ | `com.MaxGabriel.LearnScrumble.job.hairdresser` | Job: Hairdresser | Hairdresser | Most-used work words, pictures and My words |
| 30 | ✅ | `com.MaxGabriel.LearnScrumble.job.shopAssistant` | Job: Shop assistant | Shop assistant | Most-used work words, pictures and My words |
| 31 | ✅ | `com.MaxGabriel.LearnScrumble.job.farmWorker` | Job: Farm worker | Farm worker | Most-used work words, pictures and My words |
| 32 | ✅ | `com.MaxGabriel.LearnScrumble.job.gardener` | Job: Gardener | Gardener | Most-used work words, pictures and My words |

- ⬜ After creating them: each shows "Ready to Submit". They're submitted **with the app version** (version page →
  In-App Purchases → add all 32).
- Optional later: translated display names (App Store Connect → each product → localizations).

### 6.3 Server and security

- ✅ Firestore `usage` collection deleted (29 October). `reportUsage` stays.
- ✅ `getPicture` link repair is deployed: deployed 28 October 15:40 UTC, after the fix (28 October 02:46 UTC), and
  the logs show "repaired a stale picture link".
- ✅ **App Attest in the TestFlight build:** build 2 from TestFlight on the iPhone Air (29 October, 23:27 UTC): every
  call App Check **VALID**.
- ✅ **App Check enforcement:** `enforceAppCheck: true` on `getWords`, `getPicture`, `reportPicture` and
  `getReviewWords`, deployed 29 October 23:37 UTC. Xcode runs (simulator or phone) need their debug token registered
  in the Firebase console (README "first setup"). Storage and Authentication stay on Monitoring in the console
  (pictures load through plain links; enforcing Storage would break them).
- ✅ **OpenAI credits:** ran out 29 October (after the prepare run); credits added and auto recharge on. Since
  23:37 UTC no credits = "We can't prepare new words right now" in the app and a paused prepare queue (not "busy").
  The failed prepare jobs were restarted.
- ✅ *(code, 29 October)* **Alert emails** to support@learnscrumble.com right away, at most one per kind per day
  (`alerts.ts`, Firestore `alerts`): OpenAI credits used up; a user reached the daily picture cap (possible misuse).
- ✅ *(code, 29 October)* **Daily cap: 100 new pictures per user** (`PICTURES_PER_DAY`, Firestore `pictureUsage`);
  bank pictures don't count. Over it: bank words only, or "We couldn't find new words… try again later". Told to users
  in the terms (§5 "Fair use"), privacy (§3) and the support FAQ.
- ✅ Deployed 29 October 23:55 UTC (with the new function `mailAlert`).
- ✅ *(code, 30 October)* **Profession word lists end:** GPT's "exhausted" + a quality check; `jobs/{key}` becomes
  complete (or at 500 words); the app shows "🎉 You've played every word for this profession" and a separate
  daily-limit message; the paywall says "The most-used workplace words for this profession" with small print on the
  vocabulary size and 100 new pictures a day; the setup screen shows "Up to 100 new pictures a day." and a Terms link;
  the website and terms say the same. ✅ Functions deployed (dev and prod identical since 1 November); ⬜ a new
  TestFlight build with the app part.
- ✅ *(30 October)* **App Store Connect:** the product **descriptions** said "Unlimited words, pictures and My words". Change every
  product already created to "Most-used work words, pictures and My words" (table below), and the review note.
- ⏸ **Later (decided 29 October): server checks who owns a job** (today only the phone checks). Not for 1.0:
  App Check and the picture cap keep the risk small. Options:
  - **Launch without it** (recommended for 1.0): App Check already blocks scripts and fake apps; only a hacked app on
    a jailbroken phone could skip the paywall, and most words come from the bank, so the cost is small.
  - **Later:** the app sends the App Store's signed purchase (`jwsRepresentation`) to a new function; the server checks
    it with Apple's `@apple/app-store-server-library`, remembers which jobs the user owns, and `getWords` refuses
    locked jobs after the 10 free words. About a day of work plus testing.

### 6.4 Website and legal (`WebsiteContent/TODO.md`, `LegalReview.md`)

- ✅ Privacy, terms, support and home pages updated for Ontario/Canada law (29 October; live since 1 November).
- ⬜ Everything open in `LegalReview.md`: privacy officer, breach record, Québec assessment, French pages, the app's
  consent and paywall wording, a lawyer's read. *(The business name is decided: PawIT, 1 November.)*

- ✅ *(1 November)* Name on every page: "Max Gabriel, operating as PawIT"; privacy officer Max Gabriel.
- ✅ *(1 November)* Pronunciation test on the website: privacy (Apple speech recognition, microphone,
  results on the phone), terms, support FAQ, home and how-to-play — deployed. ✅ The start screen screenshot was replaced
  (`images/app/start-screen.jpg`, 1 November).
- ⬜ Fill the remaining yellow placeholders: postal address, effective dates,
  minimum age (16 suggested), governing law (Ontario, Canada). Then deploy: `firebase deploy --only hosting`.
- ✅ `www.learnscrumble.com` redirects to learnscrumble.com (README "Hosting"). ⬜ Test every page once more before submitting.
- ✅ *(1 November 2026)* Firebase data processing terms and OpenAI Data Processing Addendum in place.
- ⬜ Legal review of `privacy.html` and `terms.html` (recommended).
- ⬜ **Privacy policy gaps found in the 2 November data-flow audit** (EN + FR, then `firebase deploy --only hosting`):
  1. **Server logs:** Cloud Logging keeps each function request (time, IP address, app version) and our `logger` lines
     (word, job key, language codes, the one-way user code at the picture limit) for 30 days. Add to §3 after "Google
     receives your IP address…": "Google Cloud keeps a technical log of each request to our server — the time, the IP
     address, the app version and short notes such as the word, job and language codes involved — for 30 days, so we
     can find and fix problems." Add to §6: "Server logs: 30 days, then deleted automatically by Google Cloud."
     Check the `_Default` bucket says 30 days: https://console.cloud.google.com/logs/storage?project=scrumblegame
     (`gcloud auth login` first if using the CLI).
  2. **§6 daily counts:** says "pictures reported and new pictures drawn"; word reports count too → "pictures and
     words reported, and new pictures drawn".
  3. **Daily count documents are never deleted:** `reportUsage/{uid}` and `pictureUsage/{uid}` stay after the
     anonymous ID is gone. Either add a Firestore TTL policy (field `updated`, e.g. delete after 2 days) or say in §6
     that the last day's count stays.
  4. **Anonymous ID "deleted after 30 days":** true only if Authentication's automatic clean-up of anonymous
     accounts is on (needs the Identity Platform upgrade). Check Firebase console → Authentication → Settings; if
     it's off, turn it on or change the policy (§3 and §6).

### 6.5 App Store Connect: the app page

- ✅ *(2 November 2026)* App Privacy answers published (9 types; User ID and Other Usage Data linked; Privacy
  Policy URL set). The list is in `WebsiteContent/README.md`, the same as `PrivacyInfo.xcprivacy`.
- ✅ *(1 November 2026)* Age rating questionnaire.
- ✅ *(1 November 2026)* Store listing: subtitle, description, keywords, category Education, copyright "2026 Max Gabriel".
- ⬜ Screenshots: 6.9" iPhone (required).
- ⬜ **Pricing and Availability → turn off "Make this app available on Mac" (Apple silicon) and Apple Vision Pro.**
  App Check uses App Attest, which doesn't work there: every server call would fail, so the app couldn't load words.
- ✅ URLs: Privacy `https://learnscrumble.com/privacy` (2 November), Support `https://learnscrumble.com/support`,
  Marketing `https://learnscrumble.com`.
- ⬜ Notes for the reviewer: the text is ready in the README, **App Store review guide** (revised 2 November: the
  free words are kept across reinstalls, so on a reused review device setup leads to the start screen with "Unlock"); the full
  app flow for any reviewer question is there too. Paste it when the review build is picked.
- ✅ *(2 November 2026)* Audio Data not declared: Apple's speech recognition is Apple's data ("You are not responsible
  for disclosing data collected by Apple").

### 6.6 Testing

- ⬜ **iPad once** (the app is iPhone-only, but App Review often runs it on an iPad in compatibility mode): setup,
  a round, the purchase screen, both tests and Settings must work and fit. Install the TestFlight build on any iPad.
- ⬜ **Reinstall with the free words used up** (what a reused review device sees): delete the app, install again, do the
  setup. Expected: the start screen with "Unlock" on the card. Check the tutorial doesn't get stuck (it normally runs
  over the loading game, which doesn't load here) and that Unlock → purchase → "Unlocked!" → Let's go! works.
- ✅ *(1 November, fixed)* **The tutorial still taught the gear in the game** ("The gear opens Settings… Tap it.", `OnboardingView` /
  `OnboardingService`), but since 30 October the game shows a back arrow there and the gear is on the start screen.
  Now the tutorial shows the back arrow: "This arrow takes you back to the start screen. Settings are there, behind
  the gear." (53 languages). ⬜ Retake `WebsiteContent/images/how-to-play/08-settings.jpg`.
- ⬜ **Pronunciation test on a real iPhone** (the simulator can't recognise speech): permissions, a right word, three
  misses, Again / Next word, the counts and rings, a language without speech recognition — and **Test all** (the next
  word comes by itself after the result; no Again).
- ✅ *(1 November 2026)* **Listening test** (cabinet section for professions with 4+ words with pictures, 4 pictures,
  first tap counts, Test all with summary) and the two **tutorial pages** (pronunciation demo, listening demo) —
  checked in the simulator. ⬜ Check on a real iPhone with sound and haptics.
- ✅ *(1 November 2026)* **Wrong word or translation reports** (app + `reportWord` / `reviewWordReport`, dev and prod,
  morning email "Words" section) — a test report was sent, emailed, rejected; an approval ("wine glass" uk-UA →
  «келих для вина») worked. ⬜ See the "Wrong word?" button on the game's right/wrong screen on a device.
- ⬜ **Lawyer review:** `privacy.html` now covers word reports (typed corrections and notes) and listening results;
  consider a line in `terms.html` that corrections users send may be used in the shared word library.

- ⬜ Update to Xcode 27.1 and check the app on the **iPhone Duo** simulator (all poses).
- ⬜ TestFlight round on a real iPhone, once section 1 is Active: free words → paywall → sandbox purchase → more
  words, My words (also offline), Restore purchases, report a picture, reminder, offline screen, Settings.

### 6.7 Submit

- ⬜ A **normal** Product → Archive (not the tester script) with build 3 → upload → pick it on the version page.
- ⬜ Add the 32 products to the version → Submit for Review.

### 6.8 Not needed for 1.0 (decided 29 October)

- **"Delete my data" in Settings:** Apple requires in-app deletion only when the app has accounts. LearnScrumble has
  none: progress lives on the phone (deleting the app removes it) and the anonymous ID is cleaned up by Firebase after
  30 days. Deletion requests go to support@learnscrumble.com. The code stays commented out for later.
- **Terms and Privacy links on the paywall:** Apple requires them only for subscriptions. The unlocks are one-time
  purchases, and the links are already in Settings and on the website.
- Weekly recap, a native-speaker check of the translations, "Not listed?" typed jobs: after launch.
