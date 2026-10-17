// KAN-553: the kill-switch drill. The operator flips MESSAGING_ACCESS_MODE in the Cloudflare dashboard at this
// script's prompts; the script measures, from the Enter press, how long the live Worker takes to refuse (off) and
// to accept again (allowlist), as the two test accounts. Everything external is injected so the logic is unit tested
// with fakes. It never prints, logs or writes a credential, token, key or message text: only reasons, status codes,
// counts and timings. It does not change any variable, deploy anything or touch the database; the only writes are the
// drill's own short test messages in the fixture game, through the Worker's normal send route.

export const PROJECT_URL = "https://wtncuzcskpigqpmnxwws.supabase.co";
export const WORKER_HOST = "dabbler-messaging-staging.dabbler-sport.workers.dev";
export const MARKER = "kan553-drill";
export const WITHIN_MS = 60_000;
const TIMEOUT_MS = 120_000;
const GET_EVERY_MS = 1000;
const POST_EVERY_MS = 3000;

export class DrillError extends Error {}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function readConfig(env) {
  const need = ["SUPABASE_URL", "SUPABASE_ANON_KEY", "MESSAGING_GAME_ID"];
  const missing = need.filter((k) => !env[k]);
  if (missing.length > 0) throw new DrillError(`missing environment: ${missing.join(", ")}`);
  if (env.SUPABASE_URL.replace(/\/+$/, "") !== PROJECT_URL) throw new DrillError("SUPABASE_URL is not the Dabbler project");
  if (!UUID.test(env.MESSAGING_GAME_ID)) throw new DrillError("MESSAGING_GAME_ID is not a uuid");
  const workerUrl = (env.MESSAGING_WORKER_URL || `https://${WORKER_HOST}`).replace(/\/+$/, "");
  if (workerUrl !== `https://${WORKER_HOST}`) throw new DrillError("MESSAGING_WORKER_URL is not the production messaging Worker");
  return { supabaseUrl: PROJECT_URL, anonKey: env.SUPABASE_ANON_KEY, workerUrl, gameId: env.MESSAGING_GAME_ID.toLowerCase() };
}

/** Signs in with the password grant over HTTPS; returns the access token and user id. Values stay in memory. */
export async function signIn(fetchFn, cfg, cred) {
  const res = await fetchFn(`${cfg.supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: cfg.anonKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email: cred.email, password: cred.password }),
  });
  if (!res.ok) throw new DrillError("sign-in failed");
  const j = await res.json();
  if (typeof j.access_token !== "string" || typeof j.user?.id !== "string") throw new DrillError("sign-in returned no session");
  return { token: j.access_token, uid: j.user.id };
}

/** Guard: every profile of the account carries "test" in its username or display name. */
export async function assertTestAccount(fetchFn, cfg, label, session) {
  const res = await fetchFn(
    `${cfg.supabaseUrl}/rest/v1/profiles?select=username,display_name&user_id=eq.${session.uid}`,
    { headers: { apikey: cfg.anonKey, Authorization: `Bearer ${session.token}` } },
  );
  if (!res.ok) throw new DrillError(`${label}: profile unreadable`);
  const rows = await res.json();
  const isTest = (r) => /test/i.test(`${r.username ?? ""} ${r.display_name ?? ""}`);
  if (!Array.isArray(rows) || rows.length === 0 || !rows.every(isTest)) throw new DrillError(`${label}: not a test account, refusing`);
}

/** One Worker call. Returns status, the typed reason (or null), and for a list the count of drill messages. */
export async function call(fetchFn, cfg, session, method, path, { body, idempotencyKey } = {}) {
  const headers = { Authorization: `Bearer ${session.token}`, "Content-Type": "application/json" };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  let res;
  try {
    res = await fetchFn(`${cfg.workerUrl}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  } catch {
    return { status: 0, reason: null, networkError: true };
  }
  let json = null;
  try {
    json = await res.json();
  } catch {
    json = null;
  }
  const reason = json && typeof json === "object" && json.error && typeof json.error.reason === "string" ? json.error.reason : null;
  const out = { status: res.status, reason };
  if (res.ok && json && Array.isArray(json.messages)) {
    out.drillMessages = json.messages.filter((m) => typeof m?.body === "string" && m.body.startsWith(MARKER)).length;
  }
  if (res.ok && json && typeof json.id === "string") out.conversationId = json.id;
  if (res.ok && json && typeof json.writable === "boolean") {
    out.writable = json.writable;
    out.readOnlyReason = json.read_only_reason ?? null;
  }
  return out;
}

const fmt = (ms) => (ms === null ? "NOT SEEN" : `${(ms / 1000).toFixed(1)} s`);
const within = (ms) => ms !== null && ms <= WITHIN_MS;

