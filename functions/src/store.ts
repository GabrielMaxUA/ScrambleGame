// store.ts — Firestore and Storage, from the server side (admin access, not limited by security rules).
//
// Same data shapes the app has always used, so existing words and pictures keep working:
//   words/{id}        id = English toolName with "/" -> "-"
//     { id, word, translation: { "uk-UA": "...", ... }, image: <download URL or "">, professions: ["cook", ...],
//       imagePrompt?: the description the picture was last drawn from (only set by reportPicture so far) }
//   professions/{name} the job counter (was ProfessionStore in the app)
//     { name, typed, picked, firstSeen, lastSeen, status: "in menu" | "new" | "added" | "rejected" }
//   reports/{id}      pictures users reported as wrong (reportPicture), same id as the word
//     { word, jobs, reports, users, lastReport, bankImage, suggested: { url, path, imagePrompt, job, at },
//       status: "new" | "approve" | "reject" (set by you) | "approved" | "rejected", notified, approvedAt? }
//     reports/{id}/reporters/{code}  one per reporting user (one-way hash of the anonymous ID), to count people
//   reportUsage/{uid} reports sent per anonymous user per day — capped (REPORTS_PER_DAY in index.ts)
//   pictureUsage/{uid} new pictures drawn per anonymous user per day — capped (PICTURES_PER_DAY in index.ts)
//   jobs/{key}        a menu job's vocabulary (getWords): { status: "open" | "complete", words, reason, completedAt }.
//                     No document = open. "complete" = no new GPT words for this job any more (set status "open" in
//                     the console to let it grow again)
//   Storage: tools/<id>.webp in the project's word-picture bucket; replaced pictures are kept in rejected/,
//            pictures drawn for a report (only the reporter sees them until approved) in reports/<id>/

import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, FieldPath } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { randomUUID, createHash } from "node:crypto";
import sharp from "sharp";

initializeApp();
export const db = getFirestore();

export interface WordDoc {
  id: string;
  word: string;
  translation: Record<string, string>;
  image: string;
  professions?: string[];
  imagePrompt?: string;
  pictureRefused?: boolean;   // prepare.ts skipped it: OpenAI's safety system refused the picture prompt
}

