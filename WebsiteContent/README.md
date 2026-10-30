# LearnScrumble website

Static support website for the app: plain HTML, one stylesheet and one small script. No build step, no framework.

**What's left to do for the website:** see `TODO.md` in this folder.

## Pages

| File | What it is | Linked from the app |
|---|---|---|
| `index.html` | Home: what the app does, App Store button | — |
| `how-to-play.html` | The "How to play" tutorial step by step, with real screenshots (`images/how-to-play/`) | (could be linked from Settings → How to play later) |
| `support.html` | Contact + FAQ (reminders, languages, free words, unlocking a profession, My words, wrong pictures, voices, progress, data) | Settings → Contact support (email) |
| `privacy.html` | Privacy Policy — what the app stores on the iPhone and sends to OpenAI, Firebase and Apple | `AppLinks.privacy` (Settings, setup screen, consent sheet) |
| `terms.html` | Terms of Use ("usage regulations") — service, not-safety-training, AI content, free words, profession unlocks | `AppLinks.terms` |

**After changing `css/style.css` or `js/main.js`:** raise the `?v=` number in the `<link>` and `<script>` lines of every page (e.g. `?v=2` → `?v=3`). Browsers keep those two files for a day, and the new number makes them fetch the new version straight away.

Shared: `css/style.css` (dark look matching the app), `js/main.js` (phone menu, footer year, copy-email button, opens a FAQ answer from a `#link`). Everything still works with JavaScript off.

## Before publishing

1. **Fill in every yellow-highlighted placeholder.** They're marked with `class="fill"`; find them all with:
   ```
   grep -n 'class="fill"' *.html
   ```
   Company or developer name, postal address, privacy and support email addresses, effective dates, reply time,
   Firebase project region, transfer safeguards (DPF / SCCs), minimum age, governing law, trial length.
   When everything is filled in, you can delete the `.fill` rule from `css/style.css`.
2. **Have a lawyer review `privacy.html` and `terms.html`.** They describe the app accurately as of 14 October 2026, but they're drafts, not legal advice.
3. **Replace the App Store button** on `index.html` with Apple's official badge and the real App Store link.
4. ✅ **The app's links** point to learnscrumble.com (18 October 2026). They all live in one file, `LearnScrumble/Models/AppLinks.swift` (privacy, terms, support page, support email), used by `SettingsView`, `EntryView` and `ConsentSheet`. If a page address changes, edit only that file.

## Hosting: where the site lives

- **Live at:** https://learnscrumble.com (`www.learnscrumble.com` redirects there). Firebase's own address, https://scrumblegame.web.app, shows the same site.
- **Host:** Firebase Hosting in the production project `scrumblegame`. Set up 18 October 2026.
- **Config:** `firebase.json` and `.firebaserc` in the repository root (next to `README.md`). They publish this folder to `scrumblegame`, skip the `.md` files (this README, `TODO.md`) and hidden files, give clean addresses (`/privacy` instead of `/privacy.html`) and set browser caching.
- **Domain and email:** registered at Namecheap. DNS (Namecheap → Domain List → `learnscrumble.com` → Manage → Advanced DNS) has three host records: A `@` → `199.36.158.100`, TXT `@` → `hosting-site=scrumblegame`, CNAME `www` → `scrumblegame.web.app.`. Mail Settings is **Private Email** (`support@learnscrumble.com`) and must stay as it is: never delete the `v=spf1 …privateemail…` TXT record or change Mail Settings, or email stops working.

**Pushing to git does NOT update the website.** Git keeps the history; the live site only changes when you run the deploy command below.

## Updating the website: step by step

Everything runs on the Mac, in Terminal, from the **repository root** (the folder with `firebase.json`, not this folder).

1. **Edit** the pages in `WebsiteContent/`.
2. **Changed `css/style.css` or `js/main.js`?** Raise the `?v=` number in the `<link>` and `<script>` lines of every page (e.g. `?v=2` → `?v=3`), otherwise phones keep the old file for up to a day.
3. **Look at it locally:** open the page in a browser, or run `python3 -m http.server 8000` in this folder and visit http://localhost:8000.
4. **Go to the repository root:**
   ```
   cd ~/Desktop/ScrambleGame
   ```
