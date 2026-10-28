// errors.ts — one place that turns failures into the error codes the app understands.
//
// The app (RequestModel) maps these HttpsError codes back to its own GenerationError cases:
//   unavailable          -> serverBusy          (OpenAI 429 / 5xx after our retries — temporary)
//   deadline-exceeded    -> timedOut            (OpenAI took too long)
//   failed-precondition  -> serviceUnavailable  (OpenAI 4xx: key, billing or request problem — OUR side, retry won't help)
//   internal             -> badResponse         (garbled reply from GPT)
//   not-found            -> noWordsAvailable    (nothing new for this job + language)
//   invalid-argument     -> noWordsAvailable    (bad input, or the typed job text was refused by moderation)
//   unauthenticated      -> unknown             (no anonymous sign-in on the phone)
// The message is a short machine-readable reason, never user text.

import { HttpsError } from "firebase-functions/v2/https";

export const busy = () => new HttpsError("unavailable", "serverBusy");
export const timedOut = () => new HttpsError("deadline-exceeded", "timedOut");
export const serviceUnavailable = () => new HttpsError("failed-precondition", "serviceUnavailable");
export const badResponse = () => new HttpsError("internal", "badResponse");
export const noWords = () => new HttpsError("not-found", "noWordsAvailable");
export const refused = () => new HttpsError("invalid-argument", "refused");
export const badInput = (what: string) => new HttpsError("invalid-argument", `badInput:${what}`);
export const notSignedIn = () => new HttpsError("unauthenticated", "notSignedIn");
