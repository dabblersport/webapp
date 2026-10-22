// KAN-625: MESSAGING_ACCESS_MODE is dashboard-only and the Worker fails closed. Absent, empty or anything other than
// exactly off|allowlist|all is sent to msg_authorize as 'off', which the RPC refuses (messaging_off -> 403, no reason).
import { afterEach, describe, expect, it, vi } from "vitest";
import { accessMode } from "../src/auth";
import worker from "../src/index";
import { CONV_A, authRow, env, localD1, mockFetch, spyDb } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

const H = { Authorization: "Bearer any.token.here", "content-type": "application/json" };
const URL_MSGS = `https://worker.local/v1/conversations/${CONV_A}/messages`;

// The RPC answers by the mode it is handed: off -> messaging_off, otherwise a member who may send.
function rpcByMode() {
  return mockFetch(() => new Response(JSON.stringify([authRow()]), { status: 200 }));
}
function rpcOff() {
  return mockFetch(() => new Response(JSON.stringify([authRow({ allowed_action: null, reason: "messaging_off" })]), { status: 200 }));
}

const listWith = (db: D1Database, extra: Record<string, unknown>) =>
  worker.fetch(new Request(URL_MSGS, { headers: H }), { ...env(db), ...extra } as never);
const sendWith = (db: D1Database, extra: Record<string, unknown>) =>
  worker.fetch(
    new Request(URL_MSGS, { method: "POST", headers: { ...H, "Idempotency-Key": "9b2f7c1e-0000-4000-8000-000000000001" }, body: JSON.stringify({ body: "hi" }) }),
    { ...env(db), ...extra } as never,
  );

// "absent" removes the variable; the others set it.
const BAD: [string, Record<string, unknown>][] = [
  ["absent", { MESSAGING_ACCESS_MODE: undefined }],
  ["empty string", { MESSAGING_ACCESS_MODE: "" }],
  ["ALL (wrong case)", { MESSAGING_ACCESS_MODE: "ALL" }],
  ["garbage", { MESSAGING_ACCESS_MODE: "everyone" }],
];

describe("accessMode() fails closed", () => {
  for (const [name, extra] of BAD) {
    it(`${name} -> off`, () => expect(accessMode({ ...env({} as D1Database), ...extra } as never)).toBe("off"));
  }
  for (const v of ["off", "allowlist", "all"]) {
    it(`${v} passes through unchanged`, () => expect(accessMode({ ...env({} as D1Database), MESSAGING_ACCESS_MODE: v } as never)).toBe(v));
  }
});

describe("bad values: the Worker asks for 'off' and the refusal is the KAN-553 off signal", () => {
  for (const [name, extra] of BAD) {
    it(`${name}: list and send are 403 with no reason, p_access_mode 'off', zero DB`, async () => {
      const { calls } = rpcOff();
      const { db, touched } = spyDb();
      for (const res of [await listWith(db, extra), await sendWith(db, extra)]) {
        expect(res.status).toBe(403);
        expect(((await res.json()) as any).error.reason).toBeUndefined();
      }
      expect(calls).toHaveLength(2);
      for (const c of calls) expect(JSON.parse(c.init.body as string).p_access_mode).toBe("off");
      expect(touched).toEqual([]);
    });
  }
});

describe("valid values pass through unchanged on list and send", () => {
  for (const v of ["off", "allowlist", "all"]) {
    it(v, async () => {
      const { calls } = rpcByMode();
      const { mf, db } = await localD1();
      try {
        await listWith(db, { MESSAGING_ACCESS_MODE: v });
        await sendWith(db, { MESSAGING_ACCESS_MODE: v });
        expect(calls.map((c) => JSON.parse(c.init.body as string).p_access_mode)).toEqual([v, v]);
      } finally {
        await mf.dispose();
      }
    });
  }
});
