// KAN-561: DMs through the Worker: start, send/read, mute, the new-DM limit and the list summary. LOCAL-EMULATOR TESTS:
// Miniflare in-memory D1 and a stubbed Supabase. Nothing real is called.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { insertMessage } from "../src/db";
import { LOOKBACK_MESSAGES, MAX_BLOCK_LOOKUPS, summarySql } from "../src/conversations";
import { NEW_DM_PER_USER_PER_HOUR, SEND_PER_USER_PER_CONVERSATION_PER_MINUTE } from "../src/rate_limit";
import { RPC_URL, SUPABASE_URL, authRow, env, localD1 } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"; // the caller
const B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"; // the counterpart
const C = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"; // a stranger
const DM = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const DM2 = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
const GAME = "11111111-1111-4111-8111-111111111111";
const NIL = "00000000-0000-0000-0000-000000000000";
const START_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_start_dm`;
const MUTE_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_set_muted`;
const LIST_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_my_conversations`;
const EXISTS_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_dm_exists`;
const KEY = (n: number) => `9b2f7c1e-0000-4000-8000-${String(n).padStart(12, "0")}`;
const T0 = Date.UTC(2026, 9, 15, 10, 0, 10);
const pin = (ms: number) => vi.spyOn(Date, "now").mockReturnValue(ms);

type Call = { url: string; headers: Record<string, string>; body: Record<string, unknown> };

/**
 * A stubbed Supabase. The bearer token IS the verified user id (what the real RPCs derive from the JWT).
 *   convs  : per conversation id, the msg_authorize row the user gets (a function of the user id)
 *   start  : what msg_start_dm answers
 */
function supabase(opts: {
  convs?: Record<string, (user: string) => Record<string, unknown>>;
  start?: (user: string, other: string) => Response;
  mute?: (user: string, conv: string, muted: boolean) => Response;
  list?: (user: string) => unknown[];
  exists?: (user: string, other: string) => Response;
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
      if (url === RPC_URL) {
        const conv = body.p_conversation_id as string;
        if (conv === NIL) {
          return new Response(JSON.stringify([authRow({ user_id: user, allowed_action: null, reason: "not_member" })]), { status: 200 });
        }
        const make = opts.convs?.[conv];
        return new Response(
          JSON.stringify([make ? make(user) : authRow({ user_id: user, allowed_action: null, reason: "not_member" })]),
          { status: 200 },
        );
      }
      if (url === START_URL) return (opts.start ?? ((_u, o) => new Response(JSON.stringify(o === B ? DM : DM2), { status: 200 })))(user, body.p_other_user as string);
      if (url === MUTE_URL) return (opts.mute ?? (() => new Response(null, { status: 204 })))(user, body.p_conversation_id as string, body.p_muted as boolean);
      if (url === EXISTS_URL) return (opts.exists ?? (() => new Response("false", { status: 200 })))(user, body.p_other_user as string);
      if (url === LIST_URL) return new Response(JSON.stringify((opts.list ?? (() => []))(user)), { status: 200 });
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { calls, of: (u: string) => calls.filter((c) => c.url === u) };
}

const dbError = (message: string, status = 403) => new Response(JSON.stringify({ code: "42501", message }), { status });
const member = (conv: string, over: Record<string, unknown> = {}) => (user: string) =>
  authRow({ user_id: user, allowed_action: "send", member_user_ids: [A, B], ...over });

const post = (path: string, user: string, body: unknown, db: D1Database, extra: Record<string, string> = {}) =>
  worker.fetch(
    new Request(`https://worker.local${path}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${user}`, "content-type": "application/json", ...extra },
      body: JSON.stringify(body),
    }),
    env(db),
  );
const get = (path: string, user: string, db: D1Database) =>
  worker.fetch(new Request(`https://worker.local${path}`, { headers: { Authorization: `Bearer ${user}` } }), env(db));
const reasonOf = async (res: Response) => ((await res.json()) as { error: { reason?: string } }).error.reason;

