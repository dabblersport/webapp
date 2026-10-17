// KAN-553: entry point. Run in the CEO's Terminal (it needs the Enter key). See README.md.
import { randomUUID } from "node:crypto";
import { createInterface } from "node:readline";
import { writeFileSync } from "node:fs";
import { SERVICE_A, SERVICE_B, readCredential } from "../realtime/lib/keychain.mjs";
import { FIXTURE_GAME_ID } from "../realtime/lib/guards.mjs";
import { DrillError, assertTestAccount, makeDrill, readConfig, signIn } from "./drill.mjs";

const out = (line) => process.stdout.write(`${line}\n`);

async function main() {
  process.env.MESSAGING_GAME_ID ??= FIXTURE_GAME_ID; // the KAN-545 test game fixture
  const cfg = readConfig(process.env);
  const credA = await readCredential(SERVICE_A);
  const credB = await readCredential(SERVICE_B);
  const A = await signIn(fetch, cfg, credA);
  const B = await signIn(fetch, cfg, credB);
  await assertTestAccount(fetch, cfg, "A", A);
  await assertTestAccount(fetch, cfg, "B", B);
  out("Signed in as the two test accounts (credentials read from the Keychain into memory only, nothing printed).");
  out("Open Cloudflare: Workers -> dabbler-messaging-staging -> Settings -> Variables, edit MESSAGING_ACCESS_MODE.");
  out("The timer starts when you press Enter, so save the variable first and press Enter right after.");

  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const prompt = (text) => new Promise((resolve) => rl.question(`\n>>> ${text}\n`, () => resolve()));
  const drill = makeDrill({
    fetchFn: fetch, cfg, A, B, prompt, out,
    now: () => performance.now(),
    sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
    uuid: () => randomUUID(),
  });
  try {
    const result = await drill.run();
    const file = process.env.DRILL_OUT || new URL("./kan553-drill-result.json", import.meta.url).pathname;
    writeFileSync(file, `${JSON.stringify(result, null, 2)}\n`);
    out(`Result written to ${file} (timings and reasons only). Tell Memphis it is done.`);
  } finally {
    rl.close();
  }
}

main().catch((e) => {
  process.stderr.write(`${e instanceof DrillError ? "REFUSED" : "ERROR"}: ${e instanceof DrillError ? e.message : "unexpected failure"}\n`);
  process.exit(e instanceof DrillError ? 2 : 1);
});
