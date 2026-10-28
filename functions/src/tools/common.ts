// common.ts — what the one-off tools in this folder share (splitSharedWords.ts, checkTranslations.ts).
// They run from a Mac with `node lib/tools/<tool>.js --project <project> [...]`, never as Cloud Functions.
//
//   options()             -> --project (required), --apply, --word, --limit, --lang from the command line
//   configureFirebase()   -> project + Storage bucket in the environment, BEFORE store.ts is imported
//   openAIKey()           -> the functions' own OPENAI_API_KEY from Secret Manager (Firebase CLI)
//   planPath()            -> plans/<name>-<project>.json (not in git, not deployed)

import { execFileSync } from "node:child_process";
import * as path from "node:path";

export interface ToolOptions {
  project: string;            // scrumblegame-dev or scrumblegame
  apply: boolean;             // false = dry run: look and write the plan only
  word?: string;              // only this English word
  limit?: number;             // only the first N words
  lang?: string;              // only this language (checkTranslations)
}

// MARK: - options
// --project is required; the rest optional.
export function options(): ToolOptions {
  const args = process.argv.slice(2);
  const value = (name: string) => {
    const i = args.indexOf(name);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const project = value("--project");
  if (!project) throw new Error("Missing --project (scrumblegame-dev or scrumblegame)");
  const limit = value("--limit");
  return {
    project,
    apply: args.includes("--apply"),
    word: value("--word")?.toLowerCase(),
    limit: limit ? Number(limit) : undefined,
    lang: value("--lang"),
  };
}

// MARK: - configureFirebase
// The server code (store.ts) starts Firebase Admin when it's imported, with the project and default Storage bucket
// from the environment — set them here first. The bucket comes from the app's own GoogleService-Info.plist
// (production pictures go to "scrumblegame-tools" anyway, see store.ts pictureBucket). Credentials: your
// `gcloud auth application-default login`.
export function configureFirebase(project: string) {
  const env = project === "scrumblegame" ? "Prod" : "Dev";
  const plist = path.join(__dirname, "..", "..", "..", "FirebaseConfig", env, "GoogleService-Info.plist");
  const bucket = execFileSync("/usr/libexec/PlistBuddy", ["-c", "Print :STORAGE_BUCKET", plist]).toString().trim();
  process.env.GCLOUD_PROJECT = project;
  process.env.GOOGLE_CLOUD_PROJECT = project;
  process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: project, storageBucket: bucket });
}

// MARK: - openAIKey
// The same key the Cloud Functions use: Secret Manager's OPENAI_API_KEY in this project, fetched with the Firebase CLI
// (`firebase login` is enough, no separate gcloud login). Kept in memory only, never printed or written to a file.
export function openAIKey(project: string): string {
  if (process.env.OPENAI_API_KEY) return process.env.OPENAI_API_KEY;
  try {
    const key = execFileSync("firebase", ["functions:secrets:access", "OPENAI_API_KEY", "--project", project],
                             { stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
    if (key) return key;
  } catch { /* falls through to the error below */ }
  throw new Error(`Couldn't read OPENAI_API_KEY from Secret Manager in ${project}. Check \`firebase login\` and that you can open the project.`);
}

// MARK: - planPath
// Where a tool keeps its plan: functions/plans/<name>-<project>.json.
export const planPath = (name: string, project: string) =>
  path.join(__dirname, "..", "..", "plans", `${name}-${project}.json`);

// MARK: - run
// Starts a tool's main function; an error prints one line and exits with code 1.
export function run(main: () => Promise<void>) {
  main().catch((error) => {
    console.error(String(error instanceof Error ? error.message : error));
    process.exit(1);
  });
}