export function makeDrill(deps) {
  const { fetchFn, cfg, A, B, prompt, now, sleep, out, uuid } = deps;
  let conversationId = null;

  const getList = (session) => call(fetchFn, cfg, session, "GET", `/v1/conversations/${conversationId}/messages?limit=50`);
  const getConv = (session) => call(fetchFn, cfg, session, "GET", `/v1/games/${cfg.gameId}/conversation`);
  const post = (session) =>
    call(fetchFn, cfg, session, "POST", `/v1/conversations/${conversationId}/messages`, {
      body: { body: `${MARKER} ${uuid().slice(0, 8)}` },
      idempotencyKey: uuid(),
    });

  // A POST has passed the access gate when it was created/ok, or refused for a reason that is not the kill switch
  // (for example game_ended or rate_limited): the gate comes first, so any other typed answer means "on".
  const postPassedGate = (r) => (r.status >= 200 && r.status < 300) || (r.reason !== null && r.reason !== "messaging_off" && r.reason !== "not_in_pilot");

  async function waitPhase(label, t0, targetGet, targetPost) {
    const res = { getMs: null, postMs: null, getReason: null, postReason: null, lastGetStatus: null, lastPostStatus: null };
    let nextPost = 0;
    while (now() - t0 < TIMEOUT_MS && (res.getMs === null || res.postMs === null)) {
      const elapsed = now() - t0;
      if (res.getMs === null) {
        const g = await (conversationId ? getList(A) : getConv(A));
        res.lastGetStatus = g.status;
        res.getReason = g.reason;
        if (targetGet(g)) res.getMs = now() - t0;
      }
      if (res.postMs === null && conversationId && elapsed >= nextPost) {
        const p = await post(A);
        nextPost = elapsed + POST_EVERY_MS;
        res.lastPostStatus = p.status;
        res.postReason = p.reason;
        if (targetPost(p)) res.postMs = now() - t0;
      }
      if (res.getMs === null || res.postMs === null) await sleep(GET_EVERY_MS);
    }
    return res;
  }

  const refusedGet = (r) => r.reason === "messaging_off";
  const refusedPost = (r) => r.reason === "messaging_off";
  const acceptedGet = (r) => r.status >= 200 && r.status < 300;

  async function setup() {
    out("Step 0: the Worker should currently be \"off\". Checking that the kill switch is on before the drill starts.");
    const g0 = await getConv(A);
    out(`  start state: GET game conversation as A -> status ${g0.status}, reason ${g0.reason ?? "none"}`);
    if (g0.reason !== "messaging_off") out("  NOTE: the start value is not \"off\" (expected). Continuing; the final value must still be \"off\".");
    await prompt("SET MESSAGING_ACCESS_MODE=allowlist NOW, then press Enter");
    const t0 = now();
    // First accepted request. The conversation id is only returned once allowed.
    let g = null;
    while (now() - t0 < TIMEOUT_MS) {
      g = await getConv(A);
      if (g.status === 200 && g.conversationId) break;
      await sleep(GET_EVERY_MS);
    }
    if (!g || g.status !== 200 || !g.conversationId) throw new DrillError("the Worker did not accept a request after the variable was set to allowlist within 120 s");
    conversationId = g.conversationId;
    const setupMs = now() - t0;
    const gb = await getConv(B);
    const l = await getList(A);
    out(`Step 1 (set allowlist, warm-up): first accepted GET after ${fmt(setupMs)}; game chat writable=${g.writable}${g.readOnlyReason ? ` (${g.readOnlyReason})` : ""}; B accepted=${gb.status === 200}; A list status ${l.status}`);
    let roundTrip = null;
    let sendStatus = null;
    const p = await post(A);
    sendStatus = p.status;
    if (p.status === 201 || p.status === 200) {
      const bl = await getList(B);
      roundTrip = bl.status === 200 && (bl.drillMessages ?? 0) >= 1;
      out(`  test message: POST as A -> ${p.status}; B list shows the drill message: ${roundTrip}`);
    } else {
      out(`  test message: POST as A -> status ${p.status}, reason ${p.reason ?? "none"} (a send is not possible in this fixture state; the gate itself is open)`);
    }
    return { setupMs, writable: g.writable, readOnlyReason: g.readOnlyReason ?? null, sendStatus, sendReason: p.reason, roundTrip, bAccepted: gb.status === 200 };
  }

  async function trial(i) {
    await prompt("SET MESSAGING_ACCESS_MODE=off NOW, then press Enter");
    const tOff = now();
    const off = await waitPhase("off", tOff, refusedGet, refusedPost);
    out(`Trial ${i} OFF: GET refused (messaging_off) after ${fmt(off.getMs)}; POST refused (messaging_off) after ${fmt(off.postMs)}; within 60 s: ${within(off.getMs) && within(off.postMs)}`);
    await prompt("SET MESSAGING_ACCESS_MODE=allowlist NOW, then press Enter");
    const tOn = now();
    const on = await waitPhase("on", tOn, acceptedGet, postPassedGate);
    out(`Trial ${i} RESTORE: first accepted GET after ${fmt(on.getMs)}; first POST past the gate after ${fmt(on.postMs)}; within 60 s: ${within(on.getMs) && within(on.postMs)}`);
    return { off, on };
  }

  async function finalOff() {
    await prompt("SET MESSAGING_ACCESS_MODE=off NOW (final value), then press Enter");
    const t = now();
    const off = await waitPhase("final", t, refusedGet, refusedPost);
    out(`FINAL OFF: GET refused after ${fmt(off.getMs)}; POST refused after ${fmt(off.postMs)}`);
    return off;
  }

  async function run() {
    const s = await setup();
    const trials = [];
    for (let i = 1; i <= 3; i += 1) trials.push(await trial(i));
    const final = await finalOff();
    const ok =
      trials.every((t) => within(t.off.getMs) && within(t.off.postMs) && within(t.on.getMs) && within(t.on.postMs)) &&
      final.getMs !== null && final.postMs !== null;
    const result = { setup: s, trials, final, allWithin60s: ok, finalValueOffVerified: final.getMs !== null && final.postMs !== null };
    out(`SUMMARY: all six timings within 60 s and the final value is off: ${ok}`);
    out(`DRILL_RESULT ${JSON.stringify(result)}`);
    return result;
  }

  return { run, setup, trial, finalOff, postPassedGate };
}
