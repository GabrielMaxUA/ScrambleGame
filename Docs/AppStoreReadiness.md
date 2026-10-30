# LearnScrumble: App Store readiness (October 2026)

**Based on:** the code and project settings on 14 October 2026, checked against the App Store Review Guidelines and App Store Connect's upload checks.
**Status:** ✅ = done · ⬜ **to do** = not done yet · ❓ **need discussion** = waiting on a decision

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
- **Plan:** handled when RevenueCat and the paywall are built (`checklist.md` §4.3, `AppFlowIdeas.md` §6). **Must be finished before the first submission.**
- **If the app has to ship before the paywall:** hide everything premium for 1.0 — no "See plans", no lock icons, review and voice either free or hidden, and at the daily limit a plain "Come back tomorrow" message.
- **Done (28 October):** the paywall is real. After **10 free words (once per install)** the app shows "Unlock your profession": a one-time **$9.99 in-app purchase per menu job** (non-consumable, StoreKit 2, `Purchases.swift` / `PaywallView.swift`) with the price in the user's currency, what's included, **Restore purchases** and "Not now". Unlocking gives the job's most-used workplace words (its word list ends when no common items are left, since 30 October), "My words" for that job, and the voice picker. Tested with the local `StoreKit/LearnScrumble.storekit` (Xcode test purchase works since the scheme path fix on 28 October).
- **Still needed before submitting (guideline 3.1.1):** create the **32 non-consumable products** in App Store Connect with exactly the IDs `com.MaxGabriel.LearnScrumble.job.<case name>` (list in the `.storekit` file), each with a display name, description, price ($9.99 tier) and a review screenshot of the paywall; submit them **together with** the app version. Create them in the account the app will be published from (Auxility's, if agreed — `checklist.md` §4.3). Optional: Terms and Privacy links on the paywall (required only for subscriptions).

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
- **Done (28 October):** a **flag on every game picture** → "Report this picture?" → `reportPicture` draws a new picture for that user right away, records the report, and `mailReports` emails the day's reports to support@learnscrumble.com every morning; approve or reject in Firestore `reports` (`functions/README.md` "Reported pictures"). Wrong **words or translations** are still reported by email (support page).

### 2.2 ✅ The OpenAI key inside the app (guideline 2.1 in practice)
- **Done (27 October):** all generation runs in Firebase Cloud Functions; the new key is only in Secret Manager and the old one is deleted. Anonymous sign-in and App Check (monitoring, enforcement later) protect the functions.
- If the key is extracted and abused, OpenAI can block it, and the app shows "We can't prepare new words" during review: an instant rejection, and the same failure for all users later.
- **How:** move generation to Firebase Cloud Functions (`AppFlowIdeas.md` §9, step 2).

### 2.3 ⬜ **to do** Notes for the reviewer (App Store Connect → App Review Information)
New pictures take 10–30 seconds and need the internet, so explain that up front. Suggested text:

> LearnScrumble creates vocabulary for the user's job with AI. Most words come from a prepared word bank, so a round usually loads in a few seconds; a new picture can take up to 30 seconds. An internet connection is needed (except "My words", which works offline). Suggested test: I speak English, profession "Cook", I want to learn Polish. After setup a short "How to play" tutorial runs while the first words load. The first 10 words are free (once per install); after them the app offers a one-time in-app purchase to unlock the chosen profession (US$9.99, non-consumable, no subscription) — please buy it with your sandbox account to test more words, "My words" (Welcome back screen), and the voice picker (Settings). Restore purchases is in Settings and on the purchase screen. Each profession's word list has an end (its most-used workplace words); when every word is played the app says so and offers My words or another profession. New pictures are limited to 100 a day per user. The flag on a picture reports a wrong picture. No account or sign-in is required (the app signs in anonymously in the background).

*(Updated 28 October for the one-time unlocks, 30 October for the word lists and the daily picture limit. Check before submitting that the prepared bank has words for "Cook" and Polish translations.)*

---

## 3. Smaller items and App Store Connect tasks

- ✅ **Launch screen** shortened from 5 to 2 seconds (`RootView`). Apple discourages long forced splash screens.
- ✅ **Sounds follow the silent switch** — the audio session is now `.ambient` (`SoundManager`), still mixed with the user's music. Fixed together with the earlier main-thread audio warnings.
- ✅ **Export compliance:** add `ITSAppUsesNonExemptEncryption = NO` to the target's Info settings (the app only uses standard HTTPS), so App Store Connect stops asking for every build. *(16 October: in `LearnScrumble-Info.plist`, confirmed in the built app's Info.plist. 27 October: Xcode moved it to the build settings, `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO`)*
- ⬜ **to do** **App privacy answers** (App Store Connect → App Privacy): no tracking; data not linked to the user: Other User Content and Other Usage Data (App Functionality), plus Crash Data, Device ID and Product Interaction since 15 October, and User ID since 27 October (see 1.1) — the same as the privacy manifest. See `WebsiteContent/README.md`.
- ⬜ **to do** **Age rating questionnaire:** answer the questions about AI-generated content and user-created content honestly.
- ⬜ **to do** **Store listing:** name, subtitle, description, keywords, category (Education), copyright, and screenshots in the required iPhone sizes (the `WebsiteContent/images/how-to-play/` captures are a starting point, but App Store screenshots need the full device resolution).
- ✅ **Internal notes ship inside the app:** `checklist.md`, `AppFlowIdeas.md` and this file sit in the `LearnScrumble/` folder, which is synced to the app target, so they're copied into the app and anyone can read them from the downloaded app (business plans, prices, feedback). Move them to a folder outside the app target, e.g. `Docs/` at the repository root. *(16 October: moved to `Docs/` at the repository root, so they stay in the repo but never ship in the app; the built app has no `.md` files)*
- ⬜ **to do** **TestFlight round** on a real iPhone before submitting: first launch, tutorial, a full round, the 10 free words → paywall → sandbox purchase → more words, My words (also offline), Restore purchases, reporting a picture, reminder, offline screen, Settings. Also confirm **App Attest** works in the TestFlight build (Debug builds use App Check debug tokens since 28 October).

