// KAN-928: GET /v1/meetups/{meetupId}/conversation. LOCAL-EMULATOR TESTS: Miniflare in-memory D1 and a stubbed
// Supabase. Nothing real is called. The handler is the game one (src/games.ts) over msg_meetup_conversation.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { insertMessage } from "../src/db";
import { SUPABASE_URL, env, localD1 } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const MEETUP = "77777777-7777-4777-8777-777777777777";
const CONV = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const MEETUP_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_meetup_conversation`;

type Call = { url: string; headers: Record<string, string>; body: Record<string, unknown> };

function supabase(row: (user: string) => Record<string, unknown>) {
  const calls: Call[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      const headers = (init.headers ?? {}) as Record<string, string>;
      const body = init.body ? (JSON.parse(init.body as string) as Record<string, unknown>) : {};
      calls.push({ url, headers, body });
      if (url === MEETUP_URL) {
        return new Response(JSON.stringify([row((headers.Authorization ?? "").replace("Bearer ", ""))]), { status: 200 });
      }
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return calls;
}

const meetupRow = (over: Record<string, unknown> = {}) => (user: string) => ({
  user_id: user, conversation_id: CONV, meetup_id: MEETUP, allowed_action: "send", reason: null, left_at_seq: null,
  muted: false, ...over,
});
const denied = (reason: string) => (user: string) => ({
  user_id: user, conversation_id: null, meetup_id: null, allowed_action: null, reason, left_at_seq: null, muted: false,
});

const get = (path: string, user: string | null, db: D1Database) =>
  worker.fetch(
    new Request(`https://worker.local${path}`, { headers: user === null ? {} : { Authorization: `Bearer ${user}` } }),
    env(db),
  );

async function withDb(fn: (db: D1Database) => Promise<void>) {
  const { mf, db } = await localD1();
  try {
    await fn(db);
  } finally {
    await mf.dispose();
  }
}

describe("GET /v1/meetups/{meetupId}/conversation", () => {
  it("a going member gets kind 'meetup' with meetup_id (no game_id); one RPC, bearer unchanged", async () => {
    const calls = supabase(meetupRow());
    await withDb(async (db) => {
      for (let i = 0; i < 2; i++) await insertMessage(db, { conversationId: CONV, senderId: A, body: "x", clientKey: `k${i}` });
      const res = await get(`/v1/meetups/${MEETUP}/conversation`, A, db);
      expect(res.status).toBe(200);
      expect(await res.json()).toStrictEqual({
        id: CONV, kind: "meetup", meetup_id: MEETUP, writable: true, read_only_reason: null, boundary: null, muted: false,
        last_seq: 2,
      });
      expect(calls.length).toBe(1);
      expect(calls[0].url).toBe(MEETUP_URL);
      expect(calls[0].headers.Authorization).toBe(`Bearer ${A}`);
      expect(calls[0].body).toEqual({ p_meetup_id: MEETUP, p_access_mode: "allowlist" });
    });
  });

  it("an RSVP that left: left_read_only with the boundary", async () => {
    supabase(meetupRow({ allowed_action: "read", reason: "left", left_at_seq: 1 }));
    await withDb(async (db) => {
      for (let i = 0; i < 3; i++) await insertMessage(db, { conversationId: CONV, senderId: A, body: "x", clientKey: `k${i}` });
      const body = (await (await get(`/v1/meetups/${MEETUP}/conversation`, A, db)).json()) as Record<string, unknown>;
      expect(body.writable).toBe(false);
      expect(body.read_only_reason).toBe("left_read_only");
      expect(body.boundary).toStrictEqual({ kind: "left_at_seq", seq: 1 });
      expect(body.last_seq).toBe(1);
    });
  });

  it("a cancelled meetup: game_cancelled read-only", async () => {
    supabase(meetupRow({ allowed_action: "read", reason: "game_cancelled" }));
    await withDb(async (db) => {
      const body = (await (await get(`/v1/meetups/${MEETUP}/conversation`, A, db)).json()) as Record<string, unknown>;
      expect(body.writable).toBe(false);
      expect(body.read_only_reason).toBe("game_cancelled");
    });
  });

  for (const [dbReason, apiReason, status] of [
    ["not_member", "not_a_member", 403],
    ["not_found", "not_found", 404],
  ] as const) {
    it(`${dbReason} -> ${status} ${apiReason}`, async () => {
      supabase(denied(dbReason));
      await withDb(async (db) => {
        const res = await get(`/v1/meetups/${MEETUP}/conversation`, A, db);
        expect(res.status).toBe(status);
        expect(((await res.json()) as { error: { reason?: string } }).error.reason).toBe(apiReason);
      });
    });
  }

  it("a non-uuid meetupId is 400 with no RPC; no bearer is 401 with no RPC", async () => {
    const calls = supabase(meetupRow());
    await withDb(async (db) => {
      expect((await get("/v1/meetups/nope/conversation", A, db)).status).toBe(400);
      expect((await get(`/v1/meetups/${MEETUP}/conversation`, null, db)).status).toBe(401);
      expect(calls.length).toBe(0);
    });
  });
});
