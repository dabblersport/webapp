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

// Every route that sends p_access_mode: one generic Supabase stub records each RPC body by function name.
describe("valid values reach p_access_mode unchanged on every route that sends it", () => {
  const MSG_ID = "aaaaaaaa-aaaa-4aaa-8aaa-00000000000a";
  const GAME = "99999999-9999-4999-8999-999999999999";
  const ROUTES = ["msg_authorize", "msg_game_conversation", "msg_notify", "msg_typing", "msg_ack_receipt", "msg_report_message", "msg_receipt_summary", "msg_receipt_recipients"];

  for (const v of ["off", "allowlist", "all"]) {
    it(v, async () => {
      const seen: Record<string, unknown[]> = {};
      vi.stubGlobal(
        "fetch",
        vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
          const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
          const fn = url.split("/rpc/")[1];
          if (fn) (seen[fn] ??= []).push(init.body ? JSON.parse(init.body as string).p_access_mode : undefined);
          if (fn === "msg_authorize") return new Response(JSON.stringify([authRow({ member_user_ids: ["real-user", "u2"] })]), { status: 200 });
          if (fn === "msg_game_conversation") return new Response(JSON.stringify([{ user_id: "real-user", conversation_id: CONV_A, allowed_action: "send", reason: null }]), { status: 200 });
          if (fn === "msg_ack_receipt") return new Response(JSON.stringify([{ delivered_seq: 1, seen_seq: 1, advanced: true }]), { status: 200 });
          if (fn === "msg_report_message") return new Response(JSON.stringify([{ report_id: "r", created: true }]), { status: 200 });
          if (fn === "msg_receipt_summary") return new Response(JSON.stringify([]), { status: 200 });
          return new Response(null, { status: 204 });
        }),
      );
      const { mf, db } = await localD1();
      try {
        await db.prepare("INSERT INTO conversation_seq (conversation_id, last_seq) VALUES (?1, 5)").bind(CONV_A).run();
        await db
          .prepare("INSERT INTO messages (id, conversation_id, seq, sender_id, body, created_at, client_key) VALUES (?1, ?2, 1, 'real-user', 'x', 't', 'k1')")
          .bind(MSG_ID, CONV_A)
          .run();
        const e = { ...env(db), MESSAGING_ACCESS_MODE: v, SUPABASE_SERVICE_KEY: "service-key-for-test" } as never;
        const scheduled: Promise<unknown>[] = [];
        const ctx = { waitUntil: (p: Promise<unknown>) => void scheduled.push(p) };
        const json = { ...H };
        const base = `https://worker.local/v1/conversations/${CONV_A}`;
        await worker.fetch(new Request(`https://worker.local/v1/games/${GAME}/conversation`, { headers: H }), e, ctx);
        await worker.fetch(new Request(`${base}/messages`, { method: "POST", headers: { ...json, "Idempotency-Key": "9b2f7c1e-0000-4000-8000-000000000009" }, body: JSON.stringify({ body: "hi" }) }), e, ctx);
        await worker.fetch(new Request(`${base}/typing`, { method: "POST", headers: json, body: JSON.stringify({ typing: true }) }), e, ctx);
        await worker.fetch(new Request(`${base}/receipts`, { method: "POST", headers: json, body: JSON.stringify({ state: "seen", through_seq: 1 }) }), e, ctx);
        await worker.fetch(new Request(`${base}/receipts?seqs=1`, { headers: H }), e, ctx);
        await worker.fetch(new Request(`${base}/receipts/1`, { headers: H }), e, ctx);
        await worker.fetch(new Request(`https://worker.local/v1/messages/${MSG_ID}/report`, { method: "POST", headers: json, body: JSON.stringify({ reason: "spam" }) }), e, ctx);
        await Promise.all(scheduled);
        for (const fn of ROUTES) {
          expect(seen[fn], `${fn} was called`).toBeDefined();
          // msg_receipt_recipients is the elevated call made AFTER msg_authorize; it carries no mode of its own, so
          // its authorisation is proven by msg_authorize receiving v (counted below: send, typing, ack, summary, recipients, report).
          if (fn !== "msg_receipt_recipients") for (const mode of seen[fn]) expect(mode, fn).toBe(v);
        }
        expect(seen.msg_authorize).toEqual([v, v, v, v, v, v]);
      } finally {
        await mf.dispose();
      }
    });
  }
});