// MARK: - docID
// Firestore document IDs can't contain "/" — same rule as the app's FirebaseWordStore.documentID.
export const docID = (toolName: string) => toolName.replace(/\//g, "-");

// MARK: - fetchBank
// Every word tagged with this profession (array-contains: automatic index, nothing to set up).
export async function fetchBank(profession: string): Promise<WordDoc[]> {
  const snapshot = await db.collection("words").where("professions", "array-contains", profession).get();
  return snapshot.docs.map((d) => d.data() as WordDoc);
}

// MARK: - fetchWords
// Reads specific words by name in one round trip (getAll). Missing words aren't in the result.
export async function fetchWords(toolNames: string[]): Promise<Map<string, WordDoc>> {
  const unique = [...new Set(toolNames)];
  const result = new Map<string, WordDoc>();
  if (unique.length === 0) return result;
  const refs = unique.map((name) => db.collection("words").doc(docID(name)));
  const snapshots = await db.getAll(...refs);
  snapshots.forEach((snap) => {
    if (snap.exists) {
      const doc = snap.data() as WordDoc;
      result.set(doc.word, doc);
    }
  });
  return result;
}

// MARK: - saveWord
// Create-or-fill, the server version of the app's FirebaseWordStore.saveIfNeeded:
// - new word -> full doc (image "" until getPicture fills it)
// - existing -> only the missing translations, and the profession added with arrayUnion (never twice)
// - nothing missing -> no write
export async function saveWord(toolName: string, origin: string, originWord: string, target: string,
                               targetWord: string, profession: string | null, existing?: WordDoc): Promise<void> {
  const ref = db.collection("words").doc(docID(toolName));
  if (!existing) {
    const doc: WordDoc = {
      id: toolName,
      word: toolName,
      translation: { [origin]: originWord, [target]: targetWord },
      image: "",
      ...(profession ? { professions: [profession] } : {}),
    };
    await ref.set(doc, { merge: true });                           // merge: another user may have created it a moment ago
    return;
  }
  // Field paths, not "translation.uk-UA" strings: language codes contain "-", which dotted paths don't allow.
  const fields: [FieldPath, unknown][] = [];
  if (existing.translation?.[origin] === undefined) fields.push([new FieldPath("translation", origin), originWord]);
  if (target !== origin && existing.translation?.[target] === undefined) {   // same language twice -> one field only
    fields.push([new FieldPath("translation", target), targetWord]);
  }
  if (profession && !(existing.professions ?? []).includes(profession)) {
    fields.push([new FieldPath("professions"), FieldValue.arrayUnion(profession)]);
  }
  if (fields.length === 0) return;
  const [[firstPath, firstValue], ...rest] = fields;
  await ref.update(firstPath, firstValue, ...rest.flat());          // update(field, value, field, value, …)
}

// MARK: - savePicture
// PNG -> WebP (sharp), uploaded to tools/<id>.webp with a download token, so the URL looks exactly like the
// ones the app created before (firebasestorage.googleapis.com/... ?alt=media&token=...). Then stored on the word.
export async function savePicture(toolName: string, png: Buffer): Promise<string> {
  const webp = await sharp(png).webp({ quality: 80 }).toBuffer();
  const bucket = getStorage().bucket(pictureBucket());
  const path = `tools/${docID(toolName)}.webp`;
  const token = randomUUID();
  await bucket.file(path).save(webp, {
    contentType: "image/webp",
    metadata: { metadata: { firebaseStorageDownloadTokens: token } },
  });
  const url = pictureURL(bucket.name, path, token);
  await db.collection("words").doc(docID(toolName)).set({ image: url }, { merge: true });
  return url;
}

// MARK: - repairPictureLink
// A word's picture link stopped working although the file is still in Storage: the file was uploaded again
// (the old app redrew pictures after a failed download, or two phones made the same word at once), which gave the
// file a new download token, while the word kept the link with the old one. With the rules closed, only a link
// with the file's current token opens it.
// 1. Reads the bucket, path and token out of the word's link. Not a Storage link -> null.
// 2. The file is gone -> null (the caller draws a new picture).
// 3. The link's token is still one of the file's tokens -> nothing to fix.
//    Otherwise -> the link is rebuilt with the file's current token (one is created if the file has none)
//    and saved on the word (unless `write` is false: a check without changes).
// Costs nothing: no picture is drawn.
export async function repairPictureLink(doc: WordDoc, write = true):
    Promise<{ url: string; changed: boolean } | null> {
  const place = parsePictureURL(doc.image);
  if (!place) return null;
  const file = getStorage().bucket(place.bucket).file(place.path);
  const [exists] = await file.exists();
  if (!exists) return null;
  const [meta] = await file.getMetadata();
  const tokens = String(meta.metadata?.firebaseStorageDownloadTokens ?? "")
    .split(",").map((t) => t.trim()).filter(Boolean);
  if (place.token && tokens.includes(place.token)) return { url: doc.image, changed: false };
  let token = tokens[0];
  if (!token) {
    token = randomUUID();
    if (write) await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  }
  const url = pictureURL(place.bucket, place.path, token);
  if (write) await db.collection("words").doc(docID(doc.word)).update({ image: url });
  return { url, changed: true };
}

// MARK: - parsePictureURL / pictureURL
// Firebase download links look like
//   https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<path, URL-encoded>?alt=media&token=<token>
export function parsePictureURL(link: string): { bucket: string; path: string; token: string | null } | null {
  try {
    const url = new URL(link);
    const match = url.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
    if (!match) return null;
    return { bucket: match[1], path: decodeURIComponent(match[2]), token: url.searchParams.get("token") };
  } catch {
    return null;
  }
}

const pictureURL = (bucket: string, path: string, token: string) =>
  `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;

// MARK: - pictureBucket
// Production keeps its pictures in the separate bucket "scrumblegame-tools" (as the app did);
// any other project (dev, emulator) uses its default bucket.
function pictureBucket(): string | undefined {
  const project = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
  return project === "scrumblegame" ? "scrumblegame-tools" : undefined;
}

// MARK: - countProfession
// The job counter (was ProfessionStore in the app): +1 typed or picked, lastSeen; created on first use.
// The app decides WHEN (once per job per install); the server only does the write.
export async function countProfession(name: string, field: "typed" | "picked", inMenu: boolean): Promise<void> {
  const ref = db.collection("professions").doc(docID(name));
  const now = FieldValue.serverTimestamp();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      tx.update(ref, { [field]: FieldValue.increment(1), lastSeen: now, ...(inMenu ? { status: "in menu" } : {}) });
    } else {
      tx.set(ref, {
        name, typed: field === "typed" ? 1 : 0, picked: field === "picked" ? 1 : 0,
        firstSeen: now, lastSeen: now, status: inMenu ? "in menu" : "new",
      });
    }
  });
}

// MARK: - countReport
// Pictures reported today by this anonymous user, +1. Returns today's total (after this report). UTC day.
export async function countReport(uid: string): Promise<number> {
  const ref = db.collection("reportUsage").doc(uid);
  const day = new Date().toISOString().slice(0, 10);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const total = (snap.exists && snap.get("day") === day ? (snap.get("reports") as number) : 0) + 1;
    tx.set(ref, { day, reports: total, updated: FieldValue.serverTimestamp() });
    return total;
  });
}

// MARK: - jobComplete / completeJob
// Whether a job's vocabulary is complete, and marking it so (reason: "exhausted" = GPT says no common items are
// left, "no new words" = GPT keeps repeating, "limit" = MAX_WORDS_PER_JOB reached).
export async function isJobComplete(key: string): Promise<boolean> {
  const snap = await db.collection("jobs").doc(docID(key)).get();
  return snap.exists && snap.get("status") === "complete";
}

export async function completeJob(key: string, words: number, reason: string): Promise<void> {
  await db.collection("jobs").doc(docID(key)).set(
    { job: key, status: "complete", words, reason, completedAt: FieldValue.serverTimestamp() }, { merge: true });
}

// MARK: - countPicture / picturesToday
// New pictures drawn today for this anonymous user (getPicture). countPicture adds one and returns today's total
// (after it); picturesToday only reads. UTC day, overwritten every day — like reportUsage.
export async function countPicture(uid: string): Promise<number> {
  const ref = db.collection("pictureUsage").doc(uid);
  const day = new Date().toISOString().slice(0, 10);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const total = (snap.exists && snap.get("day") === day ? (snap.get("pictures") as number) : 0) + 1;
    tx.set(ref, { day, pictures: total, updated: FieldValue.serverTimestamp() });
    return total;
  });
}

export async function picturesToday(uid: string): Promise<number> {
  const snap = await db.collection("pictureUsage").doc(uid).get();
  return snap.exists && snap.get("day") === new Date().toISOString().slice(0, 10) ? (snap.get("pictures") as number) : 0;
}

// One-way code of the anonymous ID for logs and alerts (the same kind reports use for reporters), never the ID itself.
export const userCode = (uid: string) => createHash("sha256").update(uid).digest("hex").slice(0, 12);

// MARK: - saveReportPicture
// The picture drawn for a report: only for the user who reported, NOT on the word (the bank picture stays).
// Stored as reports/<id>/<random>.webp with a download token, so the reporting phone can download it, and so it can
// be approved later (approveReport copies it over the word's picture).
export async function saveReportPicture(toolName: string, png: Buffer): Promise<{ url: string; path: string }> {
  const webp = await sharp(png).webp({ quality: 80 }).toBuffer();
  const bucket = getStorage().bucket(pictureBucket());
  const path = `reports/${docID(toolName)}/${randomUUID()}.webp`;
  const token = randomUUID();
  await bucket.file(path).save(webp, {
    contentType: "image/webp",
    metadata: { metadata: { firebaseStorageDownloadTokens: token } },
  });
  return { url: pictureURL(bucket.name, path, token), path };
}

// MARK: - recordReport
// One report of a word's picture, in one transaction:
//   reports/{id}                  word, jobs, reports (+1), users (+1 for a new reporter), lastReport,
//                                 bankImage (the picture reported), suggested (the new picture: link, Storage path,
//                                 description, job, time), status "new", notified false (-> the daily email)
//   reports/{id}/reporters/{code} one doc per reporter: `code` is a one-way hash of the anonymous sign-in ID, only to
//                                 count different people; nothing else is stored about them
// A new report reopens an approved or rejected word (status back to "new"): someone still sees a problem.
export async function recordReport(doc: WordDoc, uid: string, job: string,
                                   suggested: { url: string; path: string; imagePrompt: string }): Promise<void> {
  const ref = db.collection("reports").doc(docID(doc.word));
  const reporter = ref.collection("reporters").doc(createHash("sha256").update(uid).digest("hex").slice(0, 32));
  await db.runTransaction(async (tx) => {
    const isNew = !(await tx.get(reporter)).exists;
    if (isNew) tx.set(reporter, { at: FieldValue.serverTimestamp() });
    tx.set(ref, {
      word: doc.word,
      jobs: FieldValue.arrayUnion(job),
      reports: FieldValue.increment(1),
      ...(isNew ? { users: FieldValue.increment(1) } : {}),
      lastReport: FieldValue.serverTimestamp(),
      bankImage: doc.image,
      suggested: { ...suggested, job, at: FieldValue.serverTimestamp() },
      status: "new",
      notified: false,
    }, { merge: true });
  });
}

// MARK: - approveReport
// The developer set status "approve" on reports/{id} (reviewReport trigger, reports.ts):
// 1. The word's current picture is copied to rejected/ (kept for checking), then the suggested picture is copied over
//    tools/<id>.webp with a new download token and saved on the word with its description — every user gets it.
//    Phones holding the old link get a 403 and repair it through getPicture.
// 2. The report becomes "approved" (approvedAt, approvedImage). Nothing suggested -> "rejected" with a note.
export async function approveReport(id: string): Promise<void> {
  const ref = db.collection("reports").doc(id);
  const report = (await ref.get()).data();
  const suggestedPath: string | undefined = report?.suggested?.path;
  const word: string | undefined = report?.word;
  if (!report || !word || !suggestedPath) {
    await ref.set({ status: "rejected", note: "nothing to approve" }, { merge: true });
    return;
  }
  const doc = (await fetchWords([word])).get(word);
  if (doc?.image) await keepRejectedPicture(doc);
  const bucket = getStorage().bucket(pictureBucket());
  const path = `tools/${docID(word)}.webp`;
  const token = randomUUID();
  await bucket.file(suggestedPath).copy(bucket.file(path));
  await bucket.file(path).setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  const url = pictureURL(bucket.name, path, token);
  await db.collection("words").doc(docID(word)).set(
    { image: url, ...(report.suggested.imagePrompt ? { imagePrompt: report.suggested.imagePrompt } : {}) }, { merge: true });
  await ref.set({ status: "approved", approvedAt: FieldValue.serverTimestamp(), approvedImage: url, bankImage: url }, { merge: true });
}

// MARK: - pendingReports / markNotified
// The daily email (reports.ts): reports not mailed yet, then flagged as mailed.
export async function pendingReports(): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  return (await db.collection("reports").where("notified", "==", false).get()).docs;
}
export async function markNotified(ids: string[]): Promise<void> {
  const batch = db.batch();
  for (const id of ids) batch.update(db.collection("reports").doc(id), { notified: true });
  await batch.commit();
}

// MARK: - keepRejectedPicture
// Copies the word's current picture to rejected/<id>-<time>.webp before it's replaced, so a person can still see
// what was reported. Returns that path, or null when there's no picture file to keep (not a Storage link, or gone).
export async function keepRejectedPicture(doc: WordDoc): Promise<string | null> {
  const place = parsePictureURL(doc.image);
  if (!place) return null;
  const file = getStorage().bucket(place.bucket).file(place.path);
  const [exists] = await file.exists();
  if (!exists) return null;
  const path = `rejected/${docID(doc.word)}-${Date.now()}.webp`;
  await file.copy(getStorage().bucket(place.bucket).file(path));
  return path;
}

// MARK: - saveImagePrompt
// Keeps the description a picture was drawn from on the word, so getWords hands it to the app (and a later redraw
// of a broken picture uses it instead of the bare word).
export async function saveImagePrompt(word: string, imagePrompt: string): Promise<void> {
  await db.collection("words").doc(docID(word)).set({ imagePrompt }, { merge: true });
}

// MARK: - samePicture
// Two links to the same picture file? The token may differ (repairPictureLink), so bucket + path are compared.
export function samePicture(a: string, b: string): boolean {
  const pa = parsePictureURL(a);
  const pb = parsePictureURL(b);
  if (!pa || !pb) return a === b;
  return pa.bucket === pb.bucket && pa.path === pb.path && (pa.token === pb.token || !pa.token || !pb.token);
}
