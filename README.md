# LearnScrumble — developer notes

iOS app (SwiftUI, iOS 18+) that teaches the words people use at work, with words and pictures made by AI.
Plans and status live in `Docs/`: `AppStoreReadiness.md` (everything left before the App Store, the one to-do file),
`AppStoreListing.md` (the store page texts to paste),
`LegalReview.md`, and the privacy records `PrivacyImpactAssessment.md` and `BreachLog.md`.
The full app flow and the notes for App Review are in **App Store review guide** below.
The website is in `WebsiteContent/` (its own README).

## First setup on a new Mac

The Firebase plists are **not in git** and must be added by hand, or the build fails:

1. **Firebase plists**, both named `GoogleService-Info.plist` (ignored by `.gitignore`):
   ```
   FirebaseConfig/Dev/GoogleService-Info.plist    ← project scrumblegame-dev
   FirebaseConfig/Prod/GoogleService-Info.plist   ← project scrumblegame
   ```
   Copy them from a backup, or download them again: Firebase console → project → ⚙️ Project settings → your iOS app.
2. **The OpenAI key is not needed in the app any more** (since 27 October 2026). It lives only in Google Secret Manager
   (`OPENAI_API_KEY`, both projects) and is used by the Cloud Functions in `functions/` (their own README).
3. **An App Check debug token per device for Debug builds.** Every ▶︎ Run build (simulator **and** a real iPhone) uses
   App Check's debug provider since 28 October 2026. Run the app once on the device, filter Xcode's console for
   `debug token`, and add it in **both** Firebase consoles → App Check → Apps → ⋮ → Manage debug tokens. One token per
   device (a new one after erasing a simulator or reinstalling the app). TestFlight and App Store builds use App Attest
   and need nothing. Keep the token out of chats, code and git; delete tokens you no longer use.
4. **Cloud Functions on a new Mac:** run `npm install` in `functions/` once before building or deploying them
   (`functions/README.md`); without it the build fails with "Cannot find module 'nodemailer'".

## Dev and production

One switch decides which Firebase project a build uses: **Build Settings → User-Defined → `FIREBASE_ENV`** (target LearnScrumble), `Prod` or `Dev`. Since 27 October 2026 it's **`Prod` for both Debug and Release**, so ▶︎ Run fills the real word bank (the app isn't launched yet, and filling the dev project with OpenAI calls would be wasted money).

| `FIREBASE_ENV` | You press | Firebase project | Pictures bucket |
|---|---|---|---|
| `Prod` (now) | ▶︎ Run or Archive | `scrumblegame` | `gs://scrumblegame-tools` |
| `Dev` (Debug only) | ▶︎ Run | `scrumblegame-dev` | dev default bucket |

- The **Copy Firebase plist** build phase reads `FIREBASE_ENV` and copies `FirebaseConfig/Prod/` or `FirebaseConfig/Dev/` into the app. Release (Archive, TestFlight, App Store) is **always** Prod, whatever the setting says. The build log shows "Copied Prod plist" or "Copied Dev plist".
- The app calls the Cloud Functions of the project it's connected to (`getWords`, `getPicture`, `reportPicture`, `reportWord`, region `us-central1`; `getReviewWords` is still deployed but no longer called), so dev builds use the dev functions and the dev word bank. Deploy function changes to `scrumblegame-dev` first (`functions/README.md`).
- Firestore and Storage rules are closed to phones (`allow read, write: if false`, since 27 October): only the functions write, and pictures load through their download links. A link with an outdated token gets a 403; `getPicture` repairs it (`functions/README.md`).
- To test against dev again (e.g. risky experiments): set `FIREBASE_ENV` to `Dev` for **Debug** only. Debug-only features (Settings → Debug → "Reset free words") work with either.
- With `Prod`, crash reports and statistics from your test runs land in the production project too; keep test crashes on `Dev`.
- `LearnScrumble/` is a synced folder: every file in it goes into the app. Keep config files outside it.
  That's why the planning docs live in `Docs/` at the repository root: in the repo for everyone, never inside the app.

## Testing tricks

**Reset the 10 free words** (10 once for the whole app, then a $9.99 unlock per profession). The counter lives in the Keychain, which survives deleting the app.
- Easiest: **Settings → Debug → Reset free words** (Debug builds only, `#if DEBUG`; never in App Store builds).
- Or, for the simulator's whole Keychain, in Terminal:
  ```bash
  xcrun simctl keychain booted reset
  ```

