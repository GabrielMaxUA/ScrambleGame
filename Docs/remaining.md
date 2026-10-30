# LearnScrumble: what's left before the App Store (29 October 2026)

**Status:** ✅ = done · ⬜ = to do · ❓ = decide
Work top to bottom. Tick items off as they're done. Details are in `AppStoreReadiness.md`, `checklist.md`,
`WebsiteContent/TODO.md` and the README section "Release: App Store Connect and TestFlight".
The app is published from **Max's personal developer account** (individual, team `7XZJ4BCPR6`). The parts of the other
docs that mention Auxility or Konstantin no longer apply.

---

## 1. Account: Paid Apps Agreement (App Store Connect → Business)

Nothing can be bought, not even in TestFlight, until this agreement is **Active**.

- ✅ Paid Apps Agreement signed (29 October).
- ⬜ Bank account (RBC, CAD): wait for Apple to verify it.
- ⬜ W-8BEN: individual, Canada, SIN, treaty benefits.
- ⬜ **CRA Business Number** (sole proprietor, free, no company needed): register for GST/HST at CRA Business
  Registration Online. You get a BN + `RT0001`.
- ⬜ GST/HST Form 506 in App Store Connect with that number.
- ⬜ EU trader status (Digital Services Act): answer it.
- ⬜ App Store Small Business Program: apply (15% commission instead of 30%).

## 2. The 32 products (App Store Connect → the app → Monetization → In-App Purchases)

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

## 3. Server and security

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
  the website and terms say the same. ⬜ Deploy the functions; ⬜ a new TestFlight build (build 3) with the app part.
- ✅ *(30 October)* **App Store Connect:** the product **descriptions** said "Unlimited words, pictures and My words". Change every
  product already created to "Most-used work words, pictures and My words" (table below), and the review note.
- ⏸ **Later (decided 29 October): server checks who owns a job** (today only the phone checks). Not for 1.0:
  App Check and the picture cap keep the risk small. Options:
  - **Launch without it** (recommended for 1.0): App Check already blocks scripts and fake apps; only a hacked app on
    a jailbroken phone could skip the paywall, and most words come from the bank, so the cost is small.
  - **Later:** the app sends the App Store's signed purchase (`jwsRepresentation`) to a new function; the server checks
    it with Apple's `@apple/app-store-server-library`, remembers which jobs the user owns, and `getWords` refuses
    locked jobs after the 10 free words. About a day of work plus testing.

## 4. Website and legal (`WebsiteContent/TODO.md`, `LegalReview.md`)

- ✅ Privacy, terms, support and home pages updated for Ontario/Canada law (29 October, not deployed yet).
- ⬜ Everything open in `LegalReview.md`: privacy officer, breach record, Québec assessment, French pages, the app's
  consent and paywall wording, the business name decision, a lawyer's read.

- ⬜ Fill the yellow placeholders with **your own** details: name (Max Gabriel), postal address, effective dates,
  minimum age (16 suggested), governing law (Ontario, Canada). Then deploy: `firebase deploy --only hosting`.
- ⬜ Connect `www.learnscrumble.com` and test every page.
- ⬜ Firebase: accept the data processing terms. OpenAI: accept the Data Processing Addendum.
- ⬜ Legal review of `privacy.html` and `terms.html` (recommended).

## 5. App Store Connect: the app page

- ⬜ App Privacy answers (from `WebsiteContent/README.md`, the same as `PrivacyInfo.xcprivacy`).
- ⬜ Age rating questionnaire (answer the AI-generated-content questions honestly).
- ⬜ Store listing: subtitle, description, keywords, category Education, copyright "2026 Max Gabriel".
- ⬜ Screenshots: 6.9" iPhone (required).
- ⬜ URLs: Privacy `https://learnscrumble.com/privacy`, Support `https://learnscrumble.com/support`,
  Marketing `https://learnscrumble.com`.
- ⬜ Notes for the reviewer: the text is ready in `AppStoreReadiness.md` §2.3.

## 6. Testing

- ⬜ Update to Xcode 27.1 and check the app on the **iPhone Duo** simulator (all poses).
- ⬜ TestFlight round on a real iPhone, once section 1 is Active: free words → paywall → sandbox purchase → more
  words, My words (also offline), Restore purchases, report a picture, reminder, offline screen, Settings.

## 7. Submit

- ⬜ A **normal** Product → Archive (not the tester script) with build 3 → upload → pick it on the version page.
- ⬜ Add the 32 products to the version → Submit for Review.

## Not needed for 1.0 (decided 29 October)

- **"Delete my data" in Settings:** Apple requires in-app deletion only when the app has accounts. LearnScrumble has
  none: progress lives on the phone (deleting the app removes it) and the anonymous ID is cleaned up by Firebase after
  30 days. Deletion requests go to support@learnscrumble.com. The code stays commented out for later.
- **Terms and Privacy links on the paywall:** Apple requires them only for subscriptions. The unlocks are one-time
  purchases, and the links are already in Settings and on the website.
- Weekly recap, a native-speaker check of the translations, "Not listed?" typed jobs: after launch.
