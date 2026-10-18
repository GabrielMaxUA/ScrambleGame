# LearnScrumble website: what's left

*Created 18 October 2026. Tick items off (⬜ → ✅) as they're done. This file is not published: `firebase.json` skips every `.md` file in this folder.*

## Now: before the site counts as final

- ⬜ **Deploy the latest changes.** From the repository root: `firebase deploy --only hosting` (steps in `README.md`).
- ⬜ **`www.learnscrumble.com` → Connected.** Namecheap must show CNAME `www` → `scrumblegame.web.app.`; then Firebase → Hosting → ⋮ next to `www` → Verify. `learnscrumble.com` is already Connected with HTTPS (18 October).
- ⬜ **Test after `www` connects:** `https://learnscrumble.com` (padlock), `www.learnscrumble.com` (redirects to it), every page and the menu on a phone, and an email to support@learnscrumble.com still arrives.
- ⬜ **Fill the remaining yellow placeholders** (`grep -n 'class="fill"' *.html`):
  - ⬜ Developer or company name (footer of every page, privacy §1, terms intro and §13).
  - ⬜ Postal address (privacy §1 and §11, terms §13).
  - ⬜ Company registration number, if any (privacy §1).
  - ⬜ Effective dates (privacy and terms): the day the final version goes live.
  - ⬜ Minimum age (privacy §9): 16 is pre-filled as a suggestion; confirm it.
  - ⬜ Governing law (terms §11): your country, or Auxility's if the app is published from their account — ask Konstantin.

## Consoles: make the policy's promises true

The privacy page now says these are in place, so they have to be:

- ⬜ **Firebase:** Project settings → Privacy / Data processing terms → accept (puts Google's Standard Contractual Clauses in place).
- ⬜ **OpenAI:** accept the Data Processing Addendum (organization settings, or the form linked from openai.com/policies/data-processing-addendum). OpenAI's Standard Contractual Clauses only apply once it's accepted.
- ⬜ **Google Analytics:** Admin → Data retention → **2 months** (the privacy page says 2 months).

## Before App Review

- ⬜ **Paywall.** The terms, support page and home page describe buying, managing and restoring a subscription, and "20 free words a day". The paywall must exist before review, and if the free limit or what's paid changes, update `terms.html` §4–5, `support.html` ("Daily free words and subscription") and `index.html` ("Free every day") together.
- ⬜ **App Store button** (`index.html`): Apple's official "Download on the App Store" badge (Apple Marketing Resources, not a home-made button, not the app icon), linked to the app's App Store page once it exists in App Store Connect.
- ⬜ **Legal review** of `privacy.html` and `terms.html` by someone qualified (GDPR, EU consumer law). They match the app as of 18 October 2026 but are drafts, not legal advice.
- ⬜ **App Store Connect privacy answers:** enter them from "App Store privacy questions" in `README.md` (they match `PrivacyInfo.xcprivacy`, including Other Diagnostic Data).
- ⬜ **App Store Connect URLs:** Privacy Policy URL `https://learnscrumble.com/privacy`, Support URL `https://learnscrumble.com/support`, Marketing URL `https://learnscrumble.com`.

## When the app changes: update the pages in the same commit

| If the app… | Update |
|---|---|
| adds **ads** | Privacy (§3 new provider, §4 "no ads/no tracking" goes), terms, support FAQ, `PrivacyInfo.xcprivacy`, App Store answers; probably Apple's tracking (ATT) popup and an EU consent screen. Big change: plan it before the ads SDK goes in. |
| changes the **free limit** or what a subscription unlocks | `terms.html` §4–5, `support.html`, `index.html`, `how-to-play.html` (last step) |
| adds a **free trial** | `terms.html` §5 (trial line was removed on 18 October because there's no trial) |
| moves **OpenAI calls to the server** / adds **anonymous sign-in** or **App Check** (`Docs/ServerMigrationPlan.md`) | Privacy §3 and §10, manifest, App Store answers (an anonymous ID may make some data "linked") |
| changes the **consent text** (`AIConsent.message`) | `support.html` "Why do I have to agree", privacy §3 "We ask first" |
| sends **new data** anywhere, or adds an SDK | Privacy §3 + §4, manifest, App Store answers |
| changes **Settings menu names** or the tutorial | `support.html`, `how-to-play.html` |

## Nice to have

- ⬜ Real screenshots on the home page.
- ⬜ A "Help & FAQ" row in the app's Settings linking to `https://learnscrumble.com/support` (`AppLinks.support` is already there).
- ⬜ Automatic deploys from GitHub (merge to `main` publishes, PRs get preview links), once several people edit the site.
