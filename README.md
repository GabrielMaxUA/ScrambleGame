# LearnScrumble — developer notes

iOS app (SwiftUI, iOS 18+) that teaches the words people use at work, with words and pictures made by AI.
Plans and status live in `Docs/` (`checklist.md`, `ServerMigrationPlan.md`, `AppStoreReadiness.md`, `AppFlowIdeas.md`).
The website is in `WebsiteContent/` (its own README).

## First setup on a new Mac

Two things are **not in git** and must be added by hand, or the build or the game fails:

1. **Firebase plists**, both named `GoogleService-Info.plist` (ignored by `.gitignore`):
   ```
   FirebaseConfig/Dev/GoogleService-Info.plist    ← project scrumblegame-dev
   FirebaseConfig/Prod/GoogleService-Info.plist   ← project scrumblegame
   ```
   Copy them from a backup, or download them again: Firebase console → project → ⚙️ Project settings → your iOS app.
2. **The OpenAI key**: paste it into `apiKey` in `LearnScrumble/Services/RequestModel.swift`.
   **Never commit that file while the key is in it.** Add files to a commit by name. (The key moves to the server later, see `ServerMigrationPlan.md` Phase 5.)

## Dev and production

| You press | Build | Firebase project | Pictures bucket |
|---|---|---|---|
| ▶︎ Run | Debug | `scrumblegame-dev` | dev default bucket |
| Product → Archive | Release | `scrumblegame` | `gs://scrumblegame-tools` |

- The **Copy Firebase plist** build phase copies the right plist into the app; `FirebaseImageStore` picks the bucket with `#if DEBUG`.
- To fill the **production** word bank while playing: Edit Scheme → Run → Build Configuration → **Release**. Switch back to Debug for coding.
- `LearnScrumble/` is a synced folder: every file in it goes into the app. Keep config files outside it.
  That's why the planning docs live in `Docs/` at the repository root: in the repo for everyone, never inside the app.

## Testing tricks

**Reset the 20 free words a day.** The counter lives in the Keychain, which survives deleting the app.
- Easiest: **Settings → Debug → Reset free words** (Debug builds only, `#if DEBUG`; never in App Store builds).
- Or, for the simulator's whole Keychain, in Terminal:
  ```bash
  xcrun simctl keychain booted reset
  ```

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
1. Add a temporary button inside `#if DEBUG` that calls `fatalError("Test crash")`.
2. Stop Xcode, open the app from the simulator icon (a crash isn't recorded while the debugger is attached), crash it.
3. Open the app again and leave it open for a minute; the report is sent on that launch.
4. Debug builds only: Crashlytics → dSYMs shows "Missing (required)". Zip `LearnScrumble.app.dSYM` from DerivedData (`Build/Products/Debug-iphonesimulator`) and drag it onto that page. Release builds upload it by themselves.
5. Remove the button.

## Git

- Work on `main` while the app isn't in the App Store yet. Once it's live, use a branch per feature so `main` stays shippable.
- On another Mac: Xcode → Integrate → **Pull** to get the latest commits.
