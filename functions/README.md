# LearnScrumble Cloud Functions

Server code for the app (TypeScript, Node 22, region `us-central1`). The app calls these instead of OpenAI,
so the OpenAI key never ships inside the app and only the server writes to the shared word bank.
Plan and progress: `Docs/ServerMigrationPlan.md` (Phases 4–8).

| Function | What it does | Replaces in the app |
|---|---|---|
| `getWords` | Next batch for a job: word bank first, GPT only for the missing number; tags words with the job; counts the job | `RequestModel.nextBatch`, `generateUniqueWordList`, `FirebaseWordStore.saveIfNeeded`, `ProfessionStore` |
| `getPicture` | One word's picture: the stored one, or a new one (GPT → WebP → Storage → saved on the word) | `RequestModel.generateImage`, `FirebaseImageStore` |
| `getReviewWords` | Struggle review words with translations and picture links | `RequestModel.generateStruggleReview`'s Firestore read |

Files: `src/index.ts` (the three functions), `src/openai.ts` (all OpenAI calls), `src/store.ts` (Firestore + Storage),
`src/errors.ts` (error codes the app maps to `GenerationError`).

## Secret

The OpenAI key is in Google Secret Manager as `OPENAI_API_KEY` (projects `scrumblegame` and `scrumblegame-dev`).
Never put it in a file. To replace it: `firebase functions:secrets:set OPENAI_API_KEY --project <project>`,
then deploy again so the functions pick up the new version.

## Everyday commands (from this `functions/` folder)

```
npm install                      # once per Mac, and after package.json changes
npm run build                    # TypeScript -> lib/ (deploy does this by itself)
firebase deploy --only functions --project scrumblegame-dev    # test project first
firebase deploy --only functions --project scrumblegame        # production
firebase functions:log --project scrumblegame                  # recent logs (or Firebase console -> Functions -> Logs)
```

## Emulator (free, local, nothing real touched)

```
firebase emulators:start --only functions,firestore,storage,auth --project scrumblegame-dev
```
Emulator UI: http://localhost:4000. The functions in the emulator still call the real OpenAI API (costs money),
using the key from a local file `functions/.secret.local` with one line `OPENAI_API_KEY=...` — that file is
git-ignored; delete it when you're done.

## Notes

- App Check is in monitoring mode (`enforceAppCheck: false`). Switch to `true` in `src/index.ts` once the
  console shows almost all requests verified, and deploy.
- The 10 free words a day are counted per anonymous user (`usage/{uid}`) but not enforced yet: the server
  can't see subscriptions until the paywall exists.
- The first deploy to a project can fail for one function with "Build failed … An unexpected error occurred" (Cloud Build
  setting itself up). Deploy just that function again: `firebase deploy --only functions:<name> --project <project>`.
- The app needs nothing else: Firestore and Storage rules can stay closed to phones (`allow read, write: if false`),
  because the functions use the Admin SDK, which ignores rules.
- `gpt-image-1-mini` is marked deprecated by OpenAI: plan the replacement model before it's switched off.
