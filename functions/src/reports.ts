// reports.ts — what happens with picture and word reports after reportPicture / reportWord (index.ts) recorded them.
//
//   reviewReport  -> Firestore trigger on reports/{id}. You open the report in the Firebase console and set
//                    status = "approve": the suggested picture replaces the word's picture for everyone (approveReport);
//                    status = "reject": nothing changes for other users, the report becomes "rejected".
//                    The reporter keeps the picture drawn for them either way.
//   reviewWordReport -> Firestore trigger on wordReports/{id}: "approve" writes the report's `fix` (edit it first in
//                    the console if needed) into the word's translation for everyone (approveWordReport); "reject"
//                    changes nothing.
//   mailReports   -> every morning (8:00 Toronto time): one email to support@learnscrumble.com listing the reports
//                    since the last email — pictures: word, jobs, how many reports and people, both pictures; words:
//                    word, language, the text now, what players typed, OpenAI's opinion — each with a link to the
//                    report in the console. No new reports -> no email.
//
// Email: sent through mail.ts (Namecheap Private Email, the SUPPORT_EMAIL_PASSWORD secret).

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { approveReport, approveWordReport, pendingReports, markNotified, db } from "./store";
import { SUPPORT_EMAIL_PASSWORD, sendSupportEmail } from "./mail";

// MARK: - reviewReport
// Only the developer's two words start something: "approve" -> approveReport (status becomes "approved"),
// "reject" -> "rejected". Every other write (a new report, our own status changes) ends here at once.
export const reviewReport = onDocumentWritten({ document: "reports/{id}", timeoutSeconds: 120, memory: "512MiB" }, async (event) => {
  const status = event.data?.after?.get("status");
  const before = event.data?.before?.get("status");
  if (status === before) return;
  const id = event.params.id;
  if (status === "approve") {
    await approveReport(id);
    logger.info("reviewReport: approved, the picture is replaced for everyone", { id });
  } else if (status === "reject") {
    await db.collection("reports").doc(id).set({ status: "rejected" }, { merge: true });
    logger.info("reviewReport: rejected", { id });
  }
});

// MARK: - reviewWordReport
// As reviewReport, for word reports: "approve" -> approveWordReport, "reject" -> "rejected".
export const reviewWordReport = onDocumentWritten({ document: "wordReports/{id}", timeoutSeconds: 60 }, async (event) => {
  const status = event.data?.after?.get("status");
  const before = event.data?.before?.get("status");
  if (status === before) return;
  const id = event.params.id;
  if (status === "approve") {
    await approveWordReport(id);
    logger.info("reviewWordReport: approved, the translation is fixed for everyone", { id });
  } else if (status === "reject") {
    await db.collection("wordReports").doc(id).set({ status: "rejected" }, { merge: true });
    logger.info("reviewWordReport: rejected", { id });
  }
});

