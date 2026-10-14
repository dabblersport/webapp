import { afterEach, describe, expect, it, vi } from "vitest";
import worker, { VERSION } from "../src/index";
import { CONV_A, RPC_URL, env, localD1, mockFetch, rpcJson, spyDb } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
});

const whoami = (headers: Record<string, string> = {}) =>
  new Request(`https://worker.local/v1/whoami?conversation_id=${CONV_A}`, { headers });

describe("(a) health", () => {
  it("GET /health is ok with a version, no auth, no RPC, no DB", async () => {
    const { calls, unmocked } = mockFetch(rpcJson({}));
    const { db, touched } = spyDb();
    const res = await worker.fetch(new Request("https://worker.local/health"), env(db));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true, version: VERSION });
    expect(calls.length).toBe(0);
    expect(unmocked).toEqual([]);
    expect(touched).toEqual([]);
  });
});

describe("(e) missing or malformed Authorization", () => {
  for (const [name, headers] of [
    ["absent", {}],
    ["empty", { Authorization: "" }],
    ["not bearer", { Authorization: "Basic abc" }],
    ["bearer without token", { Authorization: "Bearer " }],
  ] as const) {
    it(`${name}: 401 with no reason, zero RPC calls, zero DB access`, async () => {
      const { calls, unmocked } = mockFetch(rpcJson({ user_id: "x", allowed: true }));
      const { db, touched } = spyDb();
      const res = await worker.fetch(whoami(headers as Record<string, string>), env(db));
      expect(res.status).toBe(401);
      const body = (await res.json()) as { error: Record<string, unknown> };
      expect(body.error.reason).toBeUndefined();
      expect(calls.length).toBe(0);
      expect(unmocked).toEqual([]);
      expect(touched).toEqual([]);
    });
  }
});

describe("(d) no authorisation cache (AC2)", () => {
  it("two requests with the same token call msg_authorize twice, exactly once each", async () => {
    const { calls, unmocked } = mockFetch(rpcJson({ user_id: "real-user", allowed: true }));
    const { db } = spyDb();
    const h = { Authorization: "Bearer same.token.value" };
    const r1 = await worker.fetch(whoami(h), env(db));
    expect(calls.length).toBe(1);
    const r2 = await worker.fetch(whoami(h), env(db));
    expect(calls.length).toBe(2);
    expect(r1.status).toBe(200);
    expect(r2.status).toBe(200);
    expect(calls.every((c) => c.url === RPC_URL)).toBe(true);
    expect(unmocked).toEqual([]);
  });

  it("a revocation between two requests takes effect on the second", async () => {
    let allowed = true;
    const { calls } = mockFetch(() =>
      new Response(JSON.stringify({ user_id: "real-user", allowed, reason: allowed ? undefined : "removed" }), {
        status: 200,
      }),
    );
    const { db } = spyDb();
    const h = { Authorization: "Bearer same.token.value" };
    expect((await worker.fetch(whoami(h), env(db))).status).toBe(200);
    allowed = false;
    const res = await worker.fetch(whoami(h), env(db));
    expect(res.status).toBe(403);
    expect(((await res.json()) as any).error.reason).toBe("removed");
    expect(calls.length).toBe(2);
  });
});

describe("unknown route", () => {
  it("404 not_found, and /v1/_probe is off unless SKELETON_PROBE=1", async () => {
    const { calls } = mockFetch(rpcJson({}));
    const { db, touched } = spyDb();
    const res = await worker.fetch(
      new Request("https://worker.local/v1/_probe", { method: "POST", headers: { Authorization: "Bearer t" }, body: "{}" }),
      env(db),
    );
    expect(res.status).toBe(404);
    expect(((await res.json()) as any).error.reason).toBe("not_found");
    expect(calls.length).toBe(0);
    expect(touched).toEqual([]);
  });
});

describe("(f) D1 migration applies to the LOCAL emulator", () => {
  it("creates messages and conversation_seq with the unique constraints", async () => {
    const { mf, db, statements } = await localD1();
    try {
      expect(statements.some((s) => /DROP/i.test(s))).toBe(false);
      const t = await db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").all<{ name: string }>();
      const names = t.results.map((r) => r.name);
      expect(names).toContain("messages");
      expect(names).toContain("conversation_seq");
      const cols = await db.prepare("SELECT name FROM pragma_table_info('messages')").all<{ name: string }>();
      expect(cols.results.map((c) => c.name).sort()).toEqual(
        ["body", "client_key", "conversation_id", "created_at", "id", "legal_hold", "sender_id", "seq"].sort(),
      );
    } finally {
      await mf.dispose();
    }
  });
});
