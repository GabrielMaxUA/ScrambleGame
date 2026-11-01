# Privacy impact assessment: communicating personal information outside Québec

*Évaluation des facteurs relatifs à la vie privée (EFVP) — Québec, Act respecting the protection of personal information
in the private sector, s. 17 (as amended by Law 25).*

**Organization:** Max Gabriel, sole proprietor operating as PawIT (Ontario, Canada) · **App:** LearnScrumble (iOS)
**Person in charge of the protection of personal information:** Max Gabriel, support@learnscrumble.com
**Date:** 1 November 2026 · **Review:** before any change to what the app sends, and at least once a year.

This is an internal document. It isn't published; the privacy policy (`WebsiteContent/privacy.html` §7, French
`fr/privacy.html` §7) says the assessment was done. Show it to the Commission d'accès à l'information if it asks.

## 1. What leaves Québec, to whom, and why

| Recipient (country) | What is communicated | Purpose |
|---|---|---|
| Google LLC — Firebase Cloud Functions, Firestore, Storage, Authentication, App Check (United States) | Job from the menu, the two languages, English names of practised words, picture reports (word + job + picture link), a random anonymous sign-in ID with two daily counters, IP address and technical data needed to serve requests | Run the service: create and reuse words and pictures, limit misuse |
| OpenAI, L.L.C. (United States), through our server only | Job, the two languages, English names of practised words, short picture descriptions | Create words, translations and pictures (only after the user's express "I agree") |
| Google — Firebase Crashlytics (United States) | Crash and error reports: code location, error type, the two languages, last technical steps, device model, OS and app version, random installation ID | Find and fix bugs |
| Google — Analytics for Firebase (United States) | Only if the user switches statistics on: app events, the two languages, the job, device and approximate country, random app-instance ID | Improve the app |
| Apple (United States / Ireland) | Pronunciation test audio, if iOS uses Apple's servers for recognition; App Store purchases | Speech recognition; payments (Apple acts under its own policy) |

Not communicated: name, email, phone, Apple ID, location, contacts, photos, advertising ID, recordings or recognised
text (never sent to us), progress and My words (stay on the phone).

## 2. Sensitivity of the information

**Low.** No information identifies the user by name; the job and languages are not "sensitive information" in the
sense of the Act (no health, biometric, financial or ethnic data). Speech audio could be biometric in theory, but the
app doesn't keep it, never receives it, and doesn't use it to identify anyone; recognition is done by Apple under the
user's own iOS permission.

## 3. Purposes

Each communication is necessary for a feature the user asked for (words and pictures, the shared word library, the
pronunciation test) or to keep the service working and secure (sign-in ID, App Check, limits, crash reports).
Statistics are optional and off by default. No other use, no sale, no advertising, no profiling.

## 4. Protection measures (including contractual)

- **Google:** Firebase Data Processing and Security Terms (apply automatically to every project; include the
  European Commission's Standard Contractual Clauses); Google is certified under the EU–U.S. Data Privacy Framework.
  "Let Google use your Firebase Service Data for non-Firebase services" switched off (1 November 2026).
- **OpenAI:** Data Processing Addendum effective 1 January 2026, incorporated into the OpenAI Services Agreement;
  API data not used for training by default; retained up to 30 days for abuse monitoring.
- **Apple:** Apple's privacy policy; the user grants microphone and speech-recognition permission in iOS and can
  withdraw it at any time.
- **Technical:** HTTPS everywhere; phones can't read or write the database; OpenAI key in Google Secret Manager;
  App Check (App Attest) so only the genuine app can call the server; anonymous IDs deleted after 30 days;
  Analytics data kept 2 months; Crashlytics 90 days; access to the consoles limited to the owner.
- **Minimisation:** the server sends OpenAI only the items above, never the sign-in ID or device identifiers; OpenAI
  sees the server's IP address, not the user's.

## 5. Legal framework of the destination (United States)

Data in the United States can be accessed by U.S. courts, law enforcement and national-security authorities under
U.S. law. The risk is limited because the information doesn't identify users by name, is minimal, and the providers'
contractual commitments restrict their own use. Users are told about the U.S. location before agreeing (setup screen,
privacy policy §7, in French and English).

## 6. Conclusion

The information would receive **adequate protection**, in particular with regard to generally recognised principles
of personal information protection. The communication may proceed under the written agreements listed in §4.

**Signed:** Max Gabriel, person in charge of the protection of personal information · 1 November 2026
