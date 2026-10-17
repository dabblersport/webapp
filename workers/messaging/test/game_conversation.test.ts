// KAN-563: GET /v1/games/{gameId}/conversation and PUT/DELETE /v1/conversations/{id}/mute. LOCAL-EMULATOR TESTS:
// Miniflare in-memory D1 and a stubbed Supabase. Nothing real is called.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { insertMessage } from "../src/db";
import { CONVERSATION_OPS_PER_USER_PER_MINUTE } from "../src/rate_limit";
import { RPC_URL, SUPABASE_URL, authRow, env, localD1 } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const GAME = "99999999-9999-4999-8999-999999999999";
const CONV = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const GAME_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_game_conversation`;
const MUTE_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_set_muted`;

type Call = { url: string; headers: Record<string, string>; body: Record<string, unknown> };

/** Stubbed Supabase. The bearer token IS the verified user id. */
function supabase(opts: {
  game?: (user: string) => Record<string, unknown>;
  auth?: (user: string) => Record<string, unknown>;
  mute?: () => Response;
} = {}) {
  const calls: Call[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      const headers = (init.headers ?? {}) as Record<string, string>;
      const body = init.body ? (JSON.parse(init.body as string) as Record<string, unknown>) : {};
      const user = (headers.Authorization ?? "").replace("Bearer ", "");
      calls.push({ url, headers, body });
      if (url === GAME_URL) return new Response(JSON.stringify([(opts.game ?? gameRow())(user)]), { status: 200 });
      if (url === RPC_URL) {
        return new Response(JSON.stringify([(opts.auth ?? ((u: string) => authRow({ user_id: u })))(user)]), { status: 200 });
      }
      if (url === MUTE_URL) return (opts.mute ?? (() => new Response(null, { status: 204 })))();
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { calls, of: (u: string) => calls.filter((c) => c.url === u) };
}

const gameRow = (over: Record<string, unknown> = {}) => (user: string) => ({
  user_id: user,
  conversation_id: CONV,
  game_id: GAME,
  allowed_action: "send",
  reason: null,
  left_at_seq: null,
  muted: false,
  ...over,
});
const denied = (reason: string) => (user: string) => ({
  user_id: user, conversation_id: null, game_id: null, allowed_action: null, reason, left_at_seq: null, muted: false,
});

const req = (method: string, path: string, user: string | null, db: D1Database) =>
  worker.fetch(
    new Request(`https://worker.local${path}`, {
      method,
      headers: user === null ? {} : { Authorization: `Bearer ${user}` },
    }),
    env(db),
  );
const reasonOf = async (res: Response) => ((await res.json()) as { error: { reason?: string } }).error.reason;

async function withDb(fn: (db: D1Database) => Promise<void>) {
  const { mf, db } = await localD1();
  try {
    await fn(db);
  } finally {
    await mf.dispose();
  }
}

describe("GET /v1/games/{gameId}/conversation", () => {
  it("an active member gets exactly the contract Conversation; one RPC, bearer unchanged, game id only", async () => {
    const s = supabase({ game: gameRow({ muted: true }) });
    await withDb(async (db) => {
      for (let i = 0; i < 3; i++) await insertMessage(db, { conversationId: CONV, senderId: A, body: "x", clientKey: `k${i}` });
      const res = await req("GET", `/v1/games/${GAME}/conversation`, A, db);
      expect(res.status).toBe(200);
      expect(await res.json()).toStrictEqual({
        id: CONV, kind: "game", game_id: GAME, writable: true, read_only_reason: null, boundary: null, muted: true, last_seq: 3,
      });
      expect(s.calls.length).toBe(1);
      expect(s.calls[0].url).toBe(GAME_URL);
      expect(s.calls[0].headers.Authorization).toBe(`Bearer ${A}`);
      expect(s.calls[0].body).toEqual({ p_game_id: GAME, p_access_mode: "allowlist" });
    });
  });

  it("no message yet: last_seq 0", async () => {
    supabase();
    await withDb(async (db) => {
      const body = (await (await req("GET", `/v1/games/${GAME}/conversation`, A, db)).json()) as Record<string, unknown>;
      expect(body.last_seq).toBe(0);
    });
  });

  it("a member who left gets left_read_only, the boundary, and last_seq cut at it", async () => {
    supabase({ game: gameRow({ allowed_action: "read", reason: "left", left_at_seq: 2 }) });
    await withDb(async (db) => {
      for (let i = 0; i < 5; i++) await insertMessage(db, { conversationId: CONV, senderId: A, body: "x", clientKey: `k${i}` });
      const body = await (await req("GET", `/v1/games/${GAME}/conversation`, A, db)).json();
      expect(body).toStrictEqual({
        id: CONV, kind: "game", game_id: GAME, writable: false, read_only_reason: "left_read_only",
        boundary: { kind: "left_at_seq", seq: 2 }, muted: false, last_seq: 2,
      });
    });
  });

  for (const reason of ["game_cancelled", "game_ended"]) {
    it(`${reason}: writable false with that read_only_reason`, async () => {
      supabase({ game: gameRow({ allowed_action: "read", reason }) });
      await withDb(async (db) => {
        const res = await req("GET", `/v1/games/${GAME}/conversation`, A, db);
        expect(res.status).toBe(200);
        const body = (await res.json()) as Record<string, unknown>;
        expect(body.writable).toBe(false);
        expect(body.read_only_reason).toBe(reason);
        expect(body.boundary).toBeNull();
      });
    });
  }

  for (const [db_reason, api_reason, status] of [
    ["not_member", "not_a_member", 403],
    ["removed", "removed", 403],
    ["suspended", "suspended", 403],
    ["not_in_pilot", "not_in_pilot", 403],
    ["not_found", "not_found", 404],
  ] as const) {
    it(`${db_reason} -> ${status} ${api_reason}, and no limiter write`, async () => {
      supabase({ game: denied(db_reason) });
      await withDb(async (db) => {
        const res = await req("GET", `/v1/games/${GAME}/conversation`, A, db);
        expect(res.status).toBe(status);
        expect(await reasonOf(res)).toBe(api_reason);
        const rows = await db.prepare("SELECT COUNT(*) AS n FROM rate_limits").first<{ n: number }>();
        expect(rows?.n).toBe(0);
      });
    });
  }

  it("a non-uuid gameId is 400 invalid_request with no RPC", async () => {
    const s = supabase();
    await withDb(async (db) => {
      const res = await req("GET", "/v1/games/not-a-uuid/conversation", A, db);
      expect(res.status).toBe(400);
      expect(await reasonOf(res)).toBe("invalid_request");
      expect(s.calls.length).toBe(0);
    });
  });

  it("unauthenticated: 401 with no RPC; a rejected token: 401", async () => {
    const s = supabase();
    await withDb(async (db) => {
      expect((await req("GET", `/v1/games/${GAME}/conversation`, null, db)).status).toBe(401);
      expect(s.calls.length).toBe(0);
    });
    vi.unstubAllGlobals();
    vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 401 })));
    await withDb(async (db) => {
      expect((await req("GET", `/v1/games/${GAME}/conversation`, A, db)).status).toBe(401);
    });
  });

  it("over the limit: 429 rate_limited with Retry-After", async () => {
    supabase();
    vi.spyOn(Date, "now").mockReturnValue(Date.UTC(2026, 9, 17, 10, 0, 10));
    await withDb(async (db) => {
      for (let i = 0; i < CONVERSATION_OPS_PER_USER_PER_MINUTE; i++) {
        expect((await req("GET", `/v1/games/${GAME}/conversation`, A, db)).status).toBe(200);
      }
      const res = await req("GET", `/v1/games/${GAME}/conversation`, A, db);
      expect(res.status).toBe(429);
      expect(await reasonOf(res)).toBe("rate_limited");
      expect(res.headers.get("Retry-After")).toBe("50");
    });
  });
});

