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
   - `LearnScrumble/Views/SettingsView.swift` → `privacyURL`, `termsURL`, `supportEmail`

## Preview and publish

- **Preview:** open `index.html` in a browser, or run `python3 -m http.server 8000` in this folder and visit http://localhost:8000.
- **Publish:** any static host works. Since the app already uses Firebase, **Firebase Hosting** is the easiest: `firebase init hosting` (public directory: `WebsiteContent`), then `firebase deploy --only hosting`. GitHub Pages or Netlify also work.

## Keep the privacy page in sync with the app

`privacy.html` is based on what the code does today:

| Data | Where it goes |
|---|---|
| Languages, profession, speech speed, voice per language, reminder on/off + time, setup/tutorial flags | iPhone only (UserDefaults) |
| Answers per word: English name, language, right/wrong counts, last answered | iPhone only (SwiftData) |
| Daily free-word counter: day, count, latest date seen | iPhone only (Keychain — survives deleting the app) |
| Daily reminders | Scheduled locally by iOS, no server |
| Profession, both languages, already-practised word names, picture descriptions | OpenAI API (directly from the phone today) |
| New words (English name + 2 translations + picture link), new pictures | Google Firebase (Firestore + Storage), shared library, no user ID |
| Time check | `HEAD https://www.apple.com` |
| Purchases | Apple App Store (StoreKit) |

**Update the policy before shipping** any of these (all planned in `LearnScrumble/AppFlowIdeas.md`): Crashlytics/Analytics, Cloud Functions (OpenAI calls through our server), anonymous sign-in/App Check, RevenueCat, business access codes, a Report button.

## App Store privacy questions (suggestion)

Apple asks what data the app "collects" (sends off the device and keeps longer than needed to answer the request). Based on the table above, a reasonable starting point — confirm with whoever signs off the release:

- **Tracking:** No.
- **Data linked to the user:** None (no account, no identifiers).
- **Data not linked to the user:**
  - *User Content → Other User Content*: the profession text and the list of practised words sent to OpenAI to generate words — purpose: App Functionality.
- On-device data (settings, progress, Keychain counter) is not "collected" because it never leaves the device.
- Purchases are handled by Apple and aren't declared by the app.

Revisit these answers whenever the table changes (for example, Crashlytics adds Diagnostics → Crash Data).

## Screenshots

`images/how-to-play/*.jpg` were taken from the app's own tutorial in the iOS Simulator (English UI, learning Polish, iPhone 17), resized to 600 px wide. Retake them when the tutorial or the design changes.
