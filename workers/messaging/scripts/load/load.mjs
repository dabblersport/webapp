#!/usr/bin/env node
// KAN-506 (T10) messaging load script -- D26 bar (RECOMMENDED, NOT YET CEO-APPROVED).
// AUTHORED, NOT RUN: not run against any real stack. Only its dry-run and refusal paths are exercised, by tests.
//
// Target: ONLY the base URL in MESSAGING_LOAD_BASE_URL (no default). Refuses unless the host is
// localhost / 127.0.0.1 / ::1, or exactly listed in MESSAGING_LOAD_ALLOW_HOST (a CEO-approved non-production host).
// Token: MESSAGING_LOAD_TOKEN (no default; required unless the path is /health).
//
// D26: phase 1 sustains 2 x PILOT_PEAK_RPS for DURATION_S; then steps the rate up by STEP_PCT per step
// (STEP_DURATION_S each) until the error-rate or p95 budget is breached (or MAX_STEPS), and RECORDS the ceiling:
// the highest rate that stayed within budget. Results: JSON + text summary under scripts/load/results/ (gitignored).
//
// Usage: node scripts/load/load.mjs [--dry-run]

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const LOCAL_HOSTS = new Set(["localhost", "127.0.0.1", "::1", "[::1]"]);

function num(env, name, dflt, { required = false, min = 0 } = {}) {
  const raw = env[name];
  if (raw === undefined || raw === "") {
    if (required) throw new Error(`REFUSED: ${name} is required`);
    return dflt;
  }
  const v = Number(raw);
  if (!Number.isFinite(v) || v <= min) throw new Error(`REFUSED: ${name} must be a number > ${min}`);
  return v;
}

/** Validates config. Throws an Error whose message starts with "REFUSED:" on any refusal. Sends nothing. */
export function validateConfig(env) {
  const base = env.MESSAGING_LOAD_BASE_URL;
  if (!base) throw new Error("REFUSED: MESSAGING_LOAD_BASE_URL is unset (there is no default host)");
  let url;
  try {
    url = new URL(base);
  } catch {
    throw new Error("REFUSED: MESSAGING_LOAD_BASE_URL is not a valid URL");
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") throw new Error("REFUSED: only http(s) is allowed");
  const host = url.hostname;
  const allowed = (env.MESSAGING_LOAD_ALLOW_HOST ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!LOCAL_HOSTS.has(host) && !allowed.includes(host)) {
    throw new Error(`REFUSED: host ${host} is not local and not listed exactly in MESSAGING_LOAD_ALLOW_HOST`);
  }
  const path = env.MESSAGING_LOAD_PATH || "/health";
  if (!path.startsWith("/")) throw new Error("REFUSED: MESSAGING_LOAD_PATH must start with /");
  const token = env.MESSAGING_LOAD_TOKEN;
  if (path !== "/health" && !token) throw new Error("REFUSED: MESSAGING_LOAD_TOKEN is required for a protected path");

  const pilotPeak = num(env, "PILOT_PEAK_RPS", undefined, { required: true });
  return {
    target: new URL(path, url).href,
    host,
    hasToken: Boolean(token),
    token,
    pilotPeakRps: pilotPeak,
    sustainRps: 2 * pilotPeak,
    durationS: num(env, "DURATION_S", 60),
    stepPct: num(env, "STEP_PCT", 25),
    stepDurationS: num(env, "STEP_DURATION_S", 30),
    maxSteps: num(env, "MAX_STEPS", 10),
    maxErrorRate: num(env, "MAX_ERROR_RATE", 0.01),
    p95BudgetMs: num(env, "P95_BUDGET_MS", 500),
    timeoutMs: num(env, "TIMEOUT_MS", 5000),
  };
}

/** The phases the run would execute. */
export function plan(cfg) {
  const phases = [{ name: "sustain-2x-pilot-peak", rps: cfg.sustainRps, durationS: cfg.durationS }];
  let rps = cfg.sustainRps;
  for (let i = 1; i <= cfg.maxSteps; i++) {
    rps = Math.ceil(rps * (1 + cfg.stepPct / 100));
    phases.push({ name: `step-${i}`, rps, durationS: cfg.stepDurationS });
  }
  return phases;
}

function p95(xs) {
  if (xs.length === 0) return 0;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor(0.95 * s.length))];
}

async function runPhase(cfg, phase, doFetch) {
  const lat = [];
  let errors = 0;
  let sent = 0;
  const inflight = [];
  const intervalMs = 1000 / phase.rps;
  const end = Date.now() + phase.durationS * 1000;
  let next = Date.now();
  while (Date.now() < end) {
    const t0 = Date.now();
    sent++;
    inflight.push(
      doFetch(cfg.target, {
        headers: cfg.token ? { Authorization: `Bearer ${cfg.token}` } : {},
        signal: AbortSignal.timeout(cfg.timeoutMs),
      })
        .then((r) => {
          if (!r.ok) errors++;
          return r.arrayBuffer();
        })
        .catch(() => errors++)
        .finally(() => lat.push(Date.now() - t0)),
    );
    next += intervalMs;
    const wait = next - Date.now();
    if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  }
  await Promise.all(inflight);
  const errorRate = sent ? errors / sent : 0;
  const p = p95(lat);
  return { ...phase, sent, errors, errorRate, p95Ms: p, withinBudget: errorRate <= cfg.maxErrorRate && p <= cfg.p95BudgetMs };
}

export async function run(env, { dryRun = false, doFetch = globalThis.fetch, out = console.log } = {}) {
  const cfg = validateConfig(env);
  const phases = plan(cfg);
  const safeCfg = { ...cfg, token: cfg.token ? "<set>" : "<unset>" };
  if (dryRun) {
    out(JSON.stringify({ dryRun: true, config: safeCfg, phases }, null, 2));
    return { dryRun: true, config: safeCfg, phases };
  }
  const results = [];
  let ceilingRps = null;
  for (const phase of phases) {
    const r = await runPhase(cfg, phase, doFetch);
    results.push(r);
    out(`${r.name}: ${r.rps} rps, sent ${r.sent}, errors ${r.errors}, p95 ${r.p95Ms} ms, within budget ${r.withinBudget}`);
    if (!r.withinBudget) break;
    ceilingRps = r.rps;
  }
  const sustainPassed = results[0]?.withinBudget === true;
  const report = { config: safeCfg, sustainPassed, ceilingRps, results, finishedAt: new Date().toISOString() };
  const dir = join(dirname(fileURLToPath(import.meta.url)), "results");
  mkdirSync(dir, { recursive: true });
  const stamp = report.finishedAt.replace(/[:.]/g, "-");
  writeFileSync(join(dir, `load-${stamp}.json`), JSON.stringify(report, null, 2));
  writeFileSync(
    join(dir, `load-${stamp}.txt`),
    `target ${cfg.target}\nsustain 2x pilot peak (${cfg.sustainRps} rps for ${cfg.durationS}s): ${sustainPassed ? "PASS" : "FAIL"}\n` +
      `recorded ceiling: ${ceilingRps ?? "none within budget"} rps\n`,
  );
  return report;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run(process.env, { dryRun: process.argv.includes("--dry-run") }).catch((e) => {
    console.error(e.message);
    process.exit(2);
  });
}
