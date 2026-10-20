// KAN-580 (UI half): sender-only receipt reads. Local D1 emulator + stubbed fetch; nothing real is called.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CONV_A, RPC_URL, SUPABASE_URL, authRow, env, localD1 } from "./helpers";

const SUMMARY_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_receipt_summary`;
const RECIPIENTS_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_receipt_recipients`;
const TOKEN = "Bearer reads.test.token";
const ME = "real-user";
const SERVICE = "service-key-for-test";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

function stub(row: Record<string, unknown> = authRow({ member_user_ids: [ME, "u2", "u3"] })) {
  const calls: { url: string; init: RequestInit }[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      if (url === RPC_URL) return new Response(JSON.stringify([row]), { status: 200 });
      calls.push({ url, init });
      if (url === SUMMARY_URL) return new Response(JSON.stringify([{ seq: 3, recipients: 2, delivered_count: 2, seen_count: 1 }]), { status: 200 });
      if (url === RECIPIENTS_URL)
        return new Response(JSON.stringify([{ user_id: "u2", state: "seen", updated_at: "2026-10-20T10:00:00Z" }, { user_id: "u3", state: "sent", updated_at: null }]), { status: 200 });
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { calls };
}

async function seeded() {
  const l = await localD1();
  await l.db
    .prepare("INSERT INTO messages (id, conversation_id, seq, sender_id, body, created_at, client_key) VALUES ('m3', ?1, 3, ?2, 'x', 't', 'k3'), ('m4', ?1, 4, 'u2', 'y', 't', 'k4')")
    .bind(CONV_A, ME)
    .run();
  return l;
}

const get = (db: D1Database, path: string, token: string | null = TOKEN, extra: Record<string, string> = {}) =>
  worker.fetch(
    new Request(`https://worker.local/v1/conversations/${CONV_A}/receipts${path}`, { headers: token === null ? {} : { Authorization: token } }),
    env(db, extra),
    undefined,
  );

describe("receipt summary (sender only)", () => {
  it("returns counts for the caller's own seqs only, with the caller's own token", async () => {
    const { calls } = stub();
    const { mf, db } = await seeded();
    try {
      const res = await get(db, "?seqs=3,4");
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ summaries: [{ seq: 3, recipients: 2, delivered_count: 2, seen_count: 1 }] });
      expect(JSON.parse(calls[0].init.body as string).p_seqs).toEqual([3]); // seq 4 is another sender's
      expect((calls[0].init.headers as Record<string, string>).Authorization).toBe(TOKEN);
    } finally {
      await mf.dispose();
    }
  });

  it("answers 404 when none of the seqs is the caller's, and a non-member also gets 404", async () => {
    stub();
    const a = await seeded();
    try {
      expect((await get(a.db, "?seqs=4")).status).toBe(404);
    } finally {
      await a.mf.dispose();
    }
    stub(authRow({ user_id: null, allowed_action: null, reason: "not_member" }));
    const b = await seeded();
    try {
      expect((await get(b.db, "?seqs=3")).status).toBe(404);
    } finally {
      await b.mf.dispose();
    }
  });

  it("is 401 without a token and 400 for a malformed or oversized list", async () => {
    stub();
    const { mf, db } = await seeded();
    try {
      expect((await get(db, "?seqs=3", null)).status).toBe(401);
      expect((await get(db, "?seqs=abc")).status).toBe(400);
      expect((await get(db, "")).status).toBe(400);
      expect((await get(db, `?seqs=${Array.from({ length: 101 }, (_, i) => i + 1).join(",")}`)).status).toBe(400);
    } finally {
      await mf.dispose();
    }
  });
});

describe("receipt recipients (sender only)", () => {
  it("calls the elevated function with the authorised member list and returns states", async () => {
    const { calls } = stub();
    const { mf, db } = await seeded();
    try {
      const res = await get(db, "/3", TOKEN, { SUPABASE_SERVICE_KEY: SERVICE });
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({
        recipients: [
          { user_id: "u2", state: "seen", updated_at: "2026-10-20T10:00:00Z" },
          { user_id: "u3", state: "sent", updated_at: null },
        ],
      });
      expect(JSON.parse(calls[0].init.body as string)).toEqual({
        p_conversation_id: CONV_A,
        p_seq: 3,
        p_caller_id: ME,
        p_member_ids: [ME, "u2", "u3"],
      });
      expect((calls[0].init.headers as Record<string, string>).Authorization).toBe(`Bearer ${SERVICE}`);
    } finally {
      await mf.dispose();
    }
  });

  it("answers 404 for a seq someone else sent, and never calls the database function", async () => {
    const { calls } = stub();
    const { mf, db } = await seeded();
    try {
      expect((await get(db, "/4", TOKEN, { SUPABASE_SERVICE_KEY: SERVICE })).status).toBe(404);
      expect((await get(db, "/99", TOKEN, { SUPABASE_SERVICE_KEY: SERVICE })).status).toBe(404);
      expect(calls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a non-member gets 404 and the function is not called", async () => {
    const { calls } = stub(authRow({ user_id: null, allowed_action: null, reason: "not_member" }));
    const { mf, db } = await seeded();
    try {
      expect((await get(db, "/3", TOKEN, { SUPABASE_SERVICE_KEY: SERVICE })).status).toBe(404);
      expect(calls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("without the elevated binding configured the route answers 503 and calls nothing", async () => {
    const { calls } = stub();
    const { mf, db } = await seeded();
    try {
      expect((await get(db, "/3")).status).toBe(503);
      expect(calls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });
});