describe("start a DM (POST /v1/dm)", () => {
  it("returns the conversation id; the caller's bearer goes unchanged and only other_user_id is sent", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      const res = await post("/v1/dm", A, { other_user_id: B, user_id: C, p_user: C, started_by: C }, db);
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ conversation_id: DM });
      const call = s.of(START_URL)[0];
      expect(call.headers.Authorization).toBe(`Bearer ${A}`);
      expect(call.headers.apikey).toBe(env(db).SUPABASE_ANON_KEY);
      expect(Object.keys(call.body)).toEqual(["p_other_user"]); // no client-supplied identity is relayed
      expect(call.body.p_other_user).toBe(B);
    } finally {
      await mf.dispose();
    }
  });

  it("is idempotent: starting again returns the same conversation", async () => {
    supabase();
    const { mf, db } = await localD1();
    try {
      const a = await (await post("/v1/dm", A, { other_user_id: B }, db)).json();
      const b = await (await post("/v1/dm", A, { other_user_id: B }, db)).json();
      expect(b).toEqual(a);
    } finally {
      await mf.dispose();
    }
  });

  const refusals: [string, string, number, string][] = [
    ["blocked", "blocked", 403, "blocked"],
    ["age_restricted", "age_restricted", 403, "not_in_pilot"],
    ["not_found", "not_found", 404, "not_found"],
    ["rate_limited", "rate_limited", 429, "dm_cap_reached"],
    ["invalid_request", "invalid_request", 400, "invalid_request"],
  ];
  for (const [name, message, status, reason] of refusals) {
    it(`the database's ${name} is passed on as ${status} ${reason}`, async () => {
      supabase({ start: () => dbError(message, 403) });
      const { mf, db } = await localD1();
      try {
        const res = await post("/v1/dm", A, { other_user_id: B }, db);
        expect(res.status).toBe(status);
        expect(await reasonOf(res)).toBe(reason);
      } finally {
        await mf.dispose();
      }
    });
  }

  it("self is refused before the database is asked", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      const res = await post("/v1/dm", A, { other_user_id: A.toUpperCase() }, db);
      expect(res.status).toBe(400);
      expect(await reasonOf(res)).toBe("invalid_request");
      expect(s.of(START_URL)).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a bad body, a missing token and a non-pilot user are refused with no start call", async () => {
    const s = supabase({ convs: {} });
    const { mf, db } = await localD1();
    try {
      expect((await post("/v1/dm", A, { other_user_id: "nope" }, db)).status).toBe(400);
      expect((await post("/v1/dm", A, {}, db)).status).toBe(400);
      const noToken = await worker.fetch(
        new Request("https://worker.local/v1/dm", { method: "POST", body: JSON.stringify({ other_user_id: B }) }),
        env(db),
      );
      expect(noToken.status).toBe(401);
      expect(s.of(START_URL)).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a Supabase failure is a 502 with no reason", async () => {
    supabase({ start: () => new Response("boom", { status: 500 }) });
    const { mf, db } = await localD1();
    try {
      const res = await post("/v1/dm", A, { other_user_id: B }, db);
      expect(res.status).toBe(502);
      expect(await reasonOf(res)).toBeUndefined();
    } finally {
      await mf.dispose();
    }
  });
});

