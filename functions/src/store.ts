// store.ts — Firestore and Storage, from the server side (admin access, not limited by security rules).
//
// Same data shapes the app has always used, so existing words and pictures keep working:
//   words/{id}        id = English toolName with "/" -> "-"
//     { id, word, translation: { "uk-UA": "...", ... }, image: <download URL or "">, professions: ["cook", ...] }
//   professions/{name} the job counter (was ProfessionStore in the app)
//     { name, typed, picked, firstSeen, lastSeen, status: "in menu" | "new" | "added" | "rejected" }
//   usage/{uid}       words handed out per anonymous user per day — counted, not yet enforced (see index.ts)
//   Storage: tools/<id>.webp in the project's word-picture bucket

import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, FieldPath } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { randomUUID } from "node:crypto";
import sharp from "sharp";

initializeApp();
export const db = getFirestore();

export interface WordDoc {
  id: string;
  word: string;
  translation: Record<string, string>;
  image: string;
  professions?: string[];
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

// MARK: - countUsage
// Words handed out today to this anonymous user. Returns today's total. UTC day.
export async function countUsage(uid: string, words: number): Promise<number> {
  const ref = db.collection("usage").doc(uid);
  const day = new Date().toISOString().slice(0, 10);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const previous = snap.exists && snap.get("day") === day ? (snap.get("words") as number) : 0;
    const total = previous + words;
    tx.set(ref, { day, words: total, updated: FieldValue.serverTimestamp() });
    return total;
  });
}
