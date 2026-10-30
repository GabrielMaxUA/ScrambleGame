// errors.ts — one place that turns failures into the error codes the app understands.
//
// The app (RequestModel) maps these HttpsError codes back to its own GenerationError cases:
//   unavailable          -> serverBusy          (OpenAI 429 / 5xx after our retries — temporary)
//   deadline-exceeded    -> timedOut            (OpenAI took too long)
//   failed-precondition  -> serviceUnavailable  (OpenAI 4xx: key, billing or request problem — OUR side, retry won't help;
//                                               also OpenAI's 429 "insufficient_quota": the credits are used up)
//   internal             -> badResponse         (garbled reply from GPT)
//   not-found            -> noWordsAvailable    (nothing new for this job + language)
//   not-found "jobComplete"       -> jobComplete  (the player has played every word of a complete job; app 1.0 build 3+)
//   resource-exhausted "pictureLimit" -> dailyLimit (PICTURES_PER_DAY new pictures today; app 1.0 build 3+, older: busy)
//   invalid-argument     -> noWordsAvailable    (bad input, or the typed job text was refused by moderation)
//   unauthenticated      -> unknown             (no anonymous sign-in on the phone)
//   resource-exhausted   -> tooManyReports      (reportPicture: the user's reports for today are used up)
// The message is a short machine-readable reason, never user text.

import { HttpsError } from "firebase-functions/v2/https";

export const busy = () => new HttpsError("unavailable", "serverBusy");
export const timedOut = () => new HttpsError("deadline-exceeded", "timedOut");
export const serviceUnavailable = () => new HttpsError("failed-precondition", "serviceUnavailable");
// OpenAI's safety system refused a picture prompt: the same code for the app, marked so prepare.ts can skip the word.
export const pictureRefused = () => new HttpsError("failed-precondition", "serviceUnavailable", { safety: true });
export const isPictureRefused = (error: unknown) =>
  error instanceof HttpsError && (error.details as { safety?: boolean } | undefined)?.safety === true;
// OpenAI's credits are used up (429 "insufficient_quota"): not "busy", waiting won't help until credits are added.
// The app shows "We can't prepare new words right now"; prepare.ts pauses the queue instead of failing every job.
export const outOfCredits = () => new HttpsError("failed-precondition", "serviceUnavailable", { credits: true });
export const isOutOfCredits = (error: unknown) =>
  error instanceof HttpsError && (error.details as { credits?: boolean } | undefined)?.credits === true;
export const badResponse = () => new HttpsError("internal", "badResponse");
export const noWords = () => new HttpsError("not-found", "noWordsAvailable");
export const refused = () => new HttpsError("invalid-argument", "refused");
export const badInput = (what: string) => new HttpsError("invalid-argument", `badInput:${what}`);
export const notSignedIn = () => new HttpsError("unauthenticated", "notSignedIn");
export const tooManyReports = () => new HttpsError("resource-exhausted", "tooManyReports");
export const jobComplete = () => new HttpsError("not-found", "jobComplete");
export const pictureLimit = () => new HttpsError("resource-exhausted", "pictureLimit");