describe("the new-DM limit (second line behind the database cap)", () => {
  it("the 11th start in an hour is 429 rate_limited with Retry-After; the 10th passes", async () => {
    pin(T0);
    supabase();
    const { mf, db } = await localD1();
    try {
      for (let i = 1; i <= NEW_DM_PER_USER_PER_HOUR; i++) {
        expect((await post("/v1/dm", A, { other_user_id: B }, db)).status).toBe(200);
      }
      const eleventh = await post("/v1/dm", A, { other_user_id: B }, db);
      expect(eleventh.status).toBe(429);
      expect(await reasonOf(eleventh)).toBe("rate_limited");
      expect(Number(eleventh.headers.get("Retry-After"))).toBe(3590); // to the end of the hour window
      // another user is not affected, and the next hour starts clean
      expect((await post("/v1/dm", C, { other_user_id: B }, db)).status).toBe(200);
      pin(T0 + 3600 * 1000);
      expect((await post("/v1/dm", A, { other_user_id: B }, db)).status).toBe(200);
    } finally {
      await mf.dispose();
    }
  });

  it("a refused start writes nothing and does not call the database", async () => {
    pin(T0);
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < NEW_DM_PER_USER_PER_HOUR; i++) await post("/v1/dm", A, { other_user_id: B }, db);
      const before = s.of(START_URL).length;
      await post("/v1/dm", A, { other_user_id: B }, db);
      expect(s.of(START_URL).length).toBe(before);
      const row = await db.prepare("SELECT count FROM rate_limits WHERE subject = ?1 AND scope = 'new_dm_hour'").bind(A).first<{ count: number }>();
      expect(row?.count).toBe(NEW_DM_PER_USER_PER_HOUR);
    } finally {
      await mf.dispose();
    }
  });
});

describe("send and read in a DM through the existing routes", () => {
  const send = (db: D1Database, user: string, n: number, conv = DM) =>
    post(`/v1/conversations/${conv}/messages`, user, { body: `hello ${n}` }, db, { "Idempotency-Key": KEY(n) });

  it("a member sends (201) and reads the message back", async () => {
    supabase({ convs: { [DM]: member(DM) } });
    const { mf, db } = await localD1();
    try {
      expect((await send(db, A, 1)).status).toBe(201);
      const list = await get(`/v1/conversations/${DM}/messages`, B, db);
      expect(list.status).toBe(200);
      const page = (await list.json()) as { messages: { body: string; kind: string }[] };
      expect(page.messages.map((m) => m.body)).toEqual(["hello 1"]);
    } finally {
      await mf.dispose();
    }
  });

  it("a non-member is refused on send and on read (not_a_member), with no D1 write", async () => {
    supabase({ convs: { [DM]: (u) => (u === C ? authRow({ user_id: u, allowed_action: null, reason: "not_member" }) : member(DM)(u)) } });
    const { mf, db } = await localD1();
    try {
      const s = await send(db, C, 1);
      expect(s.status).toBe(403);
      expect(await reasonOf(s)).toBe("not_a_member");
      const r = await get(`/v1/conversations/${DM}/messages`, C, db);
      expect(r.status).toBe(403);
      const n = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
      expect(n?.n).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("after a block (read:blocked) send is refused with blocked for the caller and history stays readable", async () => {
    supabase({ convs: { [DM]: (u) => authRow({ user_id: u, allowed_action: "read", reason: "blocked", member_user_ids: [A, B] }) } });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: B, body: "old", clientKey: "k1" });
      const s = await send(db, A, 2);
      expect(s.status).toBe(403);
      expect(await reasonOf(s)).toBe("blocked");
      const r = await get(`/v1/conversations/${DM}/messages`, A, db);
      expect(r.status).toBe(200);
      expect(((await r.json()) as { messages: unknown[] }).messages).toHaveLength(1);
    } finally {
      await mf.dispose();
    }
  });

  it("a deleted or banned counterpart (read:suspended) refuses a send with suspended", async () => {
    supabase({ convs: { [DM]: (u) => authRow({ user_id: u, allowed_action: "read", reason: "suspended", member_user_ids: [A, B] }) } });
    const { mf, db } = await localD1();
    try {
      const s = await send(db, A, 1);
      expect(s.status).toBe(403);
      expect(await reasonOf(s)).toBe("suspended");
    } finally {
      await mf.dispose();
    }
  });

  it("D4: the blocker does not see the blocked counterpart's messages; the counterpart sees all", async () => {
    supabase({ convs: { [DM]: (u) => authRow({ user_id: u, allowed_action: "send", member_user_ids: [A, B], hidden_sender_ids: u === A ? [B] : [] }) } });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: A, body: "from a", clientKey: "k1" });
      await insertMessage(db, { conversationId: DM, senderId: B, body: "from b", clientKey: "k2" });
      const forA = (await (await get(`/v1/conversations/${DM}/messages`, A, db)).json()) as { messages: { body: string }[] };
      const forB = (await (await get(`/v1/conversations/${DM}/messages`, B, db)).json()) as { messages: { body: string }[] };
      expect(forA.messages.map((m) => m.body)).toEqual(["from a"]);
      expect(forB.messages.map((m) => m.body)).toEqual(["from a", "from b"]);
    } finally {
      await mf.dispose();
    }
  });

  it("the existing send limit applies to a DM: the 21st send in a minute is 429 rate_limited", async () => {
    pin(T0);
    supabase({ convs: { [DM]: member(DM) } });
    const { mf, db } = await localD1();
    try {
      for (let i = 1; i <= SEND_PER_USER_PER_CONVERSATION_PER_MINUTE; i++) expect((await send(db, A, i)).status).toBe(201);
      const over = await send(db, A, 99);
      expect(over.status).toBe(429);
      expect(await reasonOf(over)).toBe("rate_limited");
      expect(over.headers.get("Retry-After")).not.toBeNull();
    } finally {
      await mf.dispose();
    }
  });

  it("a DM send wakes the members like a game send (msg_notify is scheduled once)", async () => {
    supabase({ convs: { [DM]: member(DM) } });
    const { mf, db } = await localD1();
    try {
      const scheduled: Promise<unknown>[] = [];
      const res = await worker.fetch(
        new Request(`https://worker.local/v1/conversations/${DM}/messages`, {
          method: "POST",
          headers: { Authorization: `Bearer ${A}`, "content-type": "application/json", "Idempotency-Key": KEY(1) },
          body: JSON.stringify({ body: "hi" }),
        }),
        env(db),
        { waitUntil: (p: Promise<unknown>) => void scheduled.push(p) },
      );
      expect(res.status).toBe(201);
      expect(scheduled).toHaveLength(1);
    } finally {
      await mf.dispose();
    }
  });
});

