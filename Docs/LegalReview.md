# LearnScrumble: legal check for Ontario, Canada (29 October 2026)

**Not legal advice.** This is a careful checklist made from the code, the website and the laws that usually apply to
a one-person app business in Ontario. Before launch, have an Ontario lawyer read `WebsiteContent/privacy.html`,
`terms.html` and this file. Cheap way: the Law Society of Ontario Referral Service (free first 30-minute consultation,
lso.ca).

**Status:** ✅ = done · ⬜ = to do · ❓ = decide

**Who sells the app:** Max Gabriel, individual Apple developer account, Ontario. The name on the website (your own name or
a business name) is decided later: every place is a yellow placeholder.

---

## 1. Laws that apply, and where we stand

| Law | What it asks | Status |
|---|---|---|
| **PIPEDA** (federal privacy law; Ontario has no private-sector law of its own) | An accountable person (privacy officer), clear purposes, meaningful consent, collect only what's needed, safeguards, access to your data within 30 days, a record of every breach and reporting serious ones to the Privacy Commissioner | ✅ privacy page rewritten (29 Oct). ⬜ fill the privacy officer's name. ⬜ keep a breach record (section 3) |
| **Québec Law 25** (the app is sold in Québec too) | A named person in charge of privacy, telling people their data leaves Québec, a privacy impact assessment before sending data outside Québec, privacy-friendly defaults | ✅ page says it; statistics are off by default. ⬜ the short assessment (section 3) |
| **Charter of the French Language** (Québec, Bill 96) | Consumer contracts (our Terms) and the privacy policy given in French to Québec users; the app available in French | ✅ app has French. ⬜ **French Terms and Privacy pages** (section 4) |
| **Ontario Consumer Protection Act** | No forced arbitration and no class-action waiver for consumers; consumer rights can't be signed away; the extra internet-agreement rules apply only above $50 (our price is $9.99) | ✅ terms rewritten (29 Oct). ❓ the new Consumer Protection Act, 2023 replaces it when it comes into force: ask the lawyer whether it's in force at launch |
| **Competition Act** (misleading advertising) | Claims must be true in their general impression ("unlimited", "free") | ✅ no "unlimited" anywhere (30 Oct): app, website and terms say "the most-used workplace words for this profession", that each list has an end (usually a few hundred words, at most 500) and that new pictures are limited to 100 a day — shown on the setup screen, the paywall and right after buying |
| **CASL** (anti-spam) | Consent before any marketing email or message | ✅ none sent. Don't add a newsletter without opt-in consent |
| **GDPR / UK GDPR** (EU and UK users) | Legal bases, rights, transfer safeguards | ✅ kept in the privacy page. ⬜ accept the Firebase and OpenAI data processing terms (`WebsiteContent/TODO.md`) |
| **Business Names Act** (Ontario) | Register a name you do business under if it isn't your own legal name | ❓ if the seller or website shows "LearnScrumble" (not "Max Gabriel"), register it with ServiceOntario (about $60 for 5 years) |
| **Tax** (CRA) | Business income on your T1 (form T2125); GST/HST registration (required above $30,000 a year, Apple's form needs a Business Number) | ⬜ CRA Business Number (`remaining.md` §1). Apple collects the sales tax from buyers. Ask an accountant once |
| **AODA** (Ontario accessibility) | Customer-service rules once you have employees | ✅ not applicable now (no employees) |

## 2. Changes in the app

- ✅ **Consent sentence** (`AIConsent.message`, setup screen, consent sheet, Settings): "…are sent to OpenAI. This
  data is processed in the United States." (PIPEDA and Law 25 transparency; all 53 languages, 29 October.)
- ✅ **Paywall** (`PaywallView.swift:47`): "The most-used workplace words for this profession" (30 October; before:
  "No word limit", before that "Unlimited words and pictures"), plus small print above the button: "Each profession
  has its own vocabulary, usually a few hundred words. Up to 100 new pictures a day." The same on the website and in
  the terms (§5). (Competition Act; all 53 languages.)
- ⬜ *(recommended)* **Paywall:** small "Terms of Use · Privacy Policy" links under the button, so the terms are
  visible before buying. Apple doesn't require it for one-time purchases, but consumer law likes it.
- ⬜ **French links:** once French pages exist, the app opens them when the app language is French (`AppLinks.swift`).
- ✅ *(30 October)* The limits before and after buying: the setup screen ("Up to 100 new pictures a day." and a Terms of
  Use link), the paywall small print, the "Unlocked! 🎉" confirmation after buying or restoring, and clear messages
  when a profession's list is played to the end or the daily limit is reached.
- ✅ Consent before OpenAI, statistics off by default, no tracking, no ads, Restore purchases, the safety
  disclaimer ("not safety training"), the AI disclaimer, a report flag for pictures.

## 3. Privacy paperwork (you keep it, nobody publishes it)

- ⬜ **Privacy officer:** you ("[Your name], owner" in `privacy.html` §1 and §12).
- ⬜ **Breach record:** a simple document: date, what happened, data involved, people affected, what was done, whether
  the Privacy Commissioner was told. PIPEDA asks to keep it 24 months. Even "no breaches" is fine to start.
- ⬜ **Privacy impact assessment for Québec** (Law 25, data sent to the United States): one or two pages — what goes
  to Google and OpenAI, why, how it's protected (their data processing terms, encryption, minimum data). I can draft
  it.
- ⬜ **Retention promises:** delete support emails after 12 months (privacy page §6 says so).
- ⬜ **Requests:** answer privacy emails within 30 days.

## 4. French versions (Québec)

- ⬜ `WebsiteContent/fr/privacy.html` and `fr/terms.html` (and ideally support), a language switch on the pages, and
  the app linking to them in French. A machine translation is a start; have the French checked (the lawyer, or a
  Québec translator) because the French version of a consumer contract counts.

## 5. Before you sign anything with your name

- ❓ **Name on the website and in the App Store:** your own name ("Max Gabriel") needs no registration; a business
  name ("LearnScrumble") needs the Ontario business name registration first. The App Store already shows your legal
  name as the seller (individual account).
- ❓ **Personal liability:** as a sole proprietor you are personally responsible. The terms limit liability as far as
  the law allows; a corporation or business insurance gives more protection. Ask the lawyer or an accountant.
- ⬜ *(optional)* Trademark search for "LearnScrumble" on the Canadian (CIPO) and U.S. (USPTO) databases before launch.

## 6. Website changes made on 29 October (not deployed yet)

- `privacy.html`: Ontario/Canada as the home of the business; PIPEDA accountability and the person in charge of
  privacy; consent in Canada (express for OpenAI and statistics, implied for what the app needs); U.S. storage and
  foreign-authority access notice; Québec information; rights for Canada, Québec and the EU/UK; answer within 30
  days; complaints to the Privacy Commissioner of Canada and the CAI (the Polish authority removed); new section
  "Security and data breaches"; children and changes updated.
- `terms.html`: Ontario law and Canadian federal law; consumer rights kept, no arbitration, no class-action waiver;
  taxes charged by Apple; "no limit set by us" explained; 30 days' notice of important changes and of a shutdown;
  unlocked professions are never taken away by a change.
- `support.html`: "How do I ask what data you have about me, or make a privacy complaint?"; the profession's word list
  and the 100-pictures-a-day limit (30 October).
- `index.html`: "the most-used workplace words of that profession" instead of "unlimited words" (30 October).
- Placeholders left on purpose (29 October): **only** `[Developer or company name]`, `[Your name]`, `[Postal address]`
  and the effective date `[DD Month YYYY]` (= the day the final pages are published). Minimum age is 16; the business
  number line is removed (a sole proprietor doesn't need to show one). The App Store button on the home page waits for
  the app's store link.
- Publish after review: `firebase deploy --only hosting` from the repository root.
