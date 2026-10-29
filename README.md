# LearnScrumble — developer notes

iOS app (SwiftUI, iOS 18+) that teaches the words people use at work, with words and pictures made by AI.
Plans and status live in `Docs/` (`checklist.md`, `ServerMigrationPlan.md`, `AppStoreReadiness.md`, `AppFlowIdeas.md`).
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
- The app calls the Cloud Functions of the project it's connected to (`getWords`, `getPicture`, `reportPicture`, region `us-central1`; `getReviewWords` is still deployed but no longer called), so dev builds use the dev functions and the dev word bank. Deploy function changes to `scrumblegame-dev` first (`functions/README.md`).
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

## Git

- Work on `main` while the app isn't in the App Store yet. Once it's live, use a branch per feature so `main` stays shippable.
- On another Mac: Xcode → Integrate → **Pull** to get the latest commits.
