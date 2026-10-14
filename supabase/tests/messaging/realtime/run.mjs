#!/usr/bin/env node
// KAN-545 entry point. See README.md. Prints PASS/FAIL/N-A/NOT RUN lines only.
import { createClient } from "@supabase/supabase-js";
import { runLive } from "./lib/live.mjs";
import { makeReporter } from "./lib/report.mjs";
import { SERVICE_A, SERVICE_B, readCredential } from "./lib/keychain.mjs";

const reporter = makeReporter();
try {
  const results = await runLive({
    env: process.env,
    reporter,
    readCredential,
    serviceA: SERVICE_A,
    serviceB: SERVICE_B,
    createClient,
    fetchFn: fetch,
    sleep: (ms) => new Promise((r) => setTimeout(r, ms)),
    now: () => Date.now(),
  });
  process.exitCode = results.some((r) => r.status === "FAIL") ? 1 : 0;
} catch (e) {
  // Only the guard code and its fixed message are printed, never a stack that could carry a value.
  reporter.note(`REFUSED/ERROR ${e?.name ?? "Error"} ${e?.code ?? ""}: ${e instanceof Error ? e.message : "unexpected error"}`);
  process.exitCode = 2;
}
