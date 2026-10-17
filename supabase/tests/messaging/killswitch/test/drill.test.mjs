// KAN-553: unit tests with a fake Worker and a fake clock. No network, no Keychain, no real credential.
import test from "node:test";
import assert from "node:assert/strict";
import { DrillError, MARKER, PROJECT_URL, WORKER_HOST, assertTestAccount, isOff, isOpen, makeDrill, readConfig, signIn } from "../drill.mjs";

const GAME = "11111111-1111-4111-8111-111111111111";
const CONV = "22222222-2222-4222-8222-222222222222";
const cfg = { supabaseUrl: PROJECT_URL, anonKey: "anon-key-value", workerUrl: `https://${WORKER_HOST}`, gameId: GAME };

function res(status, json) {
  return { ok: status >= 200 && status < 300, status, json: async () => json };
}

/** A fake Worker whose mode flips `lag` ms after the operator "presses Enter" (the prompt resolves). */
function build({ lagOffMs = 4000, lagOnMs = 7000, writable = true, typedOff = false } = {}) {
  let t = 0;
  let mode = "off";
  let pending = null;
  const prompts = [];
  const lines = [];
  const stored = [];
  const settle = () => {
    if (pending && t >= pending.at) {
      mode = pending.mode;
      pending = null;
    }
  };
  const worker = async (url, init = {}) => {
    settle();
    const path = url.replace(`https://${WORKER_HOST}`, "");
    const off = mode === "off";
    const denied = () => (typedOff ? res(403, { error: { reason: "messaging_off" } }) : res(403, { error: { message: "denied" } }));
    if (path.startsWith(`/v1/games/${GAME}/conversation`)) {
      return off ? denied() : res(200, { id: CONV, writable, read_only_reason: writable ? null : "game_ended" });
    }
    if (init.method === "POST" && path === `/v1/conversations/${CONV}/messages`) {
      if (off) return denied();
      if (!writable) return res(409, { error: { reason: "game_ended" } });
      stored.push(JSON.parse(init.body).body);
      return res(201, { id: "m" });
    }
    if (path.startsWith(`/v1/conversations/${CONV}/messages`)) {
      return off ? denied() : res(200, { messages: stored.map((b) => ({ body: b })) });
    }
    return res(404, {});
  };
  const prompt = async (text) => {
    prompts.push(text);
    t += 500; // the operator presses Enter half a second after the line
    pending = /=allowlist NOW/.test(text) ? { at: t + lagOnMs, mode: "allowlist" } : { at: t + lagOffMs, mode: "off" };
  };
  let n = 0;
  const deps = {
    fetchFn: worker, cfg, A: { token: "token-a-value", uid: "ua" }, B: { token: "token-b-value", uid: "ub" }, prompt,
    now: () => t, sleep: async (ms) => { t += ms; }, out: (l) => lines.push(l),
    uuid: () => `${String(++n).padStart(8, "0")}-0000-4000-8000-000000000000`,
  };
  return { deps, prompts, lines, stored };
}

test("the full drill measures six timings from the Enter press and ends on off", async () => {
  const w = build();
  const r = await makeDrill(w.deps).run();
  assert.equal(r.trials.length, 3);
  for (const t of r.trials) {
    assert.ok(t.off.getMs >= 4000 && t.off.getMs < 6000, `off get ${t.off.getMs}`);
    assert.ok(t.off.postMs >= 4000 && t.off.postMs < 9000);
    assert.ok(t.on.getMs >= 7000 && t.on.getMs < 9000);
    assert.ok(t.on.postMs >= 7000 && t.on.postMs < 12000);
  }
  assert.equal(r.allWithin60s, true);
  assert.equal(r.finalValueOffVerified, true);
  assert.equal(r.setup.roundTrip, true);
  assert.equal(w.prompts.filter((p) => /=allowlist NOW/.test(p)).length, 4);
  assert.equal(w.prompts.filter((p) => /=off NOW/.test(p)).length, 4);
  assert.equal(w.prompts[0], "SET MESSAGING_ACCESS_MODE=allowlist NOW, then press Enter");
  assert.ok(w.lines.some((l) => l.startsWith("DRILL_RESULT ")));
});

test("a slow edit (over 60 s) is reported as not within 60 s", async () => {
  const w = build({ lagOffMs: 75_000 });
  const r = await makeDrill(w.deps).run();
  assert.equal(r.allWithin60s, false);
  assert.ok(r.trials[0].off.getMs > 60_000);
});