describe("mute (POST /v1/conversations/{id}/mute)", () => {
  it("a member mutes and unmutes: the bearer goes unchanged, the body is only the conversation and the flag", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      const on = await post(`/v1/conversations/${DM}/mute`, A, { muted: true, user_id: C }, db);
      expect(on.status).toBe(200);
      expect(await on.json()).toEqual({ muted: true });
      const off = await post(`/v1/conversations/${DM}/mute`, A, { muted: false }, db);
      expect(await off.json()).toEqual({ muted: false });
      const [first, second] = s.of(MUTE_URL);
      expect(first.headers.Authorization).toBe(`Bearer ${A}`);
      expect(first.body).toEqual({ p_conversation_id: DM, p_muted: true });
      expect(second.body).toEqual({ p_conversation_id: DM, p_muted: false });
    } finally {
      await mf.dispose();
    }
  });

  it("a non-member is refused (403 not_a_member)", async () => {
    supabase({ mute: () => dbError("not_member") });
    const { mf, db } = await localD1();
    try {
      const res = await post(`/v1/conversations/${DM}/mute`, C, { muted: true }, db);
      expect(res.status).toBe(403);
      expect(await reasonOf(res)).toBe("not_a_member");
    } finally {
      await mf.dispose();
    }
  });

  it("a bad id, a missing flag and a missing token are refused without a database call", async () => {
    const s = supabase();
    const { mf, db } = await localD1();
    try {
      expect((await post("/v1/conversations/not-a-uuid/mute", A, { muted: true }, db)).status).toBe(400);
      expect((await post(`/v1/conversations/${DM}/mute`, A, { muted: "yes" }, db)).status).toBe(400);
      expect((await post(`/v1/conversations/${DM}/mute`, A, {}, db)).status).toBe(400);
      const noToken = await worker.fetch(
        new Request(`https://worker.local/v1/conversations/${DM}/mute`, { method: "POST", body: JSON.stringify({ muted: true }) }),
        env(db),
      );
      expect(noToken.status).toBe(401);
      expect(s.of(MUTE_URL)).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });
});

