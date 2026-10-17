# LearnScrumble website

Static support website for the app: plain HTML, one stylesheet and one small script. No build step, no framework.

## Pages

| File | What it is | Linked from the app |
|---|---|---|
| `index.html` | Home: what the app does, App Store button | — |
| `how-to-play.html` | The "How to play" tutorial step by step, with real screenshots (`images/how-to-play/`) | (could be linked from Settings → How to play later) |
| `support.html` | Contact + FAQ (reminders, languages, free words, subscriptions, voices, progress, data) | Settings → Contact support (email) |
| `privacy.html` | Privacy Policy — what the app stores on the iPhone and sends to OpenAI, Firebase and Apple | `EntryView.privacyURL`, `SettingsView.privacyURL` |
| `terms.html` | Terms of Use ("usage regulations") — service, not-safety-training, AI content, daily limit, subscriptions | `SettingsView.termsURL` (and the paywall later) |

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
4. **Update the app's links** once the site has a domain:
   - `LearnScrumble/Views/EntryView.swift` → `privacyURL`
   - `LearnScrumble/Views/ConsentSheet.swift` → `privacyURL`
   - `LearnScrumble/Views/SettingsView.swift` → `privacyURL`, `termsURL`, `supportEmail`

## Preview and publish

- **Preview:** open `index.html` in a browser, or run `python3 -m http.server 8000` in this folder and visit http://localhost:8000.
- **Publish:** any static host works. Since the app already uses Firebase, **Firebase Hosting** is the easiest: `firebase init hosting` (public directory: `WebsiteContent`), then `firebase deploy --only hosting`. GitHub Pages or Netlify also work.

## Keep the privacy page in sync with the app

`privacy.html` is based on what the code does today:

| Data | Where it goes |
|---|---|
| Languages, profession, speech speed, voice per language, reminder on/off + time, setup/tutorial flags, OpenAI agreement date, usage-statistics choice | iPhone only (UserDefaults) |
| Answers per word: English name, language, right/wrong counts, last answered | iPhone only (SwiftData) |
| Daily free-word counter: day, count, latest date seen | iPhone only (Keychain — survives deleting the app) |
| Daily reminders | Scheduled locally by iOS, no server |
| Profession, both languages, already-practised word names, picture descriptions | OpenAI API (directly from the phone today), only after the user ticks "I agree" (setup screen, or a one-time sheet for older installs) |
| Crash and error reports: where in the code, error type, the two chosen languages, the last app steps (`Log.info` / `Log.error` messages: steps and counts only; words and the profession are `private:` and never sent), device model, iOS/app version, random installation ID | Firebase Crashlytics, always on |
| Usage events, device model, iOS/app version, approximate country, random app-instance ID (no IDFA) | Google Analytics for Firebase, **only if** "Share usage statistics" is on (off by default; `FIREBASE_ANALYTICS_COLLECTION_ENABLED = NO` in `LearnScrumble-Info.plist`) |
| New words (English name + 2 translations + picture link), new pictures | Google Firebase (Firestore + Storage), shared library, no user ID |
| Job counts: English job name (menu name, or GPT's English name for a typed job; "invalid" isn't saved), typed/picked counts, first/last seen, review status | Google Firebase (Firestore `professions`), once per job per install, no user ID, never the typed text (`ProfessionStore`) |
| Time check | `HEAD https://www.apple.com` |
| Purchases | Apple App Store (StoreKit) |

**Update the policy before shipping** any of these (all planned in `Docs/AppFlowIdeas.md`): Cloud Functions (OpenAI calls through our server), anonymous sign-in/App Check, RevenueCat, business access codes, a Report button. *(Crashlytics, optional Analytics and the OpenAI consent were added to the policy on 15 October 2026.)*

## App Store privacy questions (suggestion)

Apple asks what data the app "collects" (sends off the device and keeps longer than needed to answer the request). Based on the table above, a reasonable starting point — confirm with whoever signs off the release:

- **Tracking:** No.
- **Data linked to the user:** None (no account; Firebase's random IDs aren't tied to a person).
- **Data not linked to the user** (the same as `LearnScrumble/PrivacyInfo.xcprivacy`):
  - *User Content → Other User Content*: the profession text sent to OpenAI — purposes: App Functionality, and Analytics (its English name is counted to improve the job menu).
  - *Usage Data → Other Usage Data*: the names of words already practised, sent to OpenAI so they aren't repeated — purpose: App Functionality.
  - *Diagnostics → Crash Data*: Crashlytics crash reports — purpose: App Functionality.
  - *Identifiers → Device ID*: Firebase's random installation / app-instance ID (not the advertising ID) — purposes: App Functionality, Analytics.
  - *Usage Data → Product Interaction*: Analytics events, only with the user's consent — purpose: Analytics.
- On-device data (settings, progress, Keychain counter) is not "collected" because it never leaves the device.
- Purchases are handled by Apple and aren't declared by the app.

Revisit these answers whenever the table changes (for example, anonymous sign-in or server-side limits may make some data "linked").

## Screenshots

`images/how-to-play/*.jpg` were taken from the app's own tutorial in the iOS Simulator (English UI, learning Polish, iPhone 17), resized to 600 px wide. Retake them when the tutorial or the design changes.
