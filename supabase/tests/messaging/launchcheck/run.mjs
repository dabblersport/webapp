// KAN-554: entry point. One command, no prompts. See README.md.
import { randomUUID } from "node:crypto";
import { SERVICE_A, SERVICE_B, readCredential } from "../realtime/lib/keychain.mjs";
import { DrillError, assertTestAccount, readConfig, signIn } from "../killswitch/drill.mjs";
import { makeLaunchCheck } from "./launchcheck.mjs";

const out = (line) => process.stdout.write(`${line}\n`);
// The KAN-554 test game "Dabbler Chat Test 2" (owner Dabbler-Test, ends 2026-10-18 17:00 Dubai). A test fixture id, not a secret.
export const LAUNCH_GAME_ID = "1c84fa24-e528-486b-b4a1-113bbfe31aac";

async function main() {
  process.env.MESSAGING_GAME_ID ??= LAUNCH_GAME_ID;
  const cfg = readConfig(process.env);
  const A = await signIn(fetch, cfg, await readCredential(SERVICE_A));
  const B = await signIn(fetch, cfg, await readCredential(SERVICE_B));
  await assertTestAccount(fetch, cfg, "A", A);
  await assertTestAccount(fetch, cfg, "B", B);
  out("Signed in as the two test accounts (credentials read from the Keychain into memory only, nothing printed).");
  const check = makeLaunchCheck({ fetchFn: fetch, cfg, A, B, out, now: () => performance.now(), uuid: () => randomUUID() });
  const result = await check.run();
  if (result.refused) process.exit(3);
  process.exit(result.steps.length > 0 && result.steps.every((s) => s.pass) && !result.stopped ? 0 : 1);
}

main().catch((e) => {
  process.stderr.write(`${e instanceof DrillError ? "REFUSED" : "ERROR"}: ${e instanceof DrillError ? e.message : "unexpected failure"}\n`);
  process.exit(e instanceof DrillError ? 2 : 1);
});