test("an ended game still measures the gate: send is refused with a typed non-kill-switch reason", async () => {
  const w = build({ writable: false });
  const r = await makeDrill(w.deps).run();
  assert.equal(r.setup.writable, false);
  assert.equal(r.setup.roundTrip, null);
  assert.equal(r.allWithin60s, true);
  assert.equal(w.stored.length, 0);
});

test("output carries no token, anon key or message text", async () => {
  const w = build();
  await makeDrill(w.deps).run();
  const all = w.lines.join("\n");
  assert.ok(!all.includes("token-a-value") && !all.includes("token-b-value") && !all.includes("anon-key-value"));
  assert.ok(!all.includes(`${MARKER} `), "message text must not be printed");
});

test("readConfig refuses a wrong project, a wrong Worker and a bad game id", () => {
  const base = { SUPABASE_URL: PROJECT_URL, SUPABASE_ANON_KEY: "k", MESSAGING_GAME_ID: GAME };
  assert.equal(readConfig(base).workerUrl, `https://${WORKER_HOST}`);
  assert.throws(() => readConfig({ ...base, SUPABASE_URL: "https://other.supabase.co" }), DrillError);
  assert.throws(() => readConfig({ ...base, MESSAGING_WORKER_URL: "https://evil.example" }), DrillError);
  assert.throws(() => readConfig({ ...base, MESSAGING_GAME_ID: "nope" }), DrillError);
  assert.throws(() => readConfig({ SUPABASE_URL: PROJECT_URL }), DrillError);
});

test("signIn returns only the session; assertTestAccount refuses a non-test account", async () => {
  const f = async (url) =>
    url.includes("/auth/v1/token") ? res(200, { access_token: "tok", user: { id: "uid" } }) : res(200, [{ username: "someone", display_name: "Real Person" }]);
  const s = await signIn(f, cfg, { email: "e", password: "p" });
  assert.deepEqual(s, { token: "tok", uid: "uid" });
  await assert.rejects(() => assertTestAccount(f, cfg, "A", s), DrillError);
  const ok = async () => res(200, [{ username: "dabbler_test_1", display_name: "Test One" }]);
  await assertTestAccount(ok, cfg, "A", s);
});

test("the real off answer is 403 with no reason: it is the off signal (drill run 1 reported NOT SEEN before this)", async () => {
  const w = build(); // default fake: 403 {error:{message}} without a reason
  const r = await makeDrill(w.deps).run();
  assert.ok(r.trials[0].off.getMs !== null && r.trials[0].off.postMs !== null);
  assert.equal(r.trials[0].off.getReason, null);
  assert.equal(r.allWithin60s, true);
  assert.ok(w.lines.some((l) => /GET refused \(403, the off signal\)/.test(l)));
});

test("a typed messaging_off is still accepted as the off signal", async () => {
  const w = build({ typedOff: true });
  const r = await makeDrill(w.deps).run();
  assert.equal(r.allWithin60s, true);
  assert.equal(r.trials[0].off.getReason, "messaging_off");
});

test("isOff and isOpen classify the answers", () => {
  assert.equal(isOff({ status: 403, reason: null }), true);
  assert.equal(isOff({ status: 403, reason: "messaging_off" }), true);
  assert.equal(isOff({ status: 403, reason: "not_in_pilot" }), false); // a different refusal, not the kill switch
  assert.equal(isOff({ status: 401, reason: null }), false);
  assert.equal(isOff({ status: 200, reason: null }), false);
  assert.equal(isOff({ status: 0, reason: null, networkError: true }), false);
  assert.equal(isOff({ status: 502, reason: null }), false);
  assert.equal(isOpen({ status: 200, reason: null }), true);
  assert.equal(isOpen({ status: 201, reason: null }), true);
  assert.equal(isOpen({ status: 409, reason: "game_ended" }), true); // past the gate: the fixture game is over
  assert.equal(isOpen({ status: 429, reason: "rate_limited" }), true);
  assert.equal(isOpen({ status: 403, reason: null }), false);
  assert.equal(isOpen({ status: 403, reason: "not_in_pilot" }), false);
  assert.equal(isOpen({ status: 401, reason: null }), false);
  assert.equal(isOpen({ status: 500, reason: null }), false);
  assert.equal(isOpen({ status: 0, reason: null, networkError: true }), false);
});
