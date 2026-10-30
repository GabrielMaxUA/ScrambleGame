// mail.ts — sends an email to support@learnscrumble.com (the daily report email in reports.ts, the alerts in alerts.ts).
//
// Namecheap Private Email over SMTP (mail.privateemail.com, port 465, SSL), signed in as support@learnscrumble.com
// with its mailbox password from Secret Manager (SUPPORT_EMAIL_PASSWORD; set with
// `firebase functions:secrets:set SUPPORT_EMAIL_PASSWORD --project <project>`). Change the mailbox password in
// Namecheap -> set the secret again and redeploy, or the emails stop (the error shows in the function's logs).
// A function that sends mail must list SUPPORT_EMAIL_PASSWORD in its `secrets`.

import { defineSecret } from "firebase-functions/params";
import { createTransport } from "nodemailer";

export const SUPPORT_EMAIL_PASSWORD = defineSecret("SUPPORT_EMAIL_PASSWORD");
export const SUPPORT_EMAIL = "support@learnscrumble.com";

// MARK: - sendSupportEmail
// From "LearnScrumble <sender>" to support@. Throws when sending fails; the caller decides what that means.
export async function sendSupportEmail(sender: string, subject: string, text: string, html?: string): Promise<void> {
  const transport = createTransport({
    host: "mail.privateemail.com",
    port: 465,
    secure: true,
    auth: { user: SUPPORT_EMAIL, pass: SUPPORT_EMAIL_PASSWORD.value() },
  });
  await transport.sendMail({ from: `${sender} <${SUPPORT_EMAIL}>`, to: SUPPORT_EMAIL, subject, text, html });
}
