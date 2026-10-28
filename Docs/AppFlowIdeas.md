# LearnScrumble: app flow ideas and directions (October 2026)

**For:** Max
**Based on:** our discussions on 14 October 2026, after the daily reminder was finished. Companion to `checklist.md`.
**Status:** ✅ = agreed direction · ❓ **need discussion** = waiting on a conversation or decision (often with Konstantin) · ⬜ **to do** = agreed, not started yet · ✖️ **dropped** = discussed and not doing

---

## 1. Content: live AI vs pre-made packs

**Direction:** ✅ *(built 27 October)* A hybrid word bank in Firebase, generated on the server. *(Agreed between us; Konstantin still to confirm. Built as: words tagged with the jobs they're used for, the job's bank first, GPT only for the missing words, all in Cloud Functions — `ServerMigrationPlan.md` Phases 4–5)*

- ⬜ **to do** **Pre-generate the listed professions.** A Firebase function generates 100 words for each profession in the picker.
- ✅ *(differently)* **Generate more on demand.** When a profession's words run out, the server generates about 50 more and saves them to the bank. *(27 October: instead of 50 at once, every batch takes the job's unseen bank words first and GPT makes only the missing ones (up to 5), which are saved to the bank and tagged with the job. The bank grows as people play)*
- ✅ *(partly)* **Typed professions ("Not listed?").** Before generating, the server asks AI to map the text to one English job name or to an existing profession ("cook", "chef", "cooks", "kucharz", "cok" → "Cook"). It checks the bank for words already shared with other professions, generates the rest in the background (the first 10 quickly so the user can play right away) and saves them. *(16 October, first part: typed and picked jobs are already counted in English in Firestore `professions` with no user ID (`ProfessionStore`), so the analyst list exists. 27 October: the server moderates the typed text, GPT gives it one English job name, and that name is the bank key, so "kucharz" and "Кухар" share the `cook` bank; the phone remembers the name for the next batches. Background pre-generation and matching against the menu's names are still to do (§8))*
- ⬜ **to do** **New professions are reviewed first.** A typed profession only joins everyone's picker after the analyst team approves it. The user who typed it gets their words straight away.
- ✅ **Translations made when needed.** Pictures and English words are made once; a language's translations are only generated when someone with that language first asks. *(27 October: a known word that GPT suggests for a new language pair gets the missing translations added and keeps its picture)*

**Why the hybrid:** packs alone mean native speakers for every language, and users run out of words after the pack. Live AI alone means waiting for generation and unchecked words. A bank that AI fills, that users report on and that we correct turns into packs over time.

### Pros and cons we agreed on

| | Live AI | Packs |
|---|---|---|
| Speed in game | Waits for new words | Instant |
| Quality | Unchecked | Reviewed |
| Jobs covered | Any | Only prepared ones |
| Cost | Per use, grows with users | Upfront, then flat |
| Content | Endless, no built-in priority | Limited, structured |
| Selling to employers | Hard to package | A natural product |

## 2. Word quality

- ⬜ **to do** **A Report button** for a wrong picture or word. Reports go into a review queue in Firebase, and a correction fixes the word for every user, because the bank is shared.
- ⬜ **to do** **A status per word:** AI, reported or checked, so we know what has been verified.
- ✖️ **dropped** **Word meaning in the prompt.** Today the picture is disambiguated explicitly (for example "a plumbing pipe, NOT a smoking pipe"), but the two words only get it from context. Add a rule: "originWord and targetWord must name exactly the object described in imagePrompt, as used by a [profession]". *(`RequestModel.generateWordList`. Dropped for now: no wrong words seen in practice, and the picture is the crucial part, which the prompt already disambiguates)*
- ⬜ **to do** **A meaning-aware bank key.** Firebase stores one document per English name (`toolName`), so the same name with a different meaning in another job ("pipe", "level", "spring") would share translations and a picture. On the server, the key should include the meaning or the profession, for example "pipe (plumbing)".
- ✅ **Remove the rare languages** where GPT is weak and sometimes invents words. *(Removed on 14 October: Bhojpuri, Bodo, Dogri, Konkani, Maithili, Manipuri, Sanskrit. None of them had a UI translation either)*
- ✅ The hint is in the user's own language, so a hint that doesn't match the picture can be spotted and reported. The risk left is a wrong word in the language being learned, which the rare-language removal reduces.

## 3. Safety: liability

- ✅ **The app teaches workplace vocabulary, not safety training.** Safety rules must be taught on site by professionals, not by us.
- ⬜ **to do** No "safety commands" category and no instructions such as "step aside when the forklift comes". Words like "stop" or "danger" can still appear as ordinary vocabulary.
- ⬜ **to do** A disclaimer in the app and in the terms, for example "LearnScrumble helps with work vocabulary. It doesn't replace safety training at your workplace."
- ❓ **need discussion** Remove `safetyCritical` and the safety commands from the pack format in `checklist.md` §5, and have a lawyer check the disclaimer wording. *(Raise with Konstantin)*

## 4. Offline and paid review

- ✅ **Struggle review is the paid feature.** It's the moment users see value in their own history.
- ⬜ **to do** **Offline review for paying users only.** When `hasAccess` is true, the words and pictures the user has seen are downloaded in the background and kept on the phone: words and progress in SwiftData, pictures in a local file cache. Review then works offline. Roughly 5–10 MB per 100 words.
- ⬜ **to do** **History on upgrade.** A free user's answered words are already in SwiftData (English name, language, right/wrong counts), so when they subscribe, the app downloads those words and pictures in the background. Nothing needs storing for free users before that.
- ✖️ **dropped** Downloading 30 minutes before the reminder. iOS doesn't run apps at an exact time, and once the bank exists the words really are ready in Firebase, so the notification isn't lying.
- ✖️ **dropped** Downloading the next batch ahead for offline new words. Offline play is only needed for review.

## 5. Onboarding: a "How to play" step

- ✅ **An interactive tutorial after the setup screen.** *(Built 14 October as one session on the real game screen, instead of separate steps)*
  1. Tap the first letter of the practice word ("cat" in the language being learned).
  2. Tap a letter that goes in the wrong place on purpose, then tap it in the answer to send it back.
  3. Tap ↻ to clear the answer.
  4. The hint (lightbulb), the speaker and the settings gear.
  5. Spell the whole word; the real "Correct!" screen shows the daily free words and "Let's go!".
- ✅ **A tapping pointer (PointerUp) and a tooltip** on every task; both move on as soon as the task is done.
- ✅ **Skip at any moment.** Back isn't needed in one session: every action can be redone in place.
- ✅ **It runs while the first words load** after "Start Learning".
- ✅ **Two flags:** "setup finished" on Start, "tutorial seen" at the end or on Skip. Closing the app mid-tutorial shows it again next launch.
- ✅ **"How to play" in Settings,** to replay it.
- ✅ **In the user's language,** including the hint; the practice word is in the language being learned.

## 6. Paywall: how it works

- ✅ **Personal subscriptions use Apple's In-App Purchase (StoreKit).** Apple's guideline 3.1.1 requires it for unlocking features inside the app; Stripe inside the app for a personal subscription gets rejected. Exceptions: the US App Store allows a link to a web checkout since 2025, and the EU (Poland) has its own options with their own fees. *(Rules change often: check Apple's current guidelines before deciding)*
- ✅ **Business sales can use Stripe.** Apps sold directly to organizations for their employees may be paid outside the App Store (guideline 3.1.3(c)). The factory pays on our website through Stripe and gets access codes.
- ❓ **need discussion** **RevenueCat on top of StoreKit.** It tracks who is subscribed, gives ready-made paywall screens and revenue charts, and can combine App Store and Stripe purchases into one "has access" status, matching the single `hasAccess` check. Free until a few thousand dollars a month in revenue, then a small percentage.
- ⬜ **to do** **Learn it locally first.** Xcode's StoreKit configuration file lets us create test products and "buy" them in the simulator, with no App Store Connect account and no money. *(Matches the `checklist.md` rule: no live products in your own account yet)*

| Piece | What it is | Cost |
|---|---|---|
| StoreKit | Apple's in-app purchases | Apple takes 15% (Small Business Program) or 30% |
| RevenueCat | Subscription tracking, paywall screens, charts | Free up to a few thousand dollars a month, then a small percentage |
| Stripe | Business sales on our website | Stripe's normal fees |

## 7. Selling to businesses

- ⬜ **to do** **A website where a business builds its own pack.** The factory enters its machines, materials and work terms, AI drafts the words and pictures, and the pack is saved in Firebase for that company only.
- ✅ **The business checks its own pack.** Its supervisors speak both languages, which solves the native-speaker cost.
- ⬜ **to do** **Workers join with an access code.** That's the access-code path already planned for `hasAccess`.
- ✅ **A subscription, not a one-time sale.** Paid per worker or per site, including the generation cost. A one-time sale with unlimited users invites sharing and reselling; with a subscription, access stops when payments stop.
- ✖️ **dropped** Businesses bringing their own OpenAI key. Most factories don't have one, it adds friction, and storing other companies' keys is a security responsibility. *(It can stay an option for big companies that require it)*
- ⬜ **to do** **Against resale:**
  - access codes belong to one company, with a seat limit and an expiry date, and can be cancelled or replaced;
  - the content stays in our Firebase and is only shown inside the app, to signed-in workers;
  - a contract clause forbids reselling or sharing.
- ⬜ **to do** **Usage tracking per company:**
  1. a worker's account is linked to their company when they enter the code;
  2. every request to a Cloud Function carries that link;
  3. the function adds to the company's counters in Firestore: new words, new pictures, active workers this month;
  4. it checks the plan's limit before generating; when the limit is reached, it serves only existing words;
  5. the business website shows the same counters, which are also the billing numbers.
  Only new generation costs real money; serving words already in the bank is cheap Firebase reads.

## 8. Review queue for the analyst team

- ✅ *(partly)* **One queue in Firebase** for new professions and word reports, each with a status: waiting, approved or rejected. *(16 October, professions part: Firestore `professions`, one document per job in English with `typed` / `picked` counts, `firstSeen`, `lastSeen` and a `status`: "in menu" for menu jobs, "new" for jobs missing from the menu, then "added" or "rejected" by hand. No user ID, never the typed text. Tested: menu "Cook" and Ukrainian "Кухар" land in the same `cook` document; "Різноробочий" became `general laborer`. Word reports come with the Report button, §2)*
- ✅ *(started)* **Work in the Firebase console at first,** then a small admin page later. *(Review list today: Firestore console → `professions` → Query → filter `status == "new"`, order by `typed` descending)*
- ⬜ **to do** **Use the menu's names for typed jobs.** Give OpenAI the menu's English job names with the rule "if the job matches one of these, use that exact name", so the same job doesn't split into `laborer`, `general laborer` and `general worker`. Rare synonyms are merged by hand during review.
- ⬜ **to do** **A small admin page** once the list is long (hundreds of jobs): a sorted table of job, typed, picked and last seen, with Add / Reject / Merge buttons, behind a login for us and Konstantin. On Firebase Hosting, next to the website (`ServerMigrationPlan.md` Phase 9).

## 9. Firebase work, done together step by step

- ✅ **Step 1: Crashlytics and Analytics.** Small and low-risk, and they start collecting data straight away: crashes, plus the events "onboarding finished", "round finished", "paywall shown" and "trial started". *(`checklist.md` §4.4)* *(15 October: both libraries are added and crash reports work, tested in a separate dev project `scrumblegame-dev`. The analytics consent switch (15 October), logs, crash breadcrumbs, non-fatal errors and the events (16 October) are done and tested in DebugView and Crashlytics. Only `paywall_shown` and `trial_started` wait for the paywall. Details in `ServerMigrationPlan.md` Phase 1)*
- ✅ *(partly)* **Step 2: Cloud Functions.** *(27 October: the functions, the key on the server, anonymous sign-in and App Check (monitoring) are done in both projects. Left: publish the closed rules and enforce App Check — `ServerMigrationPlan.md` Phases 6–7)*
  - the OpenAI key moves to the server, with all generation;
  - Firestore rules: the app only reads, the functions write;
  - App Check and anonymous sign-in.
- ✅ **Before step 2: the Blaze plan.** Firebase requires the pay-as-you-go plan for Cloud Functions and for calling outside services like OpenAI. It needs a payment card. Small usage stays within the free allowance; set a budget alert in Google Cloud from day one. *(Done: `scrumblegame` and `scrumblegame-dev` are both on Blaze, with budget alerts of €10 and €5. On 15 October the OpenAI monthly limit was set and auto recharge turned off)*

---

## 10. Summary (14 October)

### ⬜ To do

1. ✅ **Firebase step 1:** Crashlytics and Analytics, together. *(§9)* *(Done 15–16 October; `paywall_shown` and `trial_started` come with the paywall)*
2. ✅ *(partly)* **Firebase step 2:** Cloud Functions with the OpenAI key, the hybrid word bank and locked-down rules, after the Blaze plan. *(§1, §9)* *(27 October: all done except publishing the closed rules and App Check enforcement)*
3. ⬜ **Word quality:** Report button, a status per word, a meaning-aware bank key. *(§2)*
4. ⬜ **Safety disclaimer** in the app and terms; no safety commands or instructions. *(§3)*
5. ⬜ **Offline review for paying users,** plus history on upgrade. *(§4)*
6. ⬜ **Paywall learning** with a local StoreKit configuration file. *(§6)*
7. ✅ *(partly)* **Review queue** for professions and reports. *(§8)* *(Professions counted and reviewable in the console since 16 October; menu-name rule, admin page and word reports still to do)*
8. ⬜ **Business product:** website packs, access codes with limits, usage counters, no-resale clause. *(§7)*

### ❓ Need discussion

1. ❓ **The hybrid word bank,** with Konstantin. *(§1)* *(Built on 27 October; packs can still be added on top if he wants them)*
2. ❓ **Safety:** removing safety commands from the pack format, and a lawyer's check of the disclaimer. *(§3)*
3. ❓ **RevenueCat or StoreKit alone.** *(§6)*
4. ❓ **Business prices and plans:** per worker or per site, and usage limits. *(§7)*

### ✖️ Dropped

- ✖️ Downloading 30 minutes before the reminder. *(§4)*
- ✖️ Downloading the next batch ahead for offline new words. *(§4)*
- ✖️ Businesses bringing their own OpenAI key, except as an option for big companies. *(§7)*
- ✖️ A meaning rule for the two words in the generation prompt, for now. *(§2)*