**Test the profession unlocks without App Store Connect.** The scheme uses `StoreKit/LearnScrumble.storekit` (Edit Scheme → Run → Options → StoreKit Configuration): one $9.99 non-consumable per menu job, `com.MaxGabriel.LearnScrumble.job.<case name>`. Purchases in the simulator are fake and only work when the app is started from Xcode (▶︎ Run); started from the icon or `simctl`, the app finds no product ("no product for …" in the log) and the Unlock button does nothing. The scheme's path is `../../StoreKit/LearnScrumble.storekit` (relative to `xcshareddata/xcschemes/`; fixed 28 October). Without buying: **Settings → Debug → Unlock every profession**. To buy again, Xcode → Debug → StoreKit → Manage Transactions → delete. The same product IDs must be created in App Store Connect before release.

**Start as a brand-new user.** Delete the app from the simulator (long-press the icon → Remove App), then Run again. Add the Keychain reset above for fresh free words too.

**Logs.** The app logs through `Log` (`Services/Log.swift`), not `print`:
- Xcode's console while running from Xcode; filter by category (`words`, `game`, `firebase`…).
- `Log.info` / `Log.error` lines also become Crashlytics breadcrumbs. `private:` details (the typed profession) only show in Xcode and never leave the phone.
- Without Xcode attached: Console.app → pick the simulator or iPhone → search `subsystem:com.MaxGabriel.LearnScrumble`.

**Analytics events in DebugView** (events are in `Services/Track.swift`):
1. Edit Scheme → Run → Arguments → add `-FIRDebugEnabled`.
2. Firebase console → `scrumblegame-dev` → Analytics → **DebugView**.
3. In the app, tick **Share usage statistics** (setup screen or Settings). With it off, nothing is sent; that's on purpose.
4. Events show within seconds. Logs never show there, only events.

**Crashlytics test crash.**
1. The button is already there in Debug builds: **Settings → Debug → Crashlytics crash test** (red; it calls `fatalError`).
2. Stop Xcode, open the app from the simulator icon (a crash isn't recorded while the debugger is attached), tap it.
3. Open the app again and leave it open for a minute; the report is sent on that launch.
4. Debug builds only: Crashlytics → dSYMs shows "Missing (required)". Zip `LearnScrumble.app.dSYM` from DerivedData (`Build/Products/Debug-iphonesimulator`) and drag it onto that page. Release builds upload it by themselves.

## App Store review guide

Everything App Review needs to understand the app, in the order a new user meets it. The paste-ready notes are first;
the detailed flow below is the reference for answering a reviewer's questions. *(Written 1 November 2026, revised 2 November (free words across reinstalls), build 6
plus the pronunciation test, the listening test, Test all and word reports. Update it whenever a screen, a permission
or a purchase changes.)*

**Seller:** Max Gabriel (individual Apple Developer account, team `7XZJ4BCPR6`), a sole proprietor operating as
**PawIT** (Ontario, Canada; CRA business registration active 1 November 2026). Support: support@learnscrumble.com,
https://learnscrumble.com/support · Privacy: https://learnscrumble.com/privacy · Terms: https://learnscrumble.com/terms

### Notes for the reviewer (App Store Connect → App Review Information → Notes)

