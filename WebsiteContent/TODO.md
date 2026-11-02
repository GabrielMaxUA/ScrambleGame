# LearnScrumble website: what's left

*Created 18 October 2026. Tick items off (⬜ → ✅) as they're done. This file is not published: `firebase.json` skips every `.md` file in this folder.*

## Now: before the site counts as final

- ✅ *(1 November 2026)* **French version** of every page (`fr/`), EN | FR switch, provider policy links on the privacy page, deployed. ⬜ A French speaker's check of the translation.

- ✅ *(1 November 2026)* **Launched the final pages:** PawIT name, effective dates 1 November 2026, no postal address (email contact), the pronunciation test, the store button hidden until the app is live. Deployed with `firebase deploy --only hosting`.

- ✅ **Deploy the latest changes.** From the repository root: `firebase deploy --only hosting` (steps in `README.md`). *(28 October: deployed — the 27 October server changes plus the one-time unlocks, My words, the Report flag and no typed jobs.)*
- ✅ *(1 November 2026: `www` redirects to `https://learnscrumble.com`)* **`www.learnscrumble.com` → Connected.** Namecheap must show CNAME `www` → `scrumblegame.web.app.`; then Firebase → Hosting → ⋮ next to `www` → Verify. `learnscrumble.com` is already Connected with HTTPS (18 October).
- ✅ *(1 November 2026: all five pages answer 200, `www` → 301 to the main address)* **Test after `www` connects:** `https://learnscrumble.com` (padlock), `www.learnscrumble.com` (redirects to it), every page and the menu on a phone, and an email to support@learnscrumble.com still arrives.
- ⬜ **Fill the remaining yellow placeholders** (`grep -n 'class="fill"' *.html`):
  - ✅ *(1 November 2026)* Developer or company name: **Max Gabriel, sole proprietor operating as PawIT** (CRA registration active 1 November) — privacy §1 and contact, terms intro and §13, footer "© 2026 PawIT (Max Gabriel)" on every page.
  - ✅ *(1 November 2026)* Postal address: left out on purpose — contact by email (support@learnscrumble.com), "Ontario, Canada".
  - ⬜ Business Number (CRA) on the pages: not required for a sole proprietor; add it to privacy §1 only if you want to.
  - ✅ *(1 November 2026)* Effective dates: 1 November 2026 (the day the pages went live).
  - ✅ *(1 November 2026)* Minimum age 16 confirmed (privacy §10 "Children"). No postal address on purpose (email contact).
  - ⬜ Governing law (terms §11): your country, or Auxility's if the app is published from their account — ask Konstantin.

## Consoles: make the policy's promises true

The privacy page now says these are in place, so they have to be:

- ✅ *(1 November 2026)* **Firebase:** no accept button any more — Project settings → Data privacy has only the Service Data setting and Privacy representatives (none needed). Google's Firebase Data Processing and Security Terms, with the Standard Contractual Clauses, apply to every project automatically. Unticked "Let Google use your Firebase Service Data… non-Firebase services" (optional, privacy-friendly).
- ✅ *(1 November 2026)* **OpenAI:** nothing to sign — the Data Processing Addendum effective 1 January 2026 "supplements, and is incorporated into" the OpenAI Services Agreement, so it (with its Standard Contractual Clauses) applies to every API customer automatically. PDF kept for the records (optional).
- ✅ *(1 November 2026)* **Google Analytics:** Admin → Data collection and modification → Data retention: event data **2 months**, user data **2 months**, "Reset on new user activity" off (the privacy page says 2 months).

## Before App Review

