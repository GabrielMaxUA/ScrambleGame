// reports.ts — what happens with picture reports after reportPicture (index.ts) recorded them.
//
//   reviewReport  -> Firestore trigger on reports/{id}. You open the report in the Firebase console and set
//                    status = "approve": the suggested picture replaces the word's picture for everyone (approveReport);
//                    status = "reject": nothing changes for other users, the report becomes "rejected".
//                    The reporter keeps the picture drawn for them either way.
//   mailReports   -> every morning (8:00 Toronto time): one email to support@learnscrumble.com listing the reports
//                    since the last email — word, jobs, how many reports and people, both pictures, and a link to the
//                    report in the console. No new reports -> no email.
//
// Email: sent through mail.ts (Namecheap Private Email, the SUPPORT_EMAIL_PASSWORD secret).

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { approveReport, pendingReports, markNotified, db } from "./store";
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

// MARK: - mailReports
// 1. Reports not mailed yet (notified false). None -> nothing sent.
// 2. One email: a line per word, most reported first, with both pictures and the console link; plain-text and HTML.
// 3. Sent -> they're marked notified. Sending failed -> logged, they stay unmailed and come again tomorrow.
export const mailReports = onSchedule({ schedule: "0 8 * * *", timeZone: "America/Toronto", secrets: [SUPPORT_EMAIL_PASSWORD] }, async () => {
  const reports = (await pendingReports()).sort((a, b) => (b.get("reports") ?? 0) - (a.get("reports") ?? 0));
  if (reports.length === 0) {
    logger.info("mailReports: no new reports");
    return;
  }
  const project = process.env.GCLOUD_PROJECT ?? "scrumblegame";
  const consoleLink = (id: string) =>
    `https://console.firebase.google.com/project/${project}/firestore/databases/-default-/data/~2Freports~2F${encodeURIComponent(id)}`;
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

  const subject = `LearnScrumble: ${rows.length} reported picture${rows.length === 1 ? "" : "s"}${project === "scrumblegame" ? "" : ` (${project})`}`;
  const text = rows.map((r) =>
    `${r.word} (${r.jobs}) — ${r.reports} report(s) from ${r.users} user(s)\n  now: ${r.bank}\n  suggested: ${r.suggested}\n  review: ${consoleLink(r.id)}`,
  ).join("\n\n") + `\n\nTo decide: open the review link and set the field status to "approve" (the suggested picture replaces it for everyone) or "reject".`;
  const escape = (v: string) => v.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" }[c]!));
  const html = `<p>${rows.length} reported picture${rows.length === 1 ? "" : "s"} since the last email. To decide, open <b>Review</b> and set the field <code>status</code> to <code>approve</code> (the suggested picture replaces it for everyone) or <code>reject</code>.</p>`
    + rows.map((r) => `<hr><p><b>${escape(r.word)}</b> (${escape(r.jobs)}) — ${r.reports} report(s) from ${r.users} user(s) · <a href="${consoleLink(r.id)}">Review</a></p>
<table><tr><td>Now<br><img src="${escape(r.bank)}" width="160" alt="current picture"></td>
<td>Suggested<br><img src="${escape(r.suggested)}" width="160" alt="suggested picture"></td></tr></table>
<p style="color:#666;font-size:12px">${escape(r.description)}</p>`).join("");

  try {
    await sendSupportEmail("LearnScrumble reports", subject, text, html);
    await markNotified(rows.map((r) => r.id));
    logger.info("mailReports: sent", { reports: rows.length });
  } catch (error) {
    logger.error("mailReports: sending failed, the reports come again tomorrow", { error: String(error) });
  }
});