> LearnScrumble teaches the vocabulary of the user's job in another language: the app shows a picture, the user spells
> the word from scrambled letters, and can then practise saying it and recognising it by ear. Words and pictures are created with AI on our server
> (OpenAI, only after the user agrees on the setup screen); most come from a prepared word bank, so a round loads in a
> few seconds, a new picture can take up to 30 seconds. An internet connection is needed, except for "My words" and the
> pronunciation and listening tests, which use words saved on the phone. No account or sign-in screen: the app signs in anonymously in
> the background.
>
> Suggested test: I speak English, profession "Cook", I want to learn Polish, tick "I agree", Start Learning. A short
> "How to play" tutorial runs while the first words load (Skip is top right); it ends with a demo of both tests. The first 10 words are free, once per
> install. After them the app offers a one-time in-app purchase that unlocks the chosen profession (US$9.99,
> non-consumable, no subscription) — please buy "Cook" with the sandbox account to test more words, "My words" and the
> voice picker (Settings → Audio). Restore purchases: Settings → Purchases, and on the purchase screen. The free words
> are kept on the device even when the app is deleted and reinstalled (so they can't be taken again): if this device
> already used them, setup leads to the start screen, where the Cook card shows "Unlock" — please buy it there with
> the sandbox account.
>
> Start screen ("Welcome back"): three cards. "My vocabulary" opens one card per profession + language with the score,
> Continue learning and My words (a list of played words; tap a word for a big swipeable card with a speaker and a flag
> to report a wrong picture or a wrong word/translation). "Pronunciation test" opens the same cards with "Practise pronunciation": tap a word, then
> "Tap to speak" and say the word shown. iOS asks for the microphone and speech recognition the first time; the app
> uses them only while the button shows "Listening…", never stores or sends the audio, and works fully without them.
> 3 tries per word; the result is shown with an animation and the word is read aloud. The test works with the words
> already played, including the 10 free ones (no purchase needed), and only for languages iOS speech recognition
> supports (Polish is supported). Please test it on a device; the iOS Simulator can't run speech recognition.
> "Listening test" (appears once a profession has 4 played words, so within the free words; no purchase needed): the
> app reads a word and shows 4 pictures; the user taps the matching one (first tap counts). No microphone. Both tests
> have "Test all", which runs through every word by itself.
>
> Reporting AI content: the flag on a picture reports a wrong picture; "Wrong word?" (after an answer) or the flag in
> My words reports a wrong word or translation, with the correct version typed by the user. Reports reach us daily
> and are fixed for everyone after a human check.
>
> Each profession's word list has an end (its most-used workplace words); when every word is played the app says so.
> New pictures are limited to 100 a day per user. The arrow at the top left of the game returns to the start screen;
> the gear there opens Settings.

*(About 3,300 characters; the field allows 4,000. Check before submitting that the word bank has "Cook" words with
Polish translations, and that the 32 products are attached to the version.)*

### The app flow in detail

**1. Launch.** A 2-second launch screen (logo and slogan), then:
- first launch → the setup screen;
- returning user → the start screen ("Welcome back").
The app follows the language the user speaks for its whole interface (53 languages plus English, right-to-left for
Arabic, Hebrew and Farsi), independent of the iPhone's language.

**2. Setup screen (first launch only).** Cards, top to bottom:
- **I speak** — the user's own language (the app's language from now on).
- **My profession** — one of 32 jobs from a menu (cook, warehouse worker, electrician…).
- **I want to learn** — the language to learn. Same language twice → an orange warning, Start stays disabled.
  A language without iOS speech recognition → a note that the pronunciation test isn't available for it yet
  (everything else works).
- **Daily reminder** — the time of one reminder a day, only on days the user hasn't played.
- **Your data** — what is sent to OpenAI and why, with **I agree** (required: without it no words can be created, so
  Start stays disabled) and **Share usage statistics** (optional, off by default).
- Small print: words and images are made by AI and may contain mistakes; up to 100 new pictures a day; links to the
  Privacy Policy and Terms of Use.
**Start Learning** → iOS asks for **notifications** (the app works without them) → the first words start loading.

**3. "How to play" tutorial** (over the loading game, once; replay: Settings → How to play; Skip at any time).
A pointer walks through a practice word: tap letters in order, tap a placed letter to send it back, ↻ starts the word
over, the lightbulb shows the word in the user's language, the speaker reads it aloud, the back arrow explains the start
screen and that Settings are there (gear),
then the whole word → the "Correct!" screen with the note "You get 10 free words to try the app" → **Next** → two short
pages: the **Pronunciation test** (a demo of "Tap to speak" — the microphone is not used here) → **Next** → the
**Listening test** (a working demo: the speaker, 4 pictures, first tap counts) → **Let's go!**. Both pages say the tests
are on the start screen once a few words are played, with Test all.

**4. The game.** Rounds of 10 words.
- Top: **back arrow** (left; ends the round — every answer is already saved — and returns to the start screen) and
  the **speaker** (right; reads the word in the language being learned).
- The **picture**: a **flag** (top left) to report a wrong picture ("Report this picture?" → the user gets a new one
  within about half a minute, and the report is emailed to us for a check), a **lightbulb** (top right) with the word
  in the user's language.
- Answer slots and scrambled **letter tiles**; ↻ resets the word. Long answers fit by shrinking the tiles.
- All slots filled → **Correct!** (animals dance) or **Incorrect** + the correct word (animals walk off) → Next.
  Under the result, **Wrong word?** opens the correction form (see 7); it's offered only after the answer, so the form
  never gives the word away.
- After 10 words → **round result**: right answers this round, the profession's progress (words learned = right at
  least twice and 3 times out of 4, all right and wrong answers), days in a row → Continue / My words / Exit.

