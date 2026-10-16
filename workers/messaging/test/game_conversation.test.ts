// KAN-563: GET /v1/games/{gameId}/conversation and PUT/DELETE /v1/conversations/{id}/mute. LOCAL-EMULATOR TESTS:
// Miniflare in-memory D1 and a stubbed Supabase. Nothing real is called.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { insertMessage } from "../src/db";
import { GAME_CONVERSATION_PER_USER_PER_MINUTE, MUTE_PER_USER_PER_MINUTE } from "../src/rate_limit";
import { SUPABASE_URL, env, localD1 } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const U = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"; // the caller (the bearer token IS the verified id in the stub)
const GAME = "11111111-1111-4111-8111-111111111111";
const CONV = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const GAME_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_game_conversation`;
const MUTE_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_set_muted`;
const MUTE_CONV_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_mute_conversation`;
const T0 = Date.UTC(2026, 9, 15, 10, 0, 10);
const pin = (ms: number) => vi.spyOn(Date, "now").mockReturnValue(ms);

type Call = { url: string; headers: Record<string, string>; body: Record<string, unknown> };

/** The msg_game_conversation row for a verdict, in the real function's shape. */
const gameRow = (over: Record<string, unknown> = {}) => ({
  user_id: U,
  conversation_id: CONV,
  game_id: GAME,
  allowed_action: "send",
  reason: null,
  left_at_seq: null,
  muted: false,
  ...over,
});
const denied = (reason: string) => gameRow({ conversation_id: null, allowed_action: null, reason, muted: false });

function supabase(opts: { game?: (user: string) => unknown; muteConv?: (user: string) => Record<string, unknown>; mute?: () => Response } = {}) {
  const calls: Call[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      const headers = (init.headers ?? {}) as Record<string, string>;
      const body = init.body ? (JSON.parse(init.body as string) as Record<string, unknown>) : {};
      const user = (headers.Authorization ?? "").replace("Bearer ", "");
      calls.push({ url, headers, body });
      if (url === GAME_URL) return new Response(JSON.stringify([opts.game ? opts.game(user) : gameRow({ user_id: user })]), { status: 200 });
      if (url === MUTE_CONV_URL) return new Response(JSON.stringify([opts.muteConv ? opts.muteConv(user) : { user_id: user, reason: null }]), { status: 200 });
      if (url === MUTE_URL) return opts.mute ? opts.mute() : new Response(null, { status: 204 });
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { calls, of: (u: string) => calls.filter((c) => c.url === u) };
}

const call = (method: string, path: string, db: D1Database, user: string | null = U, extra: Record<string, string> = {}) =>
  worker.fetch(
    new Request(`https://worker.local${path}`, { method, headers: { ...(user === null ? {} : { Authorization: `Bearer ${user}` }), ...extra } }),
    env(db),
  );
const reasonOf = async (res: Response) => ((await res.json()) as { error: { reason?: string } }).error.reason;
const getGame = (db: D1Database, user: string | null = U, id = GAME) => call("GET", `/v1/games/${id}/conversation`, db, user);