5. **Optional: a private test copy first.** This publishes to a temporary address (valid 7 days) without touching the live site; open it on your phone or send it to Konstantin:
   ```
   firebase hosting:channel:deploy preview
   ```
6. **Publish to the live site:**
   ```
   firebase deploy --only hosting
   ```
   Wait for `✔ Deploy complete!`. The site updates within seconds.
7. **Check it** on https://learnscrumble.com. If a phone still shows the old version, close the tab and open the address again.
8. **Commit and push** the changed files (by name, as always), so git matches what's live.

**Undo a bad deploy:** Firebase console → `scrumblegame` → Hosting → Release history → pick the previous version → **Rollback**. That's instant; then fix the files and deploy again.

**If the deploy fails:**
- `command not found: firebase` or an old version: run `node -v` (needs v20 or newer; the Mac's default is Node 22 through nvm) and `firebase --version`. Reinstall with `npm install -g firebase-tools`.
- Asked to log in: `firebase login`, approve in the browser.
- "Not in a Firebase app directory": you're in the wrong folder; `cd ~/Desktop/ScrambleGame` and try again.

**Later, optional:** Firebase can deploy automatically from GitHub (a merge to `main` publishes the site, each Pull Request gets a preview link), limited to changes in `WebsiteContent/`. Worth it once several people edit the site.

## Keep the privacy page in sync with the app

`privacy.html` is based on what the code does today:

| Data | Where it goes |
|---|---|
| Languages, profession, speech speed, voice per language, reminder on/off + time, setup/tutorial flags, OpenAI agreement date, usage-statistics choice | iPhone only (UserDefaults) |
| Answers per word: English name, language, right/wrong counts, last answered; the word itself (job, both words, picture description, picture, picture link) for My words | iPhone only (SwiftData) |
| Free-word counter: words used of the 10 free ones (since 28 Oct 2026; was per day) | iPhone only (Keychain — survives deleting the app) |
| Streak: last day played, days in a row | iPhone only (UserDefaults) |
| Daily reminders | Scheduled locally by iOS, no server |
| Profession (menu job; typed jobs are off since 28 Oct 2026), both languages, already-practised word names, picture descriptions | Our Cloud Functions (`getWords`, `getPicture`, us-central1), which call the OpenAI API. Only after the user ticks "I agree" (setup screen, or a one-time sheet for older installs). The OpenAI key is on the server only (Secret Manager) |
| Crash and error reports: where in the code, error type, the two chosen languages, the last app steps (`Log.info` / `Log.error` messages: steps and counts only; words and the profession are `private:` and never sent), device model, iOS/app version, random installation ID | Firebase Crashlytics, always on |
| Usage events, device model, iOS/app version, approximate country, random app-instance ID (no IDFA) | Google Analytics for Firebase, **only if** "Share usage statistics" is on (off by default; `FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO` in `LearnScrumble-Info.plist`) |
| New words (English name + 2 translations + picture link + English job names), new pictures | Google Firebase (Firestore + Storage), shared library, no user ID. Written only by the Cloud Functions; the app downloads pictures by their link |
| Job counts: English job name (menu name, or GPT's English name for a typed job; "invalid" isn't saved), typed/picked counts, first/last seen, review status | Google Firebase (Firestore `professions`), written by `getWords` when the app sends `countJob` (once per job per install, `ProfessionStore`), no user ID, never the typed text |
| Random anonymous sign-in ID | Firebase Authentication (`AnonymousAuth.swift`), sent with every function call; auto clean-up deletes it 30 days after creation |
| Picture reports: word's English name, job's English name, the picture link seen | `reportPicture` -> OpenAI (word + job, to describe and draw it again) -> the new picture only to the reporter (Storage `reports/`). Firestore `reports/{word}`: word, jobs, counts, the picture seen, the suggested picture + description, status; `reports/{word}/reporters/{code}`: a one-way hash of the anonymous ID, to count people. Daily email to support@learnscrumble.com (`mailReports`). The bank picture changes only when the developer approves |
| Today's date + pictures reported today, per anonymous ID | Firestore `reportUsage/{uid}`, written by `reportPicture`, overwritten daily (max 10 a day) |
| Today's date + new pictures drawn today, per anonymous ID | Firestore `pictureUsage/{uid}`, written by `getPicture`, overwritten daily (max 100 a day, since 29 October 2026) |
| Alerts: OpenAI credits used up; a user over the picture limit (one-way code of the anonymous ID, never the ID) | Firestore `alerts/{kind}-{day}` + an email to support@learnscrumble.com (`mailAlert`), at most one per kind per day |
| A job's word list status (open / complete, word count) | Firestore `jobs/{key}`, no user data (since 30 October 2026) |
| App Check token (App Attest on iPhones, debug token in the simulator) | Firebase App Check, with every Firebase call; no personal data |
| Purchases: one-time profession unlocks (non-consumable, $9.99) | Apple App Store (StoreKit 2, `Purchases.swift`); the app only reads which ones the user owns |

**Update the policy before shipping** any of these (ideas for later): RevenueCat, business access codes, typed jobs coming back, the server enforcing the free words. *(Crashlytics, optional Analytics and the OpenAI consent were added to the policy on 15 October 2026; the Cloud Functions, anonymous sign-in, the daily count on the server and App Check on 27 October 2026; one-time unlocks, My words, the picture Report flag and the end of the time check and typed jobs on 28 October 2026;
Ontario/Canada law, the daily picture count and the alert emails on 29 October 2026.)*

## App Store privacy questions (suggestion)

Apple asks what data the app "collects" (sends off the device and keeps longer than needed to answer the request). Based on the table above, a reasonable starting point — confirm with whoever signs off the release:

- **Tracking:** No.
- **Data linked to the user:** None (no account; Firebase's random IDs, including the anonymous sign-in ID, aren't tied to a person). ⚠️ Confirm at sign-off: the server keeps a daily report count per anonymous ID (`reportUsage/{uid}`), and Apple may see that as "linked". If so, mark User ID and Other Usage Data as linked (still not tracking). (The daily word count `usage/{uid}` was removed on 28 October 2026.)
- **Data not linked to the user** (the same as `LearnScrumble/PrivacyInfo.xcprivacy`):
  - *User Content → Other User Content*: the profession text sent to OpenAI — purposes: App Functionality, and Analytics (its English name is counted to improve the job menu).
  - *Usage Data → Other Usage Data*: the names of words already practised, sent to our server and OpenAI so they aren't repeated, the server's daily report count, and picture reports (word + job) — purpose: App Functionality.
  - *Identifiers → User ID*: the random anonymous Firebase sign-in ID — purpose: App Functionality.
  - *Diagnostics → Crash Data*: Crashlytics crash reports — purpose: App Functionality.
  - *Diagnostics → Other Diagnostic Data*: Crashlytics non-fatal error reports (words couldn't be loaded), with the error type, a short technical description, the last steps, free memory and disk space — purpose: App Functionality.
  - *Identifiers → Device ID*: Firebase's random installation / app-instance ID (not the advertising ID) — purposes: App Functionality, Analytics.
  - *Usage Data → Product Interaction*: Analytics events, only with the user's consent — purpose: Analytics.
- On-device data (settings, progress, Keychain counter) is not "collected" because it never leaves the device.
- Purchases are handled by Apple and aren't declared by the app.

Revisit these answers whenever the table changes (for example, anonymous sign-in or server-side limits may make some data "linked").

## Screenshots

`images/how-to-play/*.jpg` were taken from the app's own tutorial in the iOS Simulator (English UI, learning Polish, iPhone 17), resized to 600 px wide. Retake them when the tutorial or the design changes. *(27 October 2026: `10-lets-go.jpg` edited from "20" to "10 free words"; `how-to-play.html` loads it with `?v=2`. 28 October 2026: the app's note now reads "You get 10 free words to try the app." — retake it.)*