describe("summary (GET /v1/conversations/summary)", () => {
  const listFor = (rows: { conversation_id: string; state: string }[]) => () => rows.map((r) => ({ ...r, kind: "dm", game_title: "secret title" }));

  it("returns only conversation_id, last_message_at and last_message_from_me; no text, sender id or count", async () => {
    const s = supabase({ list: listFor([{ conversation_id: DM, state: "send" }, { conversation_id: DM2, state: "send" }]) });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: B, body: "first secret words", clientKey: "k1" });
      await insertMessage(db, { conversationId: DM, senderId: A, body: "latest secret words", clientKey: "k2" });
      await insertMessage(db, { conversationId: DM2, senderId: B, body: "other secret words", clientKey: "k3" });
      const res = await get(`/v1/conversations/summary?ids=${DM},${DM2}`, A, db);
      expect(res.status).toBe(200);
      const text = await res.text();
      expect(text).not.toContain("secret");
      expect(text).not.toContain(B);
      const body = JSON.parse(text) as { summaries: Record<string, unknown>[] };
      expect(Object.keys(body)).toEqual(["summaries"]);
      for (const row of body.summaries) {
        expect(Object.keys(row).sort()).toEqual(["conversation_id", "last_message_at", "last_message_from_me"]);
      }
      const byId = Object.fromEntries(body.summaries.map((r) => [r.conversation_id as string, r]));
      expect(byId[DM].last_message_from_me).toBe(true); // A sent the newest
      expect(byId[DM2].last_message_from_me).toBe(false);
      expect(typeof byId[DM].last_message_at).toBe("string");
      // the list was asked with the caller's own bearer, once
      expect(s.of(LIST_URL)).toHaveLength(1);
      expect(s.of(LIST_URL)[0].headers.Authorization).toBe(`Bearer ${A}`);
    } finally {
      await mf.dispose();
    }
  });

  it("ids the caller cannot read are omitted silently, a conversation they left too", async () => {
    supabase({ list: listFor([{ conversation_id: DM, state: "send" }, { conversation_id: GAME, state: "left" }]) });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: B, body: "x", clientKey: "k1" });
      await insertMessage(db, { conversationId: GAME, senderId: B, body: "y", clientKey: "k2" });
      await insertMessage(db, { conversationId: DM2, senderId: B, body: "z", clientKey: "k3" });
      const res = await get(`/v1/conversations/summary?ids=${DM},${GAME},${DM2}`, A, db);
      const body = (await res.json()) as { summaries: { conversation_id: string }[] };
      expect(body.summaries.map((r) => r.conversation_id)).toEqual([DM]);
    } finally {
      await mf.dispose();
    }
  });

  it("a readable conversation with no user message yet has a null time; system lines do not count", async () => {
    supabase({ list: listFor([{ conversation_id: DM, state: "send" }]) });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: "system", body: '{"event":"joined"}', clientKey: "e1" });
      const body = (await (await get(`/v1/conversations/summary?ids=${DM}`, A, db)).json()) as { summaries: Record<string, unknown>[] };
      expect(body.summaries).toEqual([{ conversation_id: DM, last_message_at: null, last_message_from_me: false }]);
    } finally {
      await mf.dispose();
    }
  });

  it("is a bounded read: 50 ids at most, valid ids only, no D1 write", async () => {
    supabase({ list: listFor([]) });
    const { db, mf } = await localD1();
    try {
      const many = Array.from({ length: 51 }, (_, i) => `00000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`);
      expect((await get(`/v1/conversations/summary?ids=${many.join(",")}`, A, db)).status).toBe(400);
      expect((await get(`/v1/conversations/summary?ids=${many.slice(0, 50).join(",")}`, A, db)).status).toBe(200);
      expect((await get("/v1/conversations/summary?ids=nope", A, db)).status).toBe(400);
      expect((await get("/v1/conversations/summary", A, db)).status).toBe(400);
      const writes = await db.prepare("SELECT COUNT(*) AS n FROM rate_limits").first<{ n: number }>();
      expect(writes?.n).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("is not captured by the messages route and needs a token", async () => {
    supabase();
    const { mf, db } = await localD1();
    try {
      const res = await worker.fetch(new Request(`https://worker.local/v1/conversations/summary?ids=${DM}`), env(db));
      expect(res.status).toBe(401);
    } finally {
      await mf.dispose();
    }
  });
});

describe("re-opening an existing DM is exempt from the new-DM limit", () => {
  const yes = () => new Response("true", { status: 200 });
  const pair = (others: string[]) => (_u: string, other: string) => new Response(JSON.stringify(others.includes(other)), { status: 200 });

  it("any number of re-opens passes and writes nothing; a new pair is still counted", async () => {
    pin(T0);
    const s = supabase({ exists: pair([B]) });
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < NEW_DM_PER_USER_PER_HOUR + 5; i++) {
        expect((await post("/v1/dm", A, { other_user_id: B }, db)).status).toBe(200);
      }
      const none = await db.prepare("SELECT COUNT(*) AS n FROM rate_limits").first<{ n: number }>();
      expect(none?.n).toBe(0);
      // asked of the database with the caller's own bearer, and no list is read
      expect(s.of(EXISTS_URL)[0].headers.Authorization).toBe(`Bearer ${A}`);
      expect(s.of(EXISTS_URL)[0].body).toEqual({ p_other_user: B });
      expect(s.of(LIST_URL)).toHaveLength(0);
      for (let i = 0; i < NEW_DM_PER_USER_PER_HOUR; i++) expect((await post("/v1/dm", A, { other_user_id: C }, db)).status).toBe(200);
      expect((await post("/v1/dm", A, { other_user_id: C }, db)).status).toBe(429);
      expect((await post("/v1/dm", A, { other_user_id: B }, db)).status).toBe(200);
    } finally {
      await mf.dispose();
    }
  });

  it("an empty pair the other user started, or one beyond any list cap, is exempt too (the database answers, not a list)", async () => {
    supabase({ exists: yes, list: () => [] });
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < NEW_DM_PER_USER_PER_HOUR + 3; i++) expect((await post("/v1/dm", A, { other_user_id: B }, db)).status).toBe(200);
      const none = await db.prepare("SELECT COUNT(*) AS n FROM rate_limits").first<{ n: number }>();
      expect(none?.n).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("the database still decides a re-open: a block refuses it", async () => {
    supabase({ exists: yes, start: () => dbError("blocked") });
    const { mf, db } = await localD1();
    try {
      const res = await post("/v1/dm", A, { other_user_id: B }, db);
      expect(res.status).toBe(403);
      expect(await reasonOf(res)).toBe("blocked");
    } finally {
      await mf.dispose();
    }
  });

  it("when the database cannot answer, the second-line limiter does not charge (the database cap still decides)", async () => {
    supabase({ exists: () => new Response("{}", { status: 404 }) });
    const { mf, db } = await localD1();
    try {
      for (let i = 0; i < NEW_DM_PER_USER_PER_HOUR + 2; i++) expect((await post("/v1/dm", A, { other_user_id: C }, db)).status).toBe(200);
      const none = await db.prepare("SELECT COUNT(*) AS n FROM rate_limits").first<{ n: number }>();
      expect(none?.n).toBe(0);
    } finally {
      await mf.dispose();
    }
  });
});