describe("GET /v1/games/{gameId}/conversation", () => {
  it("an active member gets the exact contract shape; the bearer goes unchanged and only the game id is sent", async () => {
    const s = supabase({ game: (u) => gameRow({ user_id: u, muted: true }) });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: CONV, senderId: U, body: "x", clientKey: "k1" });
      await insertMessage(db, { conversationId: CONV, senderId: U, body: "y", clientKey: "k2" });
      const res = await getGame(db);
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({
        id: CONV, kind: "game", game_id: GAME, writable: true, read_only_reason: null, boundary: null, muted: true, last_seq: 2,
      });
      expect(s.calls).toHaveLength(1); // ONE database round trip
      expect(s.calls[0].headers.Authorization).toBe(`Bearer ${U}`);
      expect(Object.keys(s.calls[0].body).sort()).toEqual(["p_access_mode", "p_game_id"]); // no client-supplied identity
    } finally {
      await mf.dispose();
    }
  });

  it("no messages yet gives last_seq 0", async () => {
    supabase();
    const { mf, db } = await localD1();
    try {
      expect(((await (await getGame(db)).json()) as { last_seq: number }).last_seq).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a member who left gets left_read_only with the boundary, and last_seq is cut at it", async () => {
    supabase({ game: () => gameRow({ allowed_action: "read", reason: "left", left_at_seq: 2 }) });
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < 5; i++) await insertMessage(db, { conversationId: CONV, senderId: U, body: "m", clientKey: `k${i}` });
      const body = (await (await getGame(db)).json()) as Record<string, unknown>;
      expect(body).toEqual({
        id: CONV, kind: "game", game_id: GAME, writable: false, read_only_reason: "left_read_only",
        boundary: { kind: "left_at_seq", seq: 2 }, muted: false, last_seq: 2,
      });
    } finally {
      await mf.dispose();
    }
  });

  it.each([
    ["game_cancelled", "game_cancelled"],
    ["game_ended", "game_ended"],
  ])("a %s game is not writable with read_only_reason %s and no boundary", async (rpcReason, expected) => {
    supabase({ game: () => gameRow({ allowed_action: "read", reason: rpcReason }) });
    const { mf, db } = await localD1();
    try {
      const body = (await (await getGame(db)).json()) as Record<string, unknown>;
      expect(body.writable).toBe(false);
      expect(body.read_only_reason).toBe(expected);
      expect(body.boundary).toBeNull();
    } finally {
      await mf.dispose();
    }
  });

  it.each([
    ["not_member", 403, "not_a_member"],
    ["removed", 403, "removed"],
    ["not_in_pilot", 403, "not_in_pilot"],
    ["not_found", 404, "not_found"],
  ])("the database verdict %s is %i %s", async (rpcReason, status, reason) => {
    supabase({ game: () => denied(rpcReason) });
    const { mf, db } = await localD1();
    try {
      const res = await getGame(db);
      expect(res.status).toBe(status);
      expect(await reasonOf(res)).toBe(reason);
    } finally {
      await mf.dispose();
    }
  });

  it("a suspended verdict is 403 suspended; an unknown reason is 403 with no reason", async () => {
    supabase({ game: () => denied("suspended") });
    const { mf, db } = await localD1();
    try {
      const res = await getGame(db);
      expect(res.status).toBe(403);
      expect(await reasonOf(res)).toBe("suspended");
    } finally {
      await mf.dispose();
    }
    supabase({ game: () => denied("something_new") });
    const second = await localD1();
    try {
      const res = await getGame(second.db);
      expect(res.status).toBe(403);
      expect(await reasonOf(res)).toBeUndefined();
    } finally {
      await second.mf.dispose();
    }
  });

  it("a non-uuid game id is 400 invalid_request and the database is not called", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      const res = await getGame(db, U, "not-a-uuid");
      expect(res.status).toBe(400);
      expect(await reasonOf(res)).toBe("invalid_request");
      expect(s.calls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("no bearer is 401 with no reason and the database is not called", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      const res = await getGame(db, null);
      expect(res.status).toBe(401);
      expect(await reasonOf(res)).toBeUndefined();
      expect(s.calls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("the database rejecting the token is 401; an upstream failure is 502 with no reason", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 401 })));
    const { mf, db } = await localD1();
    try {
      expect((await getGame(db)).status).toBe(401);
      vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 500 })));
      const res = await getGame(db);
      expect(res.status).toBe(502);
      expect(await reasonOf(res)).toBeUndefined();
    } finally {
      await mf.dispose();
    }
  });

  it("the per-user limit gives 429 rate_limited with Retry-After; a denial writes nothing", async () => {
    pin(T0);
    supabase();
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < GAME_CONVERSATION_PER_USER_PER_MINUTE; i++) expect((await getGame(db)).status).toBe(200);
      const res = await getGame(db);
      expect(res.status).toBe(429);
      expect(await reasonOf(res)).toBe("rate_limited");
      expect(Number(res.headers.get("Retry-After"))).toBeGreaterThan(0);
      // another user is not affected
      expect((await getGame(db, "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")).status).toBe(200);
    } finally {
      await mf.dispose();
    }
    supabase({ game: () => denied("not_member") });
    const second = await localD1();
    try {
      expect((await getGame(second.db)).status).toBe(403);
      const none = await second.db.prepare("SELECT COUNT(*) AS n FROM rate_limits").first<{ n: number }>();
      expect(none?.n).toBe(0);
    } finally {
      await second.mf.dispose();
    }
  });

  it("a malformed database row fails closed (502)", async () => {
    supabase({ game: () => gameRow({ muted: "yes" }) });
    const { mf, db } = await localD1();
    try {
      expect((await getGame(db)).status).toBe(502);
    } finally {
      await mf.dispose();
    }
  });
});

