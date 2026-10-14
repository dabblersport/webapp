// KAN-512 (T17) report, legal hold and group block filter. LOCAL-EMULATOR TESTS: Miniflare in-memory D1 + mocked
// msg_authorize and msg_report_message. No network.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { deleteMessagesIfNotHeld, expireMessagesBefore, setLegalHold } from "../src/retention";
import { CONV_A, RPC_URL, SUPABASE_URL, authRow, env, localD1 } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

const REPORT_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_report_message`;
const KEY = (n: number) => `9b2f7c1e-0000-4000-8000-${String(n).padStart(12, "0")}`;
const H = { Authorization: "Bearer any.token.here", "content-type": "application/json" };
const SECRET_TEXT = "secret-body-text-never-relayed";

/**
 * Two mocked RPCs. msg_authorize answers `state.auth`. msg_report_message keeps an in-memory reports table
 * with the SQL function's semantics: refuse (403) a non-member, at most one row per (reporter, message).
 */
function rpcs() {
  const state = { auth: authRow() as Record<string, unknown> };
  const reports: { reporter: string; message: string; reason: string }[] = [];
  const reportBodies: unknown[] = [];
  const unmocked: string[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      if (url === RPC_URL) return new Response(JSON.stringify([state.auth]), { status: 200 });
      if (url === REPORT_URL) {
        const body = JSON.parse(init.body as string);
        reportBodies.push(body);
        if (state.auth.allowed_action === null) return new Response("{}", { status: 403 });
        const reporter = state.auth.user_id as string;
        const prior = reports.find((r) => r.reporter === reporter && r.message === body.p_message_id);
        if (!prior) reports.push({ reporter, message: body.p_message_id, reason: body.p_reason });
        return new Response(JSON.stringify([{ report_id: "r", created: !prior }]), { status: 200 });
      }
      unmocked.push(url);
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { state, reports, reportBodies, unmocked };
}

const send = (db: D1Database, key: string, body: string) =>
  worker.fetch(
    new Request(`https://worker.local/v1/conversations/${CONV_A}/messages`, {
      method: "POST",
      headers: { ...H, "Idempotency-Key": key },
      body: JSON.stringify({ body }),
    }),
    env(db),
  );
const report = (db: D1Database, id: string, reason: unknown = "spam", extra: Record<string, unknown> = {}) =>
  worker.fetch(
    new Request(`https://worker.local/v1/messages/${id}/report`, {
      method: "POST",
      headers: H,
      body: JSON.stringify({ reason, ...extra }),
    }),
    env(db),
  );
const list = (db: D1Database, qs = "") =>
  worker.fetch(new Request(`https://worker.local/v1/conversations/${CONV_A}/messages${qs}`, { headers: H }), env(db));

async function sendAs(db: D1Database, m: ReturnType<typeof rpcs>, user: string, key: number, body = `m${key}`) {
  m.state.auth = authRow({ user_id: user });
  const r = await send(db, KEY(key), body);
  expect(r.status).toBe(201);
  return ((await r.json()) as { id: string }).id;
}

const hold = async (db: D1Database, id: string) =>
  (await db.prepare("SELECT legal_hold FROM messages WHERE id = ?1").bind(id).first<{ legal_hold: number }>())?.legal_hold;

describe("report", () => {
  it("a non-member cannot report; nothing recorded, no hold", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const id = await sendAs(db, m, "alice", 1);
      m.state.auth = authRow({ user_id: "mallory", allowed_action: null, reason: "not_member" });
      const r = await report(db, id);
      expect(r.status).toBe(403);
      expect(((await r.json()) as any).error.reason).toBe("not_a_member");
      expect(m.reports).toEqual([]);
      expect(m.reportBodies).toEqual([]); // denied before the report RPC
      expect(await hold(db, id)).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a member can report: 202, one report, legal hold set", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const id = await sendAs(db, m, "alice", 1);
      m.state.auth = authRow({ user_id: "bob" });
      const r = await report(db, id, "harassment");
      expect(r.status).toBe(202);
      expect(m.reports).toEqual([{ reporter: "bob", message: id, reason: "harassment" }]);
      expect(await hold(db, id)).toBe(1);
      expect(m.unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });

  it("a member who left cannot report a message after left_at_seq, can report one before", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const a = await sendAs(db, m, "alice", 1);
      const b = await sendAs(db, m, "alice", 2);
      m.state.auth = authRow({ user_id: "carol", allowed_action: "read", reason: "left", left_at_seq: 1 });
      expect((await report(db, b)).status).toBe(403);
      expect((await report(db, a)).status).toBe(202);
    } finally {
      await mf.dispose();
    }
  });

  it("a repeat report by the same reporter does not duplicate", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const id = await sendAs(db, m, "alice", 1);
      m.state.auth = authRow({ user_id: "bob" });
      expect((await report(db, id)).status).toBe(202);
      expect((await report(db, id, "abuse")).status).toBe(202);
      expect(m.reports.length).toBe(1);
    } finally {
      await mf.dispose();
    }
  });

  it("the report RPC body carries ids and reason only, never message text", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const id = await sendAs(db, m, "alice", 1, SECRET_TEXT);
      m.state.auth = authRow({ user_id: "bob" });
      expect((await report(db, id, "spam", { body: SECRET_TEXT, details: SECRET_TEXT })).status).toBe(202);
      expect(m.reportBodies.length).toBe(1);
      const body = m.reportBodies[0] as Record<string, unknown>;
      expect(Object.keys(body).sort()).toEqual(["p_access_mode", "p_conversation_id", "p_message_id", "p_message_seq", "p_reason"]);
      expect(body).toEqual({ p_conversation_id: CONV_A, p_message_id: id, p_message_seq: 1, p_reason: "spam", p_access_mode: "allowlist" });
      expect(JSON.stringify(body)).not.toContain(SECRET_TEXT);
    } finally {
      await mf.dispose();
    }
  });

  it("rejects a reason outside the ten, a bad id, a missing bearer and an unknown message", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const id = await sendAs(db, m, "alice", 1);
      expect((await report(db, id, "rude")).status).toBe(400);
      expect((await report(db, "not-a-uuid")).status).toBe(400);
      const noAuth = await worker.fetch(
        new Request(`https://worker.local/v1/messages/${id}/report`, { method: "POST", body: JSON.stringify({ reason: "spam" }) }),
        env(db),
      );
      expect(noAuth.status).toBe(401);
      expect((await report(db, KEY(99))).status).toBe(404);
      expect(m.reportBodies).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });
});