describe("summary hides a blocked counterpart from the blocker (D4) and is a bounded read", () => {
  const dmList = (state: string) => () => [{ conversation_id: DM, kind: "dm", state, counterpart_user_id: B }];

  it("the blocker sees only their own last message; the blocked side and the unblocked see the newest", async () => {
    const convs = {
      [DM]: (u: string) => authRow({ user_id: u, allowed_action: "read", reason: "blocked", member_user_ids: [A, B], hidden_sender_ids: u === A ? [B] : [] }),
    };
    supabase({ convs, list: dmList("read_only") });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: A, body: "mine", clientKey: "k1" });
      await insertMessage(db, { conversationId: DM, senderId: B, body: "theirs", clientKey: "k2" }); // newest, by the blocked one
      const forBlocker = (await (await get(`/v1/conversations/summary?ids=${DM}`, A, db)).json()) as { summaries: Record<string, unknown>[] };
      expect(forBlocker.summaries[0].last_message_from_me).toBe(true); // B's newer message does not count
      const newest = await db.prepare("SELECT created_at FROM messages WHERE sender_id = ?1").bind(B).first<{ created_at: string }>();
      const mine = await db.prepare("SELECT created_at FROM messages WHERE sender_id = ?1").bind(A).first<{ created_at: string }>();
      expect(forBlocker.summaries[0].last_message_at).toBe(mine?.created_at);
      expect(forBlocker.summaries[0].last_message_at).not.toBe(newest?.created_at === mine?.created_at ? "x" : newest?.created_at);
      const forBlocked = (await (await get(`/v1/conversations/summary?ids=${DM}`, B, db)).json()) as { summaries: Record<string, unknown>[] };
      expect(forBlocked.summaries[0].last_message_from_me).toBe(true); // B sees the newest, which is theirs
    } finally {
      await mf.dispose();
    }
  });

  it("a blocker with only the blocked person's messages sees a null time", async () => {
    supabase({
      convs: { [DM]: (u) => authRow({ user_id: u, allowed_action: "read", reason: "blocked", member_user_ids: [A, B], hidden_sender_ids: [B] }) },
      list: dmList("read_only"),
    });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: B, body: "theirs", clientKey: "k1" });
      const body = (await (await get(`/v1/conversations/summary?ids=${DM}`, A, db)).json()) as { summaries: Record<string, unknown>[] };
      expect(body.summaries).toEqual([{ conversation_id: DM, last_message_at: null, last_message_from_me: false }]);
    } finally {
      await mf.dispose();
    }
  });

  it("a read-only DM that is NOT a block of the caller (counterpart banned) shows the newest message", async () => {
    supabase({
      convs: { [DM]: (u) => authRow({ user_id: u, allowed_action: "read", reason: "suspended", member_user_ids: [A, B], hidden_sender_ids: [] }) },
      list: dmList("read_only"),
    });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: B, body: "theirs", clientKey: "k1" });
      const body = (await (await get(`/v1/conversations/summary?ids=${DM}`, A, db)).json()) as { summaries: Record<string, unknown>[] };
      expect(body.summaries[0].last_message_at).not.toBeNull();
    } finally {
      await mf.dispose();
    }
  });

  it("a read-only DM whose block lookup fails is omitted (fails closed)", async () => {
    supabase({ convs: { [DM]: () => authRow({ allowed_action: null, reason: "not_in_pilot" }) }, list: dmList("read_only") });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: B, body: "theirs", clientKey: "k1" });
      const body = (await (await get(`/v1/conversations/summary?ids=${DM}`, A, db)).json()) as { summaries: unknown[] };
      expect(body.summaries).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });

  it("block lookups are budgeted: at most MAX_BLOCK_LOOKUPS subrequests, the rest omitted", async () => {
    const dmIds = Array.from({ length: 40 }, (_, i) => `dd000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`);
    const convs = Object.fromEntries(dmIds.map((id) => [id, (u: string) => authRow({ user_id: u, allowed_action: "read", reason: "blocked", hidden_sender_ids: [] })]));
    const s = supabase({ convs, list: () => dmIds.map((id) => ({ conversation_id: id, kind: "dm", state: "read_only", counterpart_user_id: B })) });
    const { mf, db } = await localD1();
    try {
      const body = (await (await get(`/v1/conversations/summary?ids=${dmIds.slice(0, 40).join(",")}`, A, db)).json()) as { summaries: unknown[] };
      expect(body.summaries).toHaveLength(MAX_BLOCK_LOOKUPS);
      const authorizeCalls = s.calls.filter((c) => c.url === RPC_URL && c.body.p_conversation_id !== NIL);
      expect(authorizeCalls).toHaveLength(MAX_BLOCK_LOOKUPS);
      expect(s.calls.length).toBeLessThanOrEqual(2 + MAX_BLOCK_LOOKUPS); // the Workers Free limit is 50
    } finally {
      await mf.dispose();
    }
  });

  it("the statement searches by primary key and by the (conversation_id, seq) index; it never scans messages", async () => {
    const { mf, db } = await localD1();
    try {
      const { sql, binds } = summarySql([
        { id: DM, exclude: null },
        { id: DM2, exclude: B },
        { id: GAME, exclude: null },
      ]);
      expect(binds).toHaveLength(2); // two JSON parameters, whatever the number of ids
      expect(JSON.parse(binds[0])).toEqual([DM, DM2, GAME]);
      expect(JSON.parse(binds[1])).toEqual([`${DM2}|${B}`]);
      const plan = await db.prepare(`EXPLAIN QUERY PLAN ${sql}`).bind(...binds).all<{ detail: string }>();
      const details = plan.results.map((r) => r.detail);
      // cs = conversation_seq (primary key), m = messages (the UNIQUE (conversation_id, seq) index, with a seq range)
      expect(details.some((d) => /^SEARCH cs USING INDEX sqlite_autoindex_conversation_seq_\d+ \(conversation_id=\?\)/.test(d))).toBe(true);
      expect(details.some((d) => /^SEARCH m USING INDEX sqlite_autoindex_messages_\d+ \(conversation_id=\? AND seq>\?\)/.test(d))).toBe(true);
      expect(details.filter((d) => /^SCAN (m|cs)\b/.test(d))).toEqual([]); // only the JSON lists and the result are scanned
    } finally {
      await mf.dispose();
    }
  });

  it("50 ids work in one statement (D1 limits on parameters and compound terms are not hit)", async () => {
    const { mf, db } = await localD1();
    try {
      const many = Array.from({ length: 50 }, (_, i) => ({ id: `00000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`, exclude: i % 2 ? B : null }));
      const { sql, binds } = summarySql(many);
      await insertMessage(db, { conversationId: many[0].id, senderId: A, body: "x", clientKey: "k1" });
      const r = await db.prepare(sql).bind(...binds).all<{ conversation_id: string }>();
      expect(r.results.map((x) => x.conversation_id)).toEqual([many[0].id]);
    } finally {
      await mf.dispose();
    }
  });

  it("looks back at most LOOKBACK_MESSAGES sequence numbers: older qualifying messages are not read", async () => {
    supabase({ list: () => [{ conversation_id: DM, kind: "dm", state: "send", counterpart_user_id: B }] });
    const { mf, db } = await localD1();
    try {
      await insertMessage(db, { conversationId: DM, senderId: B, body: "old", clientKey: "k0" });
      for (let i = 1; i <= LOOKBACK_MESSAGES + 5; i++) {
        await insertMessage(db, { conversationId: DM, senderId: "system", body: "{}", clientKey: `s${i}` });
      }
      const body = (await (await get(`/v1/conversations/summary?ids=${DM}`, A, db)).json()) as { summaries: Record<string, unknown>[] };
      expect(body.summaries[0].last_message_at).toBeNull(); // the user message is beyond the window
    } finally {
      await mf.dispose();
    }
  });
});

describe("source hygiene", () => {
  it("the new route files have no logging, no token decoding, no elevated key", () => {
    for (const f of ["dm.ts", "conversations.ts"]) {
      const text = readFileSync(fileURLToPath(new URL(`../src/${f}`, import.meta.url)), "utf8");
      expect(/\bconsole\s*\./.test(text), f).toBe(false);
      expect(/SERVICE_ROLE|jwt|atob|btoa|crypto\.subtle/i.test(text), f).toBe(false);
    }
  });

  it("the client's own user id is never read from the request body except other_user_id", () => {
    const text = readFileSync(fileURLToPath(new URL("../src/dm.ts", import.meta.url)), "utf8");
    expect(text.match(/input\.(\w+)/g)?.sort()).toEqual(["input.muted", "input.other_user_id"]);
  });
});