**5. Free words and the purchase.** 10 free words once per install (kept in the Keychain, so reinstalling doesn't
reset them). After the 10th: **"Unlock your profession"** — what's included, the vocabulary size and the picture
limit, **Unlock for $9.99** (the price in the user's currency from the App Store) and Restore purchases (Terms and
Privacy links are in Settings and on the setup screen; not required for one-time purchases). Apple's purchase sheet → **"Unlocked!"** → Let's go!. One non-consumable per profession:
`com.MaxGabriel.LearnScrumble.job.<case name>`, 32 products (list in `StoreKit/LearnScrumble.storekit`). An unlock
gives that profession's word list, My words and the voice picker. Locked features show a lock and lead to this screen.

**6. Start screen ("Welcome back").** The owl (celebrates at 80% right or more), "Welcome back!", the streak.
- **Top level** (when a card can take a test): up to three cards with a score ring and its label under it:
  - **My vocabulary** — ring: right answers out of all answers in the game.
  - **Pronunciation test** — ring: tests said right on the first try out of all tests ("—" before the first). Only
    when one of the user's languages supports speech recognition.
  - **Listening test** — ring: right pictures out of all listening tests. Only when a profession + language has at
    least 4 played words with pictures.
  The gear (top left) opens Settings. If no card can take a test, there's no top level: the vocabulary cards show
  straight away, as before 1 November.
- **My vocabulary** → the back arrow (top left) and a wallet-style stack, one card per profession + language the user
  learns, oldest at the top. Tapping a card's top strip opens it and makes it the current profession and language.
  An open card shows learned / right / wrong, words played, free words left (if not bought) and buttons:
  **Continue learning** (a game), **My words** (bought), **Unlock** (not bought and the free words are used up),
  My words with a lock (not bought).
- **Pronunciation test** → the same stack, only languages that can be tested, each card with words tested, right on
  the first try and struggled, and **Practise pronunciation** (needs at least one played word; no purchase needed).
- **Listening test** → the same stack, only cards with 4+ words with pictures, each with words tested, right and wrong,
  and **Practise listening** (no purchase needed).

**7. My words** (bought professions). Every word played for the profession and language, hardest first, with its
picture and right / wrong counts. Tap a word → its picture grows into a **card carousel** over the list: ✕, speaker,
the picture with the report flag, the word, its translation, right / wrong; swipe or tap a side card for the next
word; ✕ or tapping outside shrinks it back into its row. The flag asks **What's wrong?**: **Wrong picture** (as in the
game) or **Wrong word or translation** → a form with the word and its translation filled in; the user corrects the
wrong one (Send stays off until something changed), adds an optional note and sends it. Nothing changes on the phone;
the report is emailed to us the next morning with OpenAI's opinion, and an approved fix reaches everyone. **Continue learning** and **Repeat all** (the same words as a
game in rounds of 10, offline) at the bottom.