- ⬜ **Retake `images/how-to-play/08-settings.jpg`** (tutorial step 7): since 1 November the tutorial points at the back arrow, not the gear; the page text and alt text already say so. Then raise its `?v=`.
- ✅ *(1 November 2026)* **Start screen screenshot:** replaced by `images/app/start-screen.jpg` (three cards with rings); the unused `progress.jpg`, `report-picture.jpg` and `how-to-play/10-lets-go.jpg` were deleted (`10-next.jpg` replaces the last).
- ✅ *(1 November 2026, deployed)* **Listening test, Test all, tutorial test pages and word reports** on the pages: how-to-play (two new tutorial steps, start screen, Test all step), support FAQ (listening test, Test all, wrong word in the app), home cards, privacy (listening results, word reports) — EN and FR.
- ✅ *(1 November 2026, not deployed)* **Pronunciation test** on the pages: privacy §2 (results on the phone), §3 (Apple speech recognition, microphone), §4, §5, §6 and the summary box; terms §1, §3 and §4; support FAQ (how it works, unsupported languages, "Do you record my voice?", My words' big card); home page cards; how-to-play (start screen, back arrow, pronunciation card).

- ✅ **Paywall.** *(28 October: built as one-time profession unlocks, $9.99, after 10 free words once. `terms.html` §4–5, `support.html` ("Free words and unlocking a profession"), `index.html` ("Try 10 words free") and `how-to-play.html` match it. The 32 products still have to be created in App Store Connect with the IDs from `StoreKit/LearnScrumble.storekit`.)*
- ✅ *(28 October)* **Retake `images/how-to-play/10-lets-go.jpg`**: the app's note now says "You get 10 free words to try the app." (then raise its `?v=` in `how-to-play.html`).
- ⬜ **App Store button** (`index.html`): Apple's official "Download on the App Store" badge (Apple Marketing Resources, not a home-made button, not the app icon), linked to the app's App Store page once it exists in App Store Connect.
- ⬜ **Legal review** of `privacy.html` and `terms.html` by someone qualified (GDPR, EU consumer law). They match the app as of 18 October 2026 but are drafts, not legal advice.
- ⬜ **App Store Connect privacy answers:** enter them from "App Store privacy questions" in `README.md` (they match `PrivacyInfo.xcprivacy`, including Other Diagnostic Data and, since 27 October, User ID).
- ⬜ **App Store Connect URLs:** Privacy Policy URL `https://learnscrumble.com/privacy`, Support URL `https://learnscrumble.com/support`, Marketing URL `https://learnscrumble.com`.

## When the app changes: update the pages in the same commit

| If the app… | Update |
|---|---|
| adds **ads** | Privacy (§3 new provider, §4 "no ads/no tracking" goes), terms, support FAQ, `PrivacyInfo.xcprivacy`, App Store answers; probably Apple's tracking (ATT) popup and an EU consent screen. Big change: plan it before the ads SDK goes in. |
| changes the **free words**, the **price** or what an unlock includes | `terms.html` §4–5, `support.html`, `index.html`, `how-to-play.html` (last step) |
| brings back **typed jobs** ("Not listed?") | `privacy.html` §2–3 (typed job, its English name, moderation — see the comment at the top), `support.html` "My job isn't in the list", `index.html`, `terms.html` §6 |
| adds a **free trial** | `terms.html` §5 (trial line was removed on 18 October because there's no trial) |
| ✅ moves **OpenAI calls to the server** / adds **anonymous sign-in** or **App Check** (the server migration plan, removed 30 Oct 2026) | *Done 27 October:* privacy §3–6 and §10, support FAQ, manifest (User ID), App Store answers in `README.md` (confirm "linked" vs "not linked" at sign-off) |
| starts **enforcing the free words on the server** | Privacy §3 (sign-in ID and daily count), terms §4 |
| changes the **consent text** (`AIConsent.message`) | `support.html` "Why do I have to agree", privacy §3 "We ask first" |
| sends **new data** anywhere, or adds an SDK | Privacy §3 + §4, manifest, App Store answers |
| changes **Settings menu names** or the tutorial | `support.html`, `how-to-play.html` |
| changes the **pronunciation test** (what's sent, where it runs, who can use it) | `privacy.html` §2–6, `terms.html` §1, §3–4, `support.html` pronunciation FAQ, the App Store answers in `README.md` |

## Nice to have

- ⬜ Real screenshots on the home page.
- ⬜ A "Help & FAQ" row in the app's Settings linking to `https://learnscrumble.com/support` (`AppLinks.support` is already there).
- ⬜ Automatic deploys from GitHub (merge to `main` publishes, PRs get preview links), once several people edit the site.