describe("PUT / DELETE /v1/conversations/{id}/mute", () => {
  const mutePath = `/v1/conversations/${CONV}/mute`;

  it("PUT mutes: 204 with no body, idempotent; ONE database call per request, with the caller's bearer", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < 2; i++) {
        const res = await call("PUT", mutePath, db);
        expect(res.status).toBe(204);
        expect(await res.text()).toBe("");
      }
      expect(s.calls).toHaveLength(2); // one RPC per request, nothing else
      const writes = s.of(MUTE_CONV_URL);
      expect(writes).toHaveLength(2);
      expect(writes[0].headers.Authorization).toBe(`Bearer ${U}`);
      expect(writes[0].body).toEqual({ p_conversation_id: CONV, p_muted: true, p_access_mode: "allowlist" });
    } finally {
      await mf.dispose();
    }
  });

  it("DELETE unmutes: 204, idempotent, one database call per request", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < 2; i++) expect((await call("DELETE", mutePath, db)).status).toBe(204);
      expect(s.calls).toHaveLength(2);
      expect(s.of(MUTE_CONV_URL)[0].body).toEqual({ p_conversation_id: CONV, p_muted: false, p_access_mode: "allowlist" });
    } finally {
      await mf.dispose();
    }
  });

  it.each([
    ["not_member", 403, "not_a_member"],
    ["removed", 403, "removed"],
    ["not_in_pilot", 403, "not_in_pilot"],
    ["suspended", 403, "suspended"],
    ["not_found", 404, "not_found"],
  ])("a caller the database refuses (%s) is %i %s and no limiter write happens", async (rpcReason, status, reason) => {
    supabase({ muteConv: (u) => ({ user_id: u, reason: rpcReason }) });
    const { mf, db } = await localD1();
    try {
      for (const method of ["PUT", "DELETE"]) {
        const res = await call(method, mutePath, db);
        expect(res.status).toBe(status);
        expect(await reasonOf(res)).toBe(reason);
      }
      const none = await db.prepare("SELECT COUNT(*) AS n FROM rate_limits").first<{ n: number }>();
      expect(none?.n).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a member of an ended game may still mute (the database applies it)", async () => {
    supabase();
    const { mf, db } = await localD1();
    try {
      expect((await call("PUT", mutePath, db)).status).toBe(204);
    } finally {
      await mf.dispose();
    }
  });

  it("a malformed row or an upstream failure fails closed (502); a rejected token is 401", async () => {
    supabase({ muteConv: () => ({ reason: null }) });
    const { mf, db } = await localD1();
    try {
      expect((await call("PUT", mutePath, db)).status).toBe(502);
      vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 500 })));
      expect((await call("PUT", mutePath, db)).status).toBe(502);
      vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 401 })));
      expect((await call("PUT", mutePath, db)).status).toBe(401);
    } finally {
      await mf.dispose();
    }
  });

  it("unauthenticated is 401 and a non-uuid id is 400", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      expect((await call("PUT", mutePath, db, null)).status).toBe(401);
      expect((await call("DELETE", mutePath, db, null)).status).toBe(401);
      const bad = await call("PUT", "/v1/conversations/nope/mute", db);
      expect(bad.status).toBe(400);
      expect(await reasonOf(bad)).toBe("invalid_request");
      expect(s.calls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("the per-user limit gives 429 rate_limited with Retry-After", async () => {
    pin(T0);
    supabase();
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < MUTE_PER_USER_PER_MINUTE; i++) expect((await call("PUT", mutePath, db)).status).toBe(204);
      const res = await call("DELETE", mutePath, db);
      expect(res.status).toBe(429);
      expect(await reasonOf(res)).toBe("rate_limited");
      expect(Number(res.headers.get("Retry-After"))).toBeGreaterThan(0);
    } finally {
      await mf.dispose();
    }
  });

  it("KAN-561's POST /mute still answers 200 {muted} unchanged", async () => {
    supabase();
    const { mf, db } = await localD1();
    try {
      const res = await worker.fetch(
        new Request(`https://worker.local${mutePath}`, {
          method: "POST",
          headers: { Authorization: `Bearer ${U}`, "content-type": "application/json" },
          body: JSON.stringify({ muted: true }),
        }),
        env(db),
      );
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ muted: true });
    } finally {
      await mf.dispose();
    }
  });
});

describe("CORS preflight for the new methods", () => {
  it("allows PUT and DELETE (and still GET and POST) on a /v1/ route from an allowed origin", async () => {
    const { mf, db } = await localD1();
    try {
      const res = await worker.fetch(
        new Request(`https://worker.local/v1/conversations/${CONV}/mute`, {
          method: "OPTIONS",
          headers: { Origin: "https://app.dabbler.pro", "Access-Control-Request-Method": "DELETE" },
        }),
        env(db),
      );
      expect(res.status).toBe(204);
      const methods = (res.headers.get("Access-Control-Allow-Methods") ?? "").split(",").map((m) => m.trim());
      expect(methods).toEqual(expect.arrayContaining(["GET", "POST", "PUT", "DELETE", "OPTIONS"]));
    } finally {
      await mf.dispose();
    }
  });
});