**8. Pronunciation test.** The list of played words, the hardest to say first, with ✓ (right on the first try) and ↻
(struggled) counts. Tap a word → the same carousel, each card with ✕, the picture, the word and **Tap to speak**:
- The first tap → iOS asks for **speech recognition**, then the **microphone** (texts in `InfoPlist.xcstrings`,
  shown in the iPhone's language). Denied → "Allow the microphone and speech recognition…" with **Open Settings**.
- Listening → the button turns red ("Listening…") and the live text appears; it stops when the user stops talking
  (about 1.3 s of silence), when the word is heard, or after 6 s. Tapping again stops it.
- Right → ✓ result on the card (animals dance), then the word is read aloud. Not right → "Not quite. Try again." with
  what was heard; 3 tries (dots under the button). Third miss → ✗ result, then the word is read aloud. Silence or a
  missing permission doesn't use a try.
- Result card: **Next word** (Done on the last) and **Again**. Saved per word on the phone: right on the first try, or
  struggled (needed a 2nd/3rd try or missed).
- Checking: the recognised text matches the word after tidying case and punctuation, inside a phrase ("the
  blender"), joined or split ("wine glass" / "wineglass"), or one letter off for words of 8+ letters (two for 16+).
- Recognition runs on the iPhone or on Apple's servers, as iOS decides; nothing goes to our server.
- **Test all** (button at the bottom of the list): starts at the first word and runs by itself — no swiping; after each
  result the next word comes (about 2.8 s, after the word is read); the result has no "Again". After the last word: a
  summary ("8 / 10 right") with Again / Done. ✕ or tapping outside stops it; every answer is already saved.

**8b. Listening test.** The played words with pictures, misses first, with ✓ / ✗ counts. Tap a word → the carousel,
each card with ✕, **4 pictures** (the word's and 3 others of the profession, shuffled) and a big **speaker** button:
- The pictures are dimmed until the word has played once. The first tap is final: right → green ✓; wrong → the tapped
  picture red ✗ and the right one green. Success / incorrect sound and a haptic. No result screen: the word and its
  translation appear under the grid, with a small speaker and **Next word** (Done on the last).
- **Test all**: the word plays 0.5 s after each card comes to the front; 1.5 s after the answer the next card comes;
  no swiping; summary at the end, as in the pronunciation test.
- Saved per word on the phone: right / wrong taps. No microphone, works offline.

**9. Settings** (the gear on the start screen): languages and profession (with the same warnings as setup), audio
(voice — bought — and speech speed with "Try it"), daily reminder, progress (reset the current language), purchases
(Restore purchases), legal and support (how to play, privacy, terms, support email, the OpenAI explanation, usage
statistics). Debug tools exist only in Debug and tester builds, never in the App Store build.

**10. Other screens.** No internet → an offline screen that retries by itself; server errors → a message with the
right button (try again, change profession, back); a profession whose word list is finished → a message, with My
words and both tests still available. The opened iPhone Duo shows the game, pop-ups and alerts on one half
of the fold; the folded Duo uses smaller top buttons and asks to unfold for answers too long for the outer screen.

### Permissions and data at a glance

| What | When | Without it |
|---|---|---|
| Notifications | Start Learning on the setup screen | No reminder; everything else works |
| Speech recognition + microphone | First "Tap to speak" | No pronunciation test; everything else works (the listening test needs neither) |
| Agreement to send the job to OpenAI | Setup screen ("I agree"), or a one-time sheet for older installs | No new words (explained on screen) |
| Usage statistics | Optional switch, off by default | Nothing is sent |

No tracking, no ads, no account; progress and pronunciation and listening results stay on the phone. A word report
sends the word, the job, the two language codes, what the user saw and typed, and an optional note (no identity). Details: `WebsiteContent/privacy.html`,
the App Store privacy answers in `WebsiteContent/README.md`, `LearnScrumble/PrivacyInfo.xcprivacy`.

### Review test path (on a real iPhone, App Store build)

1. Fresh install → setup (English, Cook, Polish, I agree) → allow notifications → tutorial → 10 words.
2. Report a picture with the flag; use the lightbulb and the speaker; leave a round with the back arrow and continue.
3. After the 10th word: the unlock screen → buy with sandbox → "Unlocked!" → more words.
4. Start screen → My vocabulary → My words → open a word, swipe, close; Repeat all with flight mode on.
5. Start screen → Pronunciation test → Practise pronunciation → allow speech + microphone → say a word right, then one
   wrong three times; check the rings and counts afterwards. Then Test all, and stop it with ✕.
5b. Start screen → Listening test → Practise listening → tap a word, the speaker, a picture; then Test all to the end.
5c. After an answer in the game: Wrong word? → correct the translation → Send → "Thanks!". Also from the flag in My words.
6. Settings: Restore purchases, voice picker, reminder time, reset progress, the legal links.
7. Change "I want to learn" to Lithuanian in Settings: the note under it appears, and a Lithuanian card shows under
   My vocabulary but not under Pronunciation test.
8. The same build on an iPad (compatibility mode): setup, a round, the purchase screen, both tests, Settings.

## Release: App Store Connect and TestFlight

**The app in App Store Connect** (set up 29 October 2026): https://appstoreconnect.apple.com/apps/6828468301 —
name LearnScrumble, bundle ID `com.MaxGabriel.LearnScrumble`, team `7XZJ4BCPR6` (Max Gabriel, individual), primary
language English (U.S.). Business: Max Gabriel, sole proprietor operating as **PawIT** (CRA registration active 1 November 2026).

**Account status (Business page, 1 November 2026):**
- Free Apps Agreement: Active → builds can be uploaded and tested in TestFlight.
- Paid Apps Agreement: signed 29 October; until it's **Active** the $9.99 profession unlocks can't be bought, not even
  in TestFlight. Everything it needs is submitted and waiting for Apple: bank account (RBC, CAD), U.S. tax form W-8BEN
  (individual, Canada, SIN, treaty benefits), Canadian GST/HST Form 506 (CRA Business Number of PawIT + `RT0001`), and
  the EU trader status (Digital Services Act).
- App Store Small Business Program (15% commission instead of 30%): steps in `Docs/AppStoreReadiness.md` §6.1.
Current status of each item: `Docs/AppStoreReadiness.md` §6.1.

**Upload a build to TestFlight:**
1. Xcode toolbar → destination **Any iOS Device (arm64)** → **Product → Archive** (Release = production Firebase,
   App Attest, no Debug switches).
2. Organizer → the archive → **Distribute App → App Store Connect** (not "TestFlight Internal Only": that build
   can't go to external testers or the App Store) → **Distribute**, default options.
3. Each upload needs a **higher build number**: target → General → Identity → **Build** (1, 2, 3…); the version (1.0)
   can stay.
4. App Store Connect → **TestFlight**: the build is "Processing" for 10–30 minutes. **Internal Testing** → a group →
   add testers (people in Users and Access, no review) → add the build. **External Testing** → a group → public link
   (Apple reviews the first build, about a day).
5. Testers install Apple's **TestFlight** app, then LearnScrumble.

**Tester builds (for TestFlight only):** `scripts/upload-tester-build.sh <build number>` archives and uploads a
Release build with the `TESTFLIGHT_TOOLS` flag: Settings then shows the Debug section (Reset free words, Unlock every
profession), so you and your testers can test the paid parts and play again after the 10 free words. Everything else
is the real thing (production Firebase, App Attest, App Store purchases). **Never submit a tester build for review**
(the reviewer would see "Unlock every profession"): the review build is a normal Xcode **Product → Archive** with a
higher build number, picked on the iOS version page. Products and prices belong to the app, not to a build, so every
build uses the same ones. Build 2 (29 October) is a tester build.

**"Upload Symbols Failed … did not include a dSYM for …framework" after uploading:** warnings, not errors — the build
is uploaded. Google ships some Firebase parts prebuilt without symbol files, so Apple's crash reports can't name the
code *inside* those frameworks; our own code is symbolicated (and Crashlytics gets our dSYM). Since 29 October only
`FirebaseAnalytics` and `GoogleAppMeasurement` (closed source, Google never publishes their dSYMs) are left: the app
uses `FirebaseAnalyticsCore` (no advertising-ID / ad-conversion frameworks) and no longer links Firestore or Storage
(all their reads and writes go through the Cloud Functions), which removed the other seven warnings.

**Submit for review** (once the Paid Apps Agreement is Active and a TestFlight round on a real iPhone passed;
`Docs/AppStoreReadiness.md` has the status of each item):
1. **The review build:** a **normal** Product → Archive (not the tester script — a tester build shows the Debug
   section), with a higher build number → Distribute App → App Store Connect. Wait until it's processed.
2. App Store Connect → the app → **iOS App → the version (1.0)**:
   - **Build:** pick the review build.
   - **In-App Purchases and Subscriptions:** add **all 32** profession products (each must show "Ready to Submit";
     exact IDs in `StoreKit/LearnScrumble.storekit`). They're reviewed together with the app.
   - **Store listing:** screenshots (6.9" iPhone, required), promotional text, description, keywords, support URL
     `https://learnscrumble.com/support`, marketing URL `https://learnscrumble.com`, copyright "2026 Max Gabriel".
   - **App Review Information:** sign-in **not** required; contact name, phone and email; **Notes** = the text from
     "Notes for the reviewer" above, pasted **without** the `>` marks and line breaks (one paragraph per block).
     Check first that the bank has "Cook" words with Polish translations.
   - **Version release:** manual or automatic after approval (manual lets you pick the launch day).
3. App Store Connect → the app → **App Information:** category Education, age rating questionnaire (AI-generated
   content: yes; user content: corrections only reach us, nothing unmoderated is shown to others), and the
   **Privacy Policy URL** `https://learnscrumble.com/privacy`.
4. **App Privacy:** the answers from `WebsiteContent/README.md` (the same as `PrivacyInfo.xcprivacy`).
5. Version page → **Add for Review** → **Submit for Review**. Review usually takes 1–3 days; Apple emails the result.
   A rejection explains why in App Store Connect → Resolution Center: fix it, upload a new build, resubmit.

## Git

- Work on `main` while the app isn't in the App Store yet. Once it's live, use a branch per feature so `main` stays shippable.
- On another Mac: Xcode → Integrate → **Pull** to get the latest commits.
