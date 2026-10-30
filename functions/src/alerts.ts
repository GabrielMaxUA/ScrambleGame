// alerts.ts — an email to support@learnscrumble.com when something needs the developer's eyes right away.
//
//   raiseAlert(kind, line)  -> called where the problem happens (no email secret needed there):
//                              records it in Firestore alerts/{kind}-{day} (UTC day). The FIRST time a kind happens on a
//                              day the document is created, which sends the email; later ones that day only add to the
//                              count and the lines (at most 20 kept), so there's at most one email per kind per day.
//   mailAlert               -> Firestore trigger on a new alerts/{id}: sends that email.
//
// Kinds:
//   openaiCredits -> OpenAI says the credits are used up (openai.ts): players get "can't prepare new words" until
//                    credits are added (Billing on platform.openai.com).
//   pictureCap    -> a user reached PICTURES_PER_DAY new pictures today (index.ts getPicture): normal players never do,
//                    so it may be a modified app. The line has a one-way code of the user's anonymous ID, never the ID.
// Never fails the caller: a problem with the alert itself is only logged.

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "./store";
import { SUPPORT_EMAIL_PASSWORD, sendSupportEmail } from "./mail";

export type AlertKind = "openaiCredits" | "pictureCap";

const SUBJECTS: Record<AlertKind, string> = {
  openaiCredits: "OpenAI credits are used up — players can't get new words",
  pictureCap: "A user reached the daily limit of new pictures",
};
const ADVICE: Record<AlertKind, string> = {
  openaiCredits: "Add credits: platform.openai.com -> Settings -> Billing (check auto recharge and the card). Then set any paused job in Firestore \"prepare\" back to status \"run\".",
  pictureCap: "Normal players don't draw this many pictures in a day. If it keeps happening (see the count, or tomorrow's alerts), the app may be modified: check the OpenAI usage page.",
};

// MARK: - raiseAlert
export async function raiseAlert(kind: AlertKind, line: string): Promise<void> {
  const day = new Date().toISOString().slice(0, 10);
  const ref = db.collection("alerts").doc(`${kind}-${day}`);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        tx.create(ref, { kind, day, count: 1, lines: [line], first: FieldValue.serverTimestamp() });
      } else {
        const lines = (snap.get("lines") as string[] | undefined) ?? [];
        tx.update(ref, { count: FieldValue.increment(1), lines: lines.length < 20 ? [...lines, line] : lines,
                         last: FieldValue.serverTimestamp() });
      }
    });
  } catch (error) {
    logger.error("raiseAlert: couldn't record the alert", { kind, error: String(error) });
  }
}

// MARK: - mailAlert
// The first alert of a kind on a day -> one email. Sending failed -> logged (the alert stays in Firestore).
export const mailAlert = onDocumentCreated({ document: "alerts/{id}", secrets: [SUPPORT_EMAIL_PASSWORD] }, async (event) => {
  const kind = event.data?.get("kind") as AlertKind | undefined;
  if (!kind || !(kind in SUBJECTS)) return;
  const project = process.env.GCLOUD_PROJECT ?? "scrumblegame";
  const link = `https://console.firebase.google.com/project/${project}/firestore/databases/-default-/data/~2Falerts~2F${encodeURIComponent(event.params.id)}`;
  const subject = `LearnScrumble alert: ${SUBJECTS[kind]}${project === "scrumblegame" ? "" : ` (${project})`}`;
  const text = `${event.data?.get("lines")?.[0] ?? ""}\n\n${ADVICE[kind]}\n\nLater ones today are only counted here: ${link}`;
  try {
    await sendSupportEmail("LearnScrumble alerts", subject, text);
    logger.info("mailAlert: sent", { kind });
  } catch (error) {
    logger.error("mailAlert: sending failed", { kind, error: String(error) });
  }
});