---

## 4. Already fine

- ✅ Notification permission asked in context (on Start Learning, with the reason shown), and the app works without it.
- ✅ No account, so no account-deletion requirement.
- ✅ iPhone only, portrait, minimum iOS 18.
- ✅ App icon has no transparency.
- ✅ No tracking, no advertising identifier.
- ✅ Restore purchases in Settings and on the paywall (required for non-consumables). *("Manage subscription" was removed on 28 October: there's no subscription)*
- ✅ Every screen localized into the app's languages, including right-to-left. *(29 October: the 28 new texts — paywall, My words, reports, streak — are translated into all 53 languages (AI-made, native review recommended); 22 stale catalog entries removed; 0 untranslated)*
- ✅ Offline and error states with clear recovery (no blank screens or endless spinners).

---

## 5. Order of work

1. ✅ Privacy manifest (1.1)
2. ✅ Consent step on the setup screen (1.4) *(15 October)*
3. ✅ Publish the website and update the app's links (1.3) *(18 October; placeholders left)*
4. ✅ *(app side)* Paywall with RevenueCat, or 1.0 without premium (1.2) *(28 October: one-time unlock per profession with StoreKit 2; the products in App Store Connect are left)*
5. ⬜ ~~Export compliance key~~ *(done 16 October)*, App Store Connect answers, store listing (3)
6. ⬜ Reviewer notes (2.3) and a TestFlight round
7. ✅ Cloud Functions and the Report button (2.1, 2.2) — strongly recommended before launch, needed soon after at the latest *(Cloud Functions done 27 October; picture reports done 28 October)*
