// KAN-554: unit tests with a fake Worker. No network, no Keychain, no real credential.
import test from "node:test";
import assert from "node:assert/strict";
import { NOT_ALL_YET, makeLaunchCheck } from "../launchcheck.mjs";
import { PROJECT_URL, WORKER_HOST } from "../../killswitch/drill.mjs";

const GAME = "11111111-1111-4111-8111-111111111111";
const CONV = "22222222-2222-4222-8222-222222222222";
const cfg = { supabaseUrl: PROJECT_URL, anonKey: "anon-key-value", workerUrl: `https://${WORKER_HOST}`, gameId: GAME };
const A = { token: "tokA", uid: "a" };
const B = { token: "tokB", uid: "b" };
const res = (status, json) => ({ ok: status >= 200 && status < 300, status, json: async () => json });

function build({ off = false, writable = true, listed = true, reportStatus = 202 } = {}) {
  const stored = [];
  const fetchFn = async (url, init = {}) => {
    const path = url.replace(`https://${WORKER_HOST}`, "");
    if (url.includes("/rest/v1/rpc/msg_my_conversations")) return res(200, [{ conversation_id: CONV }]);
    if (off) return res(403, { error: { message: "denied" } });
    if (path.startsWith(`/v1/games/${GAME}/conversation`)) return res(200, { id: CONV, writable, read_only_reason: writable ? null : "game_ended" });
    if (init.method === "POST" && path === `/v1/conversations/${CONV}/messages`) {
      stored.push(JSON.parse(init.body).body);
      return res(201, { id: "m1" });
    }
    if (path.startsWith(`/v1/conversations/${CONV}/messages`)) return res(200, { messages: listed ? stored.map((b) => ({ id: "m1", body: b })) : [] });
    if (path === "/v1/messages/m1/report") return res(reportStatus, {});
    return res(404, {});
  };
  const lines = [];
  let t = 0;
  const check = makeLaunchCheck({ fetchFn, cfg, A, B, out: (l) => lines.push(l), now: () => (t += 10), uuid: () => "abcdef12-0000-4000-8000-000000000000" });
  return { check, lines, stored };
}

test("refuses with the exact message while the Worker is off, and sends nothing", async () => {
  const { check, lines, stored } = build({ off: true });
  const r = await check.run();
  assert.equal(r.refused, true);
  assert.ok(lines.includes(NOT_ALL_YET));
  assert.equal(stored.length, 0);
});

test("all steps pass against an open Worker, and only counts and statuses are printed", async () => {
  const { check, lines, stored } = build();
  const r = await check.run();
  assert.equal(r.refused, false);
  assert.equal(r.steps.length, 7);
  assert.ok(r.steps.every((s) => s.pass));
  assert.equal(stored.length, 1);
  const text = lines.join("\n");
  assert.ok(!text.includes(CONV) && !text.includes(GAME) && !text.includes("tokA") && !text.includes(stored[0]));
});

test("an ended game stops before any send", async () => {
  const { check, stored } = build({ writable: false });
  const r = await check.run();
  assert.equal(r.stopped, "not-writable");
  assert.equal(stored.length, 0);
});

test("a message B cannot list fails the round trip, and a refused report fails step 5", async () => {
  const a = await build({ listed: false }).check.run();
  assert.equal(a.steps.find((s) => s.name.startsWith("4")).pass, false);
  const b = await build({ reportStatus: 403 }).check.run();
  assert.equal(b.steps.find((s) => s.name.startsWith("5")).pass, false);
});