describe("PUT / DELETE /v1/conversations/{id}/mute", () => {
  it("PUT mutes: 204 no body, msg_authorize then msg_set_muted(true); repeated is still 204", async () => {
    const s = supabase();
    await withDb(async (db) => {
      for (let i = 0; i < 2; i++) {
        const res = await req("PUT", `/v1/conversations/${CONV}/mute`, A, db);
        expect(res.status).toBe(204);
        expect(await res.text()).toBe("");
      }
      expect(s.calls.map((c) => c.url)).toEqual([RPC_URL, MUTE_URL, RPC_URL, MUTE_URL]);
      expect(s.of(MUTE_URL)[0].body).toEqual({ p_conversation_id: CONV, p_muted: true });
      expect(s.of(MUTE_URL)[0].headers.Authorization).toBe(`Bearer ${A}`);
    });
  });

  it("DELETE unmutes: 204 no body, msg_set_muted(false); repeated is still 204", async () => {
    const s = supabase();
    await withDb(async (db) => {
      for (let i = 0; i < 2; i++) {
        const res = await req("DELETE", `/v1/conversations/${CONV}/mute`, A, db);
        expect(res.status).toBe(204);
        expect(await res.text()).toBe("");
      }
      expect(s.of(MUTE_URL).map((c) => c.body.p_muted)).toEqual([false, false]);
    });
  });

  it("a read-only member (left) may still mute", async () => {
    supabase({ auth: (u) => authRow({ user_id: u, allowed_action: "read", reason: "left", left_at_seq: 1 }) });
    await withDb(async (db) => {
      expect((await req("PUT", `/v1/conversations/${CONV}/mute`, A, db)).status).toBe(204);
    });
  });

  for (const [db_reason, api_reason] of [
    ["not_member", "not_a_member"],
    ["removed", "removed"],
    ["not_in_pilot", "not_in_pilot"],
  ] as const) {
    it(`refused for ${db_reason}: 403 ${api_reason}, msg_set_muted never called`, async () => {
      const s = supabase({ auth: (u) => authRow({ user_id: u, allowed_action: null, reason: db_reason }) });
      await withDb(async (db) => {
        const res = await req("PUT", `/v1/conversations/${CONV}/mute`, A, db);
        expect(res.status).toBe(403);
        expect(await reasonOf(res)).toBe(api_reason);
        expect(s.of(MUTE_URL).length).toBe(0);
      });
    });
  }

  it("msg_set_muted's own not_member refusal maps to 403 not_a_member", async () => {
    supabase({ mute: () => new Response(JSON.stringify({ message: "not_member" }), { status: 403 }) });
    await withDb(async (db) => {
      const res = await req("DELETE", `/v1/conversations/${CONV}/mute`, A, db);
      expect(res.status).toBe(403);
      expect(await reasonOf(res)).toBe("not_a_member");
    });
  });

  it("unauthenticated: 401, nothing called; a non-uuid id: 404 not_found", async () => {
    const s = supabase();
    await withDb(async (db) => {
      expect((await req("PUT", `/v1/conversations/${CONV}/mute`, null, db)).status).toBe(401);
      const bad = await req("DELETE", "/v1/conversations/nope/mute", A, db);
      expect(bad.status).toBe(404);
      expect(await reasonOf(bad)).toBe("not_found");
      expect(s.calls.length).toBe(0);
    });
  });

  it("over the limit: 429 rate_limited with Retry-After", async () => {
    supabase();
    vi.spyOn(Date, "now").mockReturnValue(Date.UTC(2026, 9, 17, 10, 0, 30));
    await withDb(async (db) => {
      for (let i = 0; i < CONVERSATION_OPS_PER_USER_PER_MINUTE; i++) {
        expect((await req("PUT", `/v1/conversations/${CONV}/mute`, A, db)).status).toBe(204);
      }
      const res = await req("DELETE", `/v1/conversations/${CONV}/mute`, A, db);
      expect(res.status).toBe(429);
      expect(await reasonOf(res)).toBe("rate_limited");
      expect(res.headers.get("Retry-After")).toBe("30");
    });
  });

  it("CORS preflight on the mute path allows PUT and DELETE", async () => {
    await withDb(async (db) => {
      const res = await worker.fetch(
        new Request(`https://worker.local/v1/conversations/${CONV}/mute`, {
          method: "OPTIONS",
          headers: { Origin: "https://canary.dabbler.pro", "Access-Control-Request-Method": "PUT" },
        }),
        env(db),
      );
      expect(res.status).toBe(204);
      const methods = res.headers.get("Access-Control-Allow-Methods") ?? "";
      expect(methods.split(", ")).toEqual(expect.arrayContaining(["PUT", "DELETE"]));
    });
  });
});
