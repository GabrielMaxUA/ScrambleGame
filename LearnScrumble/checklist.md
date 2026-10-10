# LearnScrumble: feedback and next steps (October 2026)

**For:** Max
**From:** Konstantin
**Based on:** your code at `1e60eb9` (1 October 2026), which I built and reviewed on 4 October. Nothing new had been pushed by 7 October.
**Status:** revised 7 October to the direction "keep building toward a finished app". Ready to send after Konstantin's read-through.
**Progress check (10 October, against the current code):** ✅ = done · ❓ **need discussion** = waiting on a conversation or decision · ⬜ **to do** = not started yet

---

## 1. What's working

- **Pace and follow-through.** You pushed 15 commits between 22 September and 1 October. In the last two you fixed four problems we had found:
  - the endless loading loop;
  - the hidden toolbar;
  - the crash when both languages are the same;
  - the stale batch after a failed start.
- **Real error handling.** There are now seven error types, timeouts with backoff, and a retry-or-exit screen instead of a silent spinner.
- **An interface that follows the "I speak" language.** It has right-to-left support and language names written in each language itself.
- **A game that feels like a product.** Rounds, a results screen, the missed-word review, text-to-speech and the animated drawings make it one. The drawings respect Reduce Motion and are hidden from VoiceOver, which is a nice touch.
- **A clean build.** It compiles with 0 errors and 0 Swift warnings once the minimum iOS is lowered for older Xcode.

## 2. The honest read

The game itself is in good shape. **The app around it is not finished yet.**
- ⬜ **to do** There is no first-run onboarding. *(Still one setup screen, now with a saved completion flag and a welcome-back screen; see §4.1)*
- ✅ "Settings" is the setup screen again, reached from the gear button. *(Now a real Settings screen: `SettingsView.swift`.)*
- ⬜ **to do** There is no paywall, no reminders, and no support or terms pages. *(Support and terms rows exist in Settings, with placeholder links)*
- ❓ **need discussion** The things that block a public release are still open (§4.4).

Since mid-September, about half of the new Swift code (52% of 3,469 added lines) went into screens, components and animations. Very little went into what a release needs:
- ❓ **need discussion** server-side AI calls: none; *(planned as Firebase Cloud Functions, but depends on the packs decision in §5)*
- ⬜ **to do** analytics and crash reporting: none;
- ❓ **need discussion** consent and privacy: an AI disclaimer and a placeholder privacy link so far;
- ⬜ **to do** a paywall or seat access: none. *(The single `hasAccess` check is ready for it)*

That's about direction, not effort. We never agreed on a clear target, and that's on me. **This document is that target: §3, then §4, in that order.**

## 3. Fix first: small items, about 2–3 days in total