describe("legal hold", () => {
  it("held rows survive every Worker delete/expiry helper; unheld rows do not", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const held = await sendAs(db, m, "alice", 1);
      const free = await sendAs(db, m, "alice", 2);
      await setLegalHold(db, held);
      expect(await deleteMessagesIfNotHeld(db, [held, free])).toBe(1);
      expect(await hold(db, held)).toBe(1);
      expect(await hold(db, free)).toBeUndefined();
      expect(await expireMessagesBefore(db, "9999-12-31T00:00:00.000Z")).toBe(0);
      expect(await hold(db, held)).toBe(1);
    } finally {
      await mf.dispose();
    }
  });

  it("the D1 trigger refuses a raw delete of a held row and refuses releasing a hold", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      const held = await sendAs(db, m, "alice", 1);
      await setLegalHold(db, held);
      await expect(db.prepare("DELETE FROM messages WHERE id = ?1").bind(held).run()).rejects.toThrow(/legal_hold/);
      await expect(db.prepare("UPDATE messages SET legal_hold = 0 WHERE id = ?1").bind(held).run()).rejects.toThrow(/legal_hold/);
      expect(await hold(db, held)).toBe(1);
    } finally {
      await mf.dispose();
    }
  });

  it("no file in src/ removes message rows except src/retention.ts, and every removal there is guarded", () => {
    const SRC = fileURLToPath(new URL("../src", import.meta.url));
    const files = readdirSync(SRC, { recursive: true }).map(String).filter((f) => f.endsWith(".ts"));
    for (const f of files) {
      const text = readFileSync(join(SRC, f), "utf8");
      const removals = text.match(/DELETE\s+FROM\s+messages[^"`]*/gi) ?? [];
      if (f !== "retention.ts") expect(removals, f).toEqual([]);
      for (const r of removals) expect(r).toMatch(/legal_hold = 0/);
      expect(text, f).not.toMatch(/legal_hold\s*=\s*0\s*WHERE|SET\s+legal_hold\s*=\s*0/i);
    }
  });
});

describe("group block filter", () => {
  async function seedGroup(db: D1Database, m: ReturnType<typeof rpcs>) {
    // seq 1..6: alice, bob, alice, bob, carol, bob
    const who = ["alice", "bob", "alice", "bob", "carol", "bob"];
    for (let i = 0; i < who.length; i++) await sendAs(db, m, who[i], i + 1);
  }
  const senders = async (r: Response) => ((await r.json()) as any).messages.map((x: any) => x.sender_user_id);

  it("the blocker does not see the blocked user's messages; the blocked user and others see all", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      await seedGroup(db, m);
      m.state.auth = authRow({ user_id: "alice", hidden_sender_ids: ["bob"] });
      expect(await senders(await list(db))).toEqual(["alice", "alice", "carol"]);
      m.state.auth = authRow({ user_id: "bob", hidden_sender_ids: [] });
      expect(await senders(await list(db))).toEqual(["alice", "bob", "alice", "bob", "carol", "bob"]);
      m.state.auth = authRow({ user_id: "carol", hidden_sender_ids: [] });
      expect((await senders(await list(db))).length).toBe(6);
    } finally {
      await mf.dispose();
    }
  });

  it("pagination over the filtered stream keeps has_X === (X_cursor !== null) and never leaks a hidden row", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      await seedGroup(db, m);
      m.state.auth = authRow({ user_id: "alice", hidden_sender_ids: ["bob"] });
      const seen: number[] = [];
      let page = (await (await list(db, "?limit=1")).json()) as any;
      const check = (p: any) => {
        expect(p.has_older).toBe(p.older_cursor !== null);
        expect(p.has_newer).toBe(p.newer_cursor !== null);
        for (const x of p.messages) expect(x.sender_user_id).not.toBe("bob");
      };
      check(page);
      seen.push(...page.messages.map((x: any) => x.seq));
      while (page.has_older) {
        page = (await (await list(db, `?limit=1&direction=older&cursor=${page.older_cursor}`)).json()) as any;
        check(page);
        seen.push(...page.messages.map((x: any) => x.seq));
      }
      expect(seen.sort()).toEqual([1, 3, 5]);
      // newer from the oldest visible
      page = (await (await list(db, "?limit=50&direction=newer&cursor=1")).json()) as any;
      check(page);
      expect(page.messages.map((x: any) => x.seq)).toEqual([3, 5]);
      expect(page.has_newer).toBe(false);
    } finally {
      await mf.dispose();
    }
  });

  it("a malformed hidden_sender_ids fails closed", async () => {
    const m = rpcs();
    const { mf, db } = await localD1();
    try {
      m.state.auth = authRow({ user_id: "alice", hidden_sender_ids: "bob" });
      expect((await list(db)).status).toBe(502);
    } finally {
      await mf.dispose();
    }
  });
});
