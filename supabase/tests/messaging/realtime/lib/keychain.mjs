// KAN-545: reads a test account from the macOS Keychain at run time, into process memory only.
// `security find-generic-password -s <service> -w` gives the password; the same item without -w lists its
// attributes, from which the account name (the sign-in email) is read. execFile is used (no shell), nothing is
// written to disk, and neither value is ever printed or logged.

import { execFile } from "node:child_process";
import { promisify } from "node:util";

const run = promisify(execFile);

export const SERVICE_A = "dabbler-test-user";
export const SERVICE_B = "dabbler-test-user-b";

/** Pulls "acct" from the attribute listing of `security find-generic-password`. */
export function parseAccount(attributeListing) {
  const m = /"acct"<blob>="([^"]*)"/.exec(String(attributeListing));
  return m ? m[1] : null;
}

export async function readCredential(service, exec = run) {
  const pw = await exec("security", ["find-generic-password", "-s", service, "-w"]);
  const attrs = await exec("security", ["find-generic-password", "-s", service]);
  const email = parseAccount(attrs.stdout);
  const password = String(pw.stdout).replace(/\r?\n$/, "");
  if (!email || !password) throw new Error(`Keychain item ${service} is missing its account or password`);
  return { email, password };
}