| # | What | Where | Why |
|---|---|---|---|
| ❓ **need discussion** 1 | The "Privacy Policy" link points to `your-site.com` | `EntryView.swift:18` | App Review rejects a placeholder policy, so a real hosted page is needed. *(Still `your-site.com` in `EntryView` and `SettingsView`; the TODO says it's blocked by the packs decision)* |
| ✅ 2 | The loading screen can still stick after a checkpoint | `WordVM.swift:231, 252, 282`; `AppManager.swift:73` | When exactly two words are left, `advance()` starts a prefetch, `onResume` routes to loading, and nothing routes back. Route on "is a word ready?", not on "is a fetch running?" *(Now routes on `pendingAdvance`; confirmed in a simulator trace. The prefetch also starts earlier, with 3 words left)* |
| ✅ 3 | A "/" in a word name crashes Firestore, for example "a/c unit" | `FirebaseWordStore.swift:37, 87` | Turn `toolName` into a safe slug before using it as a document ID or in the `in` query *(`documentID(for:)`; the `in` query is also split into groups of 30 now)* |
| ✅ 4 | The shuffle never ends for words made of one repeated letter | `WordVM.swift:158-162` | `repeat … while shuffled == letters` loops forever on "mm" or "妈妈". Add an attempt cap *(Capped at 10 tries; skipped when all letters are the same)* |
| ✅ 5 | Seven strings stay in English, and "Loading" has no translations | `EntryView.swift:37, 39, 92`; `MenuAlert.swift:15-23`; `LoadingView.swift:41` | The seven are passed as `String`, not `LocalizedStringKey`, so the catalog never sees them. "Loading" is in the catalog but has 0 translations *(All are `LocalizedStringKey` now, and "Loading" has 54 translations. The VoiceOver value "%lld percent" in `LoadingView.swift:51` now has 54 translations too)* |
| ✅ 6 | The review shortcut never appears with the default target language | `RootView.swift:8, 15` vs `EntryView.swift:6, 61` | `@AppStorage("pickedLanguage")` defaults to "" in one view and "en-US" in the other *(All three views now default to "en-US")* |
| ✅ 7 | "Retry" after a failed review starts a normal, paid session | `RootView.swift:30` | Retry should repeat what failed *(`AppManager.retry()` uses `lastSession`)* |
| ✅ 8 | An unused cat photo of about 15 MB ships in the app | `Assets.xcassets/cat.imageset` | It bloats the download and causes a build warning *(Removed)* |

Items 2–3 would disappear if we move to pre-created packs (§5), but they affect users today, so fix them now.

## 4. Next: make the app feel finished

Work in this order. The sizes are rough estimates.

### 4.1 Onboarding: a real first-run experience (about 2–4 days)

**Today:** one setup screen that doubles as "settings". There is no first-run flow, no notification permission, and no consent step.

**Build:**
1. ✅ **Welcome.** One sentence on what the app does, in the user's own language, for example "Learn the words you need at work, in your language". The current welcome text is a good start.
2. ✅ **Languages.** "I speak" and "I'm learning", using the existing pickers.
3. ✅ **Job.** A short list of common jobs to tap, plus the existing free-text field. This also tells us which jobs people actually pick. *(`ProfessionPicker`: an occupation menu plus "Not listed?" free text)*
4. ⬜ **to do** **Daily reminder.** Ask for a time, then ask for notification permission on this screen with a one-line reason. Not at launch. *(Not started: no `UserNotifications` code yet)*
5. ❓ **need discussion** **Consent.** Say plainly that the job text is sent to OpenAI to create words and pictures, and get an explicit "OK", with a link to the real privacy policy. Apple's App Review rule 5.1.2(i) requires this; the current disclaimer isn't enough. *(Only the AI disclaimer so far; the wording depends on live AI vs packs and on the real privacy policy)*
6. ✅ **Straight into the first round.** Aim for the first correct word within about a minute of opening the app.

**Rules for the whole flow:**
- ✅ It is shown once, with a saved completion flag. *(`hasCompletedOnboarding`; returning users get the welcome-back screen)*
- ⬜ **to do** Back and skip work. *(Not needed yet: onboarding is still a single screen)*
- ✅ Every string is localized.
- ✅ Changing languages later happens in Settings, not by re-running onboarding.

### 4.2 Settings: a real screen (about 1–3 days)

**Today:** the gear button returns to the setup screen.

**Build** a Settings screen with:
- ✅ **Languages and job.** Tell the user what happens to their progress before they change these, because progress is stored per target language.
- ⬜ **to do** **Reminder:** on/off and time.
- ✅ **Audio:** speech speed, and auto-play on or off. *(Speech speed and a voice picker are done. Auto-play is left out on purpose: speech stays on demand through the speaker button, because speaking every word automatically gets annoying. Worth telling Konstantin)*
- ✅ **Progress:** reset progress, with a confirmation.
- ✅ **Subscription:** manage subscription, and Restore Purchases.
- ❓ **need discussion** **Legal and support:** privacy policy, terms of use, and a support email. *(The rows exist, but the URLs are still `your-site.com` and the email is `support@example.com`)*
- ❓ **need discussion** **Delete my data:** local progress now, account data later. *(Built, but commented out in `SettingsView.swift:59` and `AppManager.swift`)*
- ✅ **App version.**

### 4.3 Paywall (about 3–5 days)

- ⬜ **to do** **RevenueCat on top of StoreKit**, as planned in the brief.
- ✅ *(partly)* **Free first, paywall after value.** Show the paywall after the first completed round, never at launch. A starting proposal is a set number of free rounds per day, tuned later from data. *(The daily free limit is done: 20 words, which is 2 rounds, in `FreeAllowance`, stored in the Keychain and dated with internet time. The paywall screen itself isn't built yet)*
- ❓ **need discussion** **Plans.** Monthly and annual, with a free trial. For reference, education-app medians in our research are about $9.99 a month and $40–45 a year (RevenueCat benchmarks). Set the final prices with me.
- ⬜ **to do** **App Review must-haves (guideline 3.1.2):**
  - ⬜ **to do** before purchase, show the price, the period and what's included;
  - ⬜ **to do** show the auto-renewal terms;
  - ❓ **need discussion** link to the terms of use and the privacy policy; *(needs the real pages first)*
  - ✅ include a Restore Purchases button. *(In Settings; the paywall needs one too)*
- ✅ **One access check, two ways in.** Build a single `hasAccess` check that a subscription unlocks today, and that an agency or employer access code can unlock later. Then the work isn't wasted if employers end up paying instead of workers. *(`AppManager.hasAccess` gates review, voices and the daily limit; for now it's always `false`)*
- ⬜ **to do** **Sandbox only for now.** *(Applies once the paywall is built; no StoreKit products exist in the project yet)* Develop against a local StoreKit configuration file or the sandbox. **Don't create live in-app products in your own App Store Connect account yet.** The plan is to publish from Auxility's account, and we'll set that up when our agreement is in place. Moving live products between accounts later is painful.

### 4.4 Before anyone outside your circle installs it

| What | Why |
|---|---|
| ❓ **need discussion** Get the OpenAI key off the phone (a server function), or remove OpenAI from the app entirely if we switch to pre-created packs (§5) | Any key inside an app can be extracted. Let's settle the packs question (§8) first, so you don't build a server you won't need *(Plan: move AI calls and Firestore reads and writes into Firebase Cloud Functions, and enforce the daily limit there too)* |
| ❓ **need discussion** Firebase: sign-in, read-only rules for the shared word bank, App Check | Today any phone can overwrite words and pictures that every user sees *(Deferred to the Cloud Functions move; anonymous sign-in is the likely path, since there's no user model)* |
| ❓ **need discussion** A real privacy policy and terms of use | Required by App Review, by the paywall and by the consent step |
| ⬜ **to do** Crash reporting and basic analytics: onboarding finished, round finished, paywall shown, trial started | Without them we can't tell whether onboarding or the paywall works *(Not started: the app links only FirebaseCore, Firestore and Storage, with no Crashlytics or Analytics)* |
| ✅ App icon; a realistic minimum iOS (26.0 is a settings change, older needs fallbacks for the glass effects); iPhone locked to portrait | Install base, store listing and the landscape layout problem *(Icon set; minimum iOS 18.0 with glass fallbacks in `ButtonModifier.swift`; portrait only)* |

## 5. ❓ **need discussion** The question behind the content: pre-created packs instead of live AI

Today the app asks AI for new words, and draws new pictures, while people play. An alternative is **pre-created packs**:
- one job and one language pair per pack, for example warehouse work, Ukrainian → Polish;
- about 100 words, 50 phrases and 20 safety commands;
- each item with native audio, a short explanation in the learner's language, and one picture;
- AI drafts each pack once, native speakers check it, and it ships as data.

**Why packs are worth considering:**
- **Cost.** A 150-picture pack costs about $0.75–5.40 once, instead of paying for every new word list each user plays.
- **Speed.** No live generation means no waiting and fewer loading screens.
- **Safety and quality.** No OpenAI key in the app, no shared database writes, and native speakers check every word. Eleven of today's open issues and risks would disappear.
- **The tradeoff.** "Any job you type" becomes "pick from our job packs". A middle ground: packs for the most common jobs, and live generation, done once on a server and cached, only for jobs we don't have yet.

Everything in §4 carries over either way: onboarding, settings and the paywall don't depend on where the words come from. If we go with packs, the app would also need:
- ❓ **need discussion** a pack reader that loads JSON, audio and pictures, and works offline;
- ❓ **need discussion** a listening exercise: hear it, pick the picture;
- ❓ **need discussion** phrase cards with audio.

**A sketch of the pack format:**

```json
{
  "kitId": "pl-warehouse-uk",
  "version": "1.0.0",
  "learnerLanguage": "uk-UA",
  "targetLanguage": "pl-PL",
  "verifiedBy": ["native Polish reviewer", "native Ukrainian reviewer"],
  "items": [
    {
      "id": "c001",
      "type": "command",
      "safetyCritical": true,
      "target": "Uwaga, wózek!",
      "learner": "Обережно, навантажувач!",
      "note": { "uk-UA": "Кричать, коли поруч їде вилковий навантажувач. Відійдіть убік." },
      "image": "images/forklift.webp",
      "audio": { "target": "audio/c001-pl.m4a" }
    },
    {
      "id": "w001",
      "type": "word",
      "target": "paleta",
      "learner": "піддон",
      "grammar": { "gender": "f", "plural": "palety" },
      "example": { "target": "Postaw paletę tutaj.", "learner": "Постав піддон сюди." },
      "image": "images/pallet.webp",
      "audio": { "target": "audio/w001-pl.m4a" }
    }
  ]
}
```

## 6. How we'll work together

| When | What happens |
|---|---|
| ❓ **need discussion** This week | We talk this through, including your answers to §8 |
| ✅ *(partly)* Next 2 weeks | §3 fixes, then onboarding (§4.1) and settings (§4.2) *(7 of 8 §3 fixes done; Settings mostly done; onboarding is missing the reminder and consent steps)* |
| ⬜ **to do** Following 1–2 weeks | The paywall in sandbox (§4.3), plus crash reporting and analytics |
| ❓ **need discussion** Once the packs question is settled | The §4.4 security work, in whichever form we choose |
| ❓ **need discussion** Every week | A short update from you: what shipped, what's blocked. You get feedback on each build |

We may also check with Polish work agencies whether they would pay for pre-created job packs for their new workers. If they would, it changes who pays, and the access-code path in §4.3 makes sure your paywall work still counts.

**First refusal is yours, in writing.** If we build an agency or pack version of this app, you get the first chance to build it, on terms covering your hours, IP and the Android plan.

## 7. What "finished" means

| | First external test (TestFlight) | Public App Store release |
|---|---|---|
| ⬜ **to do** Onboarding | The full flow in §4.1 | The same, polished, plus store screenshots |
| ⬜ **to do** Settings | The full screen in §4.2 *(only the reminder is missing; legal links and delete data need discussion)* | The same |
| ⬜ **to do** Paywall | Subscription in sandbox, with an access-code path ready | Live products in Auxility's account, prices tuned with data |
| ⬜ **to do** Engagement | Daily reminder at a chosen time; missed-word review *(the missed-word review is done; the reminder isn't)* | Plus streaks and a weekly recap |
| ✅ Loading | Clear progress and error states (mostly done) *(progress ring, retry-or-exit error screen, earlier prefetch)* | Polished, or largely unnecessary with packs |
| ❓ **need discussion** Design | One consistent design pass over all screens *(glass buttons with iOS 18 fallbacks are shared across screens; whether that counts as the design pass needs a review)* | Full design system |
| ❓ **need discussion** Always required | No API key in the app, locked-down Firebase, consent, a real privacy policy and terms, crash reporting and analytics | The same, plus account deletion if accounts exist, App Review compliance, and an Android plan |

## 8. Questions for you

1. ❓ **need discussion** **Why are the word lists and pictures generated live while people play, instead of pre-created as packs once?** Was there a reason, such as letting people type any job? Would you be open to packs, or to the middle ground in §5?
2. ❓ **need discussion** How many hours a week can you commit until mid-December?
3. ❓ **need discussion** Does your employment contract claim IP on side projects?
4. ❓ **need discussion** How would you handle Android: Flutter, native Kotlin, or a partner on Android while you own iOS?
5. ❓ **need discussion** Does the order in §6 work for you, or would you change it?

---

## 9. Summary (10 October)

### ⬜ Remaining: to do

1. ⬜ **Daily reminder.** Pick a time and ask for notification permission in onboarding, then an on/off and time setting in Settings. *(§4.1 #4, §4.2, §7)*
2. ⬜ **Multi-step onboarding** with back and skip. Today it's a single setup screen. *(§2, §4.1)*
3. ⬜ **Paywall.** RevenueCat on StoreKit; the paywall screen after the first completed round, showing price, period, what's included and the auto-renewal terms; Restore Purchases on the paywall too; a local StoreKit or sandbox setup with no live products. *(§2, §4.3, §7)*
4. ⬜ **Crash reporting and analytics**, with the events: onboarding finished, round finished, paywall shown, trial started. *(§2, §4.4)*

### ❓ Remaining: need discussion

1. ❓ **Packs or live AI** (§5, §8 Q1). This decides items 2–5 below.
2. ❓ **Get the OpenAI key off the phone.** The plan is to move AI calls and Firestore reads and writes into Firebase Cloud Functions, with the daily limit enforced on the server. *(§2, §4.4)*
3. ❓ **Lock down Firebase:** anonymous sign-in, read-only rules for the shared word bank, App Check. *(§4.4)*
4. ❓ **Real privacy policy, terms of use and support email.** All are placeholders today, in `EntryView` and `SettingsView`. The paywall links depend on them too. *(§3 #1, §4.2, §4.3, §4.4)*
5. ❓ **Consent step:** a plain explanation that the job text goes to OpenAI, with an explicit "OK". *(§2, §4.1 #5)*
6. ❓ **Delete my data.** It's built but commented out in `SettingsView.swift:59` and `AppManager.swift`. *(§4.2)*
7. ❓ **Plans and prices:** monthly and annual, with a free trial. *(§4.3)*
8. ❓ **Design pass:** does the shared glass style count as the "one consistent design pass"? *(§7)*
9. ❓ **§8 Q2–Q5:** weekly hours until mid-December, IP clause, Android approach, the order in §6.
10. ❓ **Weekly update rhythm.** *(§6)*

### ✅ Completed

**§3 fixes (7 of 8)**
- ✅ The loading screen no longer sticks after a checkpoint (routes on `pendingAdvance`).
- ✅ "/" in word names: safe document IDs.
- ✅ Shuffle attempt cap for repeated-letter words.
- ✅ The seven English-only strings are localized; "Loading" and "%lld percent" have 54 translations each.
- ✅ `pickedLanguage` defaults to "en-US" in every view.
- ✅ Retry repeats what failed (`lastSession`).
- ✅ The 15 MB cat image is removed.

**Onboarding (§4.1)**
- ✅ Welcome text, language pickers, job menu with free text, straight into the first round.
- ✅ Shown once (`hasCompletedOnboarding`), with a welcome-back screen for returning users.
- ✅ Every string localized; languages change in Settings.

**Settings (§4.2)**
- ✅ Languages and job, with the per-language progress warning.
- ✅ Audio: speech speed and voice picker. Speech stays on demand; auto-play is left out on purpose.
- ✅ Reset progress with confirmation; manage subscription; Restore Purchases; app version.

**Paywall groundwork (§4.3)**
- ✅ Daily free limit: 20 words (2 rounds), stored in the Keychain and dated with internet time.
- ✅ A single `hasAccess` check, ready for a subscription or an access code.

**Release basics (§4.4, §7)**
- ✅ App icon, minimum iOS 18.0 with glass fallbacks, portrait only.
- ✅ Loading and error states: a progress ring and the retry-or-exit screen.

**Also fixed on 9 October (not in the original list)**
- ✅ Struggle review: the Firestore lookup is split into groups of 30 (the old single query failed past 30 words), and each review is capped at the 10 weakest words.
- ✅ Results screen at the daily limit: a lock icon and alert instead of a silent jump to the welcome screen.
- ✅ Mid-round loading screens: the next batch now starts loading with 3 words left instead of 2.
- ✅ A short first batch (3 words or fewer) starts loading the next one right away.
- ✅ The duplicate `onResume` call after Continue is removed.
- ✅ Error recovery: each `GenerationError` has a recovery type (retry, wait for connection, change profession, none), and `ErrorView` shows the buttons that match it. 4xx responses (except 408/429) become `.serviceUnavailable`, and 401s are no longer retried.
- ✅ Offline screen with automatic retry, also used when a fetch fails mid-session.
- ✅ Two loads can no longer run at once (`startGame` and `startStruggleReview` are guarded).

**Also done on 10 October (not in the original list)**
- ✅ Sound effects through a new `SoundManager`: letter taps, a success sound for correct answers, and a notification sound on every alert.
- ✅ All 54 localized languages are now listed in the project's known regions.