// MARK: - mailReports
// 1. Reports not mailed yet (notified false). None -> nothing sent.
// 2. One email: a line per word, most reported first, with both pictures and the console link; plain-text and HTML.
// 3. Sent -> they're marked notified. Sending failed -> logged, they stay unmailed and come again tomorrow.
export const mailReports = onSchedule({ schedule: "0 8 * * *", timeZone: "America/Toronto", secrets: [SUPPORT_EMAIL_PASSWORD] }, async () => {
  const reports = (await pendingReports()).sort((a, b) => (b.get("reports") ?? 0) - (a.get("reports") ?? 0));
  const wordReports = (await pendingReports("wordReports")).sort((a, b) => (b.get("reports") ?? 0) - (a.get("reports") ?? 0));
  if (reports.length === 0 && wordReports.length === 0) {
    logger.info("mailReports: no new reports");
    return;
  }
  const project = process.env.GCLOUD_PROJECT ?? "scrumblegame";
  const consoleLink = (collection: string, id: string) =>
    `https://console.firebase.google.com/project/${project}/firestore/databases/-default-/data/~2F${collection}~2F${encodeURIComponent(id)}`;
  const rows = reports.map((r) => ({
    id: r.id,
    word: String(r.get("word") ?? r.id),
    jobs: ((r.get("jobs") ?? []) as string[]).join(", "),
    reports: r.get("reports") ?? 1,
    users: r.get("users") ?? 1,
    bank: String(r.get("bankImage") ?? ""),
    suggested: String(r.get("suggested")?.url ?? ""),
    description: String(r.get("suggested")?.imagePrompt ?? ""),
  }));
  const words = wordReports.map((r) => {
    const suggestions = (r.get("suggestions") ?? []) as { text: string; note?: string }[];
    const counts = new Map<string, number>();
    for (const s of suggestions) counts.set(s.text, (counts.get(s.text) ?? 0) + 1);
    return {
      id: r.id,
      word: String(r.get("word") ?? r.id),
      lang: String(r.get("lang") ?? ""),
      jobs: ((r.get("jobs") ?? []) as string[]).join(", "),
      reports: r.get("reports") ?? 1,
      users: r.get("users") ?? 1,
      current: String(r.get("current") ?? ""),
      typed: [...counts.entries()].sort((a, b) => b[1] - a[1]).map(([t, n]) => (n > 1 ? `${t} (×${n})` : t)).join(", "),
      notes: suggestions.map((s) => s.note ?? "").filter(Boolean).join(" / "),
      fix: String(r.get("fix") ?? ""),
      ai: r.get("aiFix") ? `${r.get("aiFix")} (${r.get("aiReason") ?? ""})` : String(r.get("aiReason") ?? "no opinion"),
    };
  });

  const parts = [
    rows.length ? `${rows.length} reported picture${rows.length === 1 ? "" : "s"}` : "",
    words.length ? `${words.length} reported word${words.length === 1 ? "" : "s"}` : "",
  ].filter(Boolean).join(", ");
  const subject = `LearnScrumble: ${parts}${project === "scrumblegame" ? "" : ` (${project})`}`;
  const howTo = `To decide: open the review link and set the field status to "approve" or "reject". A picture: the suggested picture replaces it for everyone. A word: the field "fix" becomes the translation for everyone — edit it first if needed.`;
  const text = [
    ...rows.map((r) => `PICTURE ${r.word} (${r.jobs}) — ${r.reports} report(s) from ${r.users} user(s)\n  now: ${r.bank}\n  suggested: ${r.suggested}\n  review: ${consoleLink("reports", r.id)}`),
    ...words.map((w) => `WORD ${w.word} [${w.lang}] (${w.jobs}) — ${w.reports} report(s) from ${w.users} user(s)\n  now: ${w.current}\n  players typed: ${w.typed}${w.notes ? `\n  notes: ${w.notes}` : ""}\n  OpenAI: ${w.ai}\n  fix if approved: ${w.fix}\n  review: ${consoleLink("wordReports", w.id)}`),
  ].join("\n\n") + `\n\n${howTo}`;
  const escape = (v: string) => v.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" }[c]!));
  const html = `<p>${escape(parts)} since the last email. ${escape(howTo)}</p>`
    + (rows.length ? `<h3>Pictures</h3>` : "")
    + rows.map((r) => `<hr><p><b>${escape(r.word)}</b> (${escape(r.jobs)}) — ${r.reports} report(s) from ${r.users} user(s) · <a href="${consoleLink("reports", r.id)}">Review</a></p>
<table><tr><td>Now<br><img src="${escape(r.bank)}" width="160" alt="current picture"></td>
<td>Suggested<br><img src="${escape(r.suggested)}" width="160" alt="suggested picture"></td></tr></table>
<p style="color:#666;font-size:12px">${escape(r.description)}</p>`).join("")
    + (words.length ? `<h3>Words</h3>` : "")
    + words.map((w) => `<hr><p><b>${escape(w.word)}</b> [${escape(w.lang)}] (${escape(w.jobs)}) — ${w.reports} report(s) from ${w.users} user(s) · <a href="${consoleLink("wordReports", w.id)}">Review</a></p>
<table><tr><td>Now:</td><td><b>${escape(w.current)}</b></td></tr>
<tr><td>Players typed:</td><td>${escape(w.typed)}</td></tr>
${w.notes ? `<tr><td>Notes:</td><td>${escape(w.notes)}</td></tr>` : ""}
<tr><td>OpenAI:</td><td>${escape(w.ai)}</td></tr>
<tr><td>Fix if approved:</td><td><b>${escape(w.fix)}</b></td></tr></table>`).join("");

  try {
    await sendSupportEmail("LearnScrumble reports", subject, text, html);
    if (rows.length) await markNotified(rows.map((r) => r.id));
    if (words.length) await markNotified(words.map((w) => w.id), "wordReports");
    logger.info("mailReports: sent", { pictures: rows.length, words: words.length });
  } catch (error) {
    logger.error("mailReports: sending failed, the reports come again tomorrow", { error: String(error) });
  }
});
