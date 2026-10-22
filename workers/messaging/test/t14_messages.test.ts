// KAN-509 (T14) send / list. LOCAL-EMULATOR TESTS: Miniflare in-memory D1 + mocked msg_authorize. No network.
import { afterEach, describe, expect, it, vi } from "vitest";
import { mapAuthorizeReason } from "../src/auth";
import worker from "../src/index";
import { CONV_A, CONV_B, authRow, env, localD1, mockFetch, spyDb } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

const KEY = (n: number) => `9b2f7c1e-0000-4000-8000-${String(n).padStart(12, "0")}`;
const H = { Authorization: "Bearer any.token.here", "content-type": "application/json" };

/** Mutable RPC: each call answers with whatever `state.row` is at that moment. */
function rpc(initial: Record<string, unknown> = authRow()) {
  const state = { row: initial };
  const m = mockFetch(() => new Response(JSON.stringify([state.row]), { status: 200 }));
  return { state, ...m };
}

const send = (db: D1Database, key: string, body = "hi", conv = CONV_A) =>
  worker.fetch(
    new Request(`https://worker.local/v1/conversations/${conv}/messages`, {
      method: "POST",
      headers: { ...H, "Idempotency-Key": key },
      body: JSON.stringify({ body }),
    }),
    env(db),
  );
const list = (db: D1Database, qs = "", conv = CONV_A) =>
  worker.fetch(new Request(`https://worker.local/v1/conversations/${conv}/messages${qs}`, { headers: H }), env(db));

async function seed(db: D1Database, n: number) {
  for (let i = 1; i <= n; i++) expect((await send(db, KEY(i), `m${i}`)).status).toBe(201);
}

describe("reason mapping (one table, one test per reason)", () => {
  it("not_authenticated -> 401, no reason", () => expect(mapAuthorizeReason("not_authenticated")).toEqual({ kind: "deny", status: 401 }));
  it("messaging_off -> 403, no reason", () => expect(mapAuthorizeReason("messaging_off")).toEqual({ kind: "deny", status: 403 }));
  it("not_in_pilot -> not_in_pilot", () => expect(mapAuthorizeReason("not_in_pilot")).toEqual({ kind: "deny", reason: "not_in_pilot" }));
  it("not_member -> not_a_member", () => expect(mapAuthorizeReason("not_member")).toEqual({ kind: "deny", reason: "not_a_member" }));
  it("removed -> removed", () => expect(mapAuthorizeReason("removed")).toEqual({ kind: "deny", reason: "removed" }));
  it("left -> read-only left_read_only", () => expect(mapAuthorizeReason("left")).toEqual({ kind: "readOnly", reason: "left_read_only" }));
  it("game_ended -> read-only game_ended", () =>
    expect(mapAuthorizeReason("game_ended")).toEqual({ kind: "readOnly", reason: "game_ended" }));
  it("game_cancelled -> read-only game_cancelled", () =>
    expect(mapAuthorizeReason("game_cancelled")).toEqual({ kind: "readOnly", reason: "game_cancelled" }));
  it("the retired single closed-game reason is unknown -> 403 with no reason", () =>
    expect(mapAuthorizeReason(["read", "only"].join("_"))).toEqual({ kind: "deny", status: 403 }));
  it("unknown -> 403, no reason", () => expect(mapAuthorizeReason("whatever")).toEqual({ kind: "deny", status: 403 }));

  it("messaging_off end to end: 403 with no reason, zero DB", async () => {
    rpc(authRow({ allowed_action: null, reason: "messaging_off" }));
    const { db, touched } = spyDb();
    const res = await list(db);
    expect(res.status).toBe(403);
    expect(((await res.json()) as any).error.reason).toBeUndefined();
    expect(touched).toEqual([]);
  });
});

describe("RPC request", () => {
  it("sends p_conversation_id and p_access_mode (test env sets 'allowlist'; env override passed through)", async () => {
    const { calls } = rpc(authRow({ allowed_action: null, reason: "not_member" }));
    const { db } = spyDb();
    await list(db);
    expect(JSON.parse(calls[0].init.body as string)).toEqual({ p_conversation_id: CONV_A, p_access_mode: "allowlist" });
    await worker.fetch(new Request(`https://worker.local/v1/conversations/${CONV_A}/messages`, { headers: H }), {
      ...env(db),
      MESSAGING_ACCESS_MODE: "all",
    });
    expect(JSON.parse(calls[1].init.body as string).p_access_mode).toBe("all");
  });
});

describe("roster statuses", () => {
  it("active: sends (201) and lists", async () => {
    rpc();
    const { mf, db } = await localD1();
    try {
      const r = await send(db, KEY(1), "hello");
      expect(r.status).toBe(201);
      const m = (await r.json()) as any;
      expect(m).toMatchObject({ conversation_id: CONV_A, seq: 1, sender_user_id: "real-user", kind: "text", body: "hello", client_key: KEY(1) });
      const page = (await (await list(db)).json()) as any;
      expect(page.messages.map((x: any) => x.seq)).toEqual([1]);
      expect(page.boundary).toBeNull();
    } finally {
      await mf.dispose();
    }
  });

  it("a member who becomes 'kicked' (RPC: removed) can neither list nor send; zero DB access", async () => {
    const { state } = rpc();
    const { mf, db } = await localD1();
    try {
      await seed(db, 3);
      state.row = authRow({ allowed_action: null, reason: "removed" });
      const spy = spyDb(db);
      for (const res of [await list(spy.db), await send(spy.db, KEY(9))]) {
        expect(res.status).toBe(403);
        expect(((await res.json()) as any).error.reason).toBe("removed");
      }
      expect(spy.touched).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });

  for (const [name, conv] of [["non-member", CONV_A], ["guessed conversation id", "33333333-3333-4333-8333-333333333333"]] as const) {
    it(`${name}: 403 not_a_member on list and send, zero DB access`, async () => {
      rpc(authRow({ allowed_action: null, reason: "not_member" }));
      const { db, touched } = spyDb();
      for (const res of [await list(db, "", conv), await send(db, KEY(1), "x", conv)]) {
        expect(res.status).toBe(403);
        expect(((await res.json()) as any).error.reason).toBe("not_a_member");
      }
      expect(touched).toEqual([]);
    });
  }

  it("left: list is cut at left_at_seq in every direction; send refused left_read_only", async () => {
    const { state } = rpc();
    const { mf, db } = await localD1();
    try {
      await seed(db, 10);
      state.row = authRow({ allowed_action: "read", reason: "left", left_at_seq: 6 });
      const newest = (await (await list(db)).json()) as any;
      expect(newest.messages.map((x: any) => x.seq)).toEqual([1, 2, 3, 4, 5, 6]);
      expect(newest.boundary).toEqual({ kind: "left_at_seq", seq: 6 });
      expect(newest.has_newer).toBe(false);
      const newer = (await (await list(db, "?cursor=4&direction=newer")).json()) as any;
      expect(newer.messages.map((x: any) => x.seq)).toEqual([5, 6]);
      expect(newer.has_newer).toBe(false);
      const beyond = (await (await list(db, "?cursor=9&direction=older")).json()) as any;
      expect(beyond.messages.map((x: any) => x.seq)).toEqual([1, 2, 3, 4, 5, 6]);
      expect(beyond.has_newer).toBe(false);
      const res = await send(db, KEY(50));
      expect(res.status).toBe(403);
      expect(((await res.json()) as any).error.reason).toBe("left_read_only");
      const n = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
      expect(n?.n).toBe(10);
    } finally {
      await mf.dispose();
    }
  });

  it("left with left_at_seq 0 sees nothing", async () => {
    const { state } = rpc();
    const { mf, db } = await localD1();
    try {
      await seed(db, 2);
      state.row = authRow({ allowed_action: "read", reason: "left", left_at_seq: 0 });
      const p = (await (await list(db)).json()) as any;
      expect(p.messages).toEqual([]);
      expect(p.has_older).toBe(false);
    } finally {
      await mf.dispose();
    }
  });
});

describe("closed game (msg_authorize returns game_ended or game_cancelled)", () => {
  for (const which of ["game_ended", "game_cancelled"]) {
    it(`${which}: send refused 409 ${which}, no row; list still allowed`, async () => {
      const { state } = rpc();
      const { mf, db } = await localD1();
      try {
        await seed(db, 2);
        state.row = authRow({ allowed_action: "read", reason: which });
        const res = await send(db, KEY(77));
        expect(res.status).toBe(409);
        expect(((await res.json()) as any).error.reason).toBe(which);
        const p = await list(db);
        expect(p.status).toBe(200);
        expect(((await p.json()) as any).messages.map((x: any) => x.seq)).toEqual([1, 2]);
        const n = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
        expect(n?.n).toBe(2);
      } finally {
        await mf.dispose();
      }
    });
  }
});

describe("send idempotency and seq", () => {
  it("same Idempotency-Key resent: 201 then 200 with the same id/seq, one row, original body kept", async () => {
    rpc();
    const { mf, db } = await localD1();
    try {
      const a = await send(db, KEY(1), "first");
      const b = await send(db, KEY(1), "retry body differs");
      const c = await send(db, KEY(1).toUpperCase(), "upper-case key");
      expect([a.status, b.status, c.status]).toEqual([201, 200, 200]);
      const [ma, mb, mc] = (await Promise.all([a.json(), b.json(), c.json()])) as any[];
      expect(mb).toEqual(ma);
      expect(mc).toEqual(ma);
      expect(ma.body).toBe("first");
      const n = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
      expect(n?.n).toBe(1);
    } finally {
      await mf.dispose();
    }
  });

  it("concurrent duplicate sends with one key: exactly one 201, one row", async () => {
    rpc();
    const { mf, db } = await localD1();
    try {
      const rs = await Promise.all(Array.from({ length: 5 }, () => send(db, KEY(5))));
      expect(rs.filter((r) => r.status === 201).length).toBe(1);
      expect(rs.filter((r) => r.status === 200).length).toBe(4);
      const n = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
      expect(n?.n).toBe(1);
    } finally {
      await mf.dispose();
    }
  });

  it("40 concurrent sends over two conversations: seq 1..20 contiguous and unique in each", async () => {
    rpc();
    const { mf, db } = await localD1();
    try {
      const rs = await Promise.all(Array.from({ length: 40 }, (_, i) => send(db, KEY(i + 1), `m${i}`, i % 2 ? CONV_B : CONV_A)));
      expect(rs.every((r) => r.status === 201)).toBe(true);
      for (const conv of [CONV_A, CONV_B]) {
        const r = await db.prepare("SELECT seq FROM messages WHERE conversation_id = ?1 ORDER BY seq").bind(conv).all<{ seq: number }>();
        expect(r.results.map((x) => x.seq)).toEqual(Array.from({ length: 20 }, (_, i) => i + 1));
      }
    } finally {
      await mf.dispose();
    }
  });

  it("another sender's message hides its client_key", async () => {
    const { state } = rpc();
    const { mf, db } = await localD1();
    try {
      await seed(db, 1);
      state.row = authRow({ user_id: "other-user" });
      const p = (await (await list(db)).json()) as any;
      expect(p.messages[0].client_key).toBeNull();
      expect(p.messages[0].sender_user_id).toBe("real-user");
    } finally {
      await mf.dispose();
    }
  });

  it("invalid input is 400 invalid_request with no RPC call", async () => {
    const { calls } = rpc();
    const { db, touched } = spyDb();
    const bad = [
      await send(db, "not-a-uuid"),
      await send(db, KEY(1), ""),
      await send(db, KEY(1), "x".repeat(2001)),
      await list(db, "?limit=51"),
      await list(db, "?limit=0"),
      await list(db, "?cursor=0"),
      await list(db, "?direction=sideways"),
      await list(db, "", "not-a-uuid"),
    ];
    for (const r of bad) {
      expect(r.status).toBe(400);
      expect(((await r.json()) as any).error.reason).toBe("invalid_request");
    }
    expect(calls.length).toBe(0);
    expect(touched).toEqual([]);
  });
});

describe("pagination by seq", () => {
  it("newest page, then older pages to the start, then newer pages back to the end; stable ascending order", async () => {
    rpc();
    const { mf, db } = await localD1();
    try {
      await seed(db, 7);
      const p1 = (await (await list(db, "?limit=3")).json()) as any;
      expect(p1.messages.map((x: any) => x.seq)).toEqual([5, 6, 7]);
      expect(p1).toMatchObject({ has_older: true, has_newer: false, older_cursor: 5, newer_cursor: null, page_size: 3 });
      const p2 = (await (await list(db, `?limit=3&cursor=${p1.older_cursor}&direction=older`)).json()) as any;
      expect(p2.messages.map((x: any) => x.seq)).toEqual([2, 3, 4]);
      expect(p2).toMatchObject({ has_older: true, has_newer: true, older_cursor: 2, newer_cursor: 4 });
      const p3 = (await (await list(db, `?limit=3&cursor=${p2.older_cursor}&direction=older`)).json()) as any;
      expect(p3.messages.map((x: any) => x.seq)).toEqual([1]);
      expect(p3).toMatchObject({ has_older: false, has_newer: true, older_cursor: null, newer_cursor: 1 });
      const n1 = (await (await list(db, `?limit=3&cursor=${p3.newer_cursor}&direction=newer`)).json()) as any;
      expect(n1.messages.map((x: any) => x.seq)).toEqual([2, 3, 4]);
      expect(n1).toMatchObject({ has_older: true, has_newer: true, older_cursor: 2, newer_cursor: 4 });
      const n2 = (await (await list(db, `?limit=3&cursor=${n1.newer_cursor}&direction=newer`)).json()) as any;
      expect(n2.messages.map((x: any) => x.seq)).toEqual([5, 6, 7]);
      expect(n2).toMatchObject({ has_older: true, has_newer: false, newer_cursor: null });
    } finally {
      await mf.dispose();
    }
  });

  it("exact-boundary pages and empty edges", async () => {
    rpc();
    const { mf, db } = await localD1();
    try {
      const empty = (await (await list(db)).json()) as any;
      expect(empty).toMatchObject({ messages: [], has_older: false, has_newer: false, older_cursor: null, newer_cursor: null, page_size: 30 });
      await seed(db, 6);
      const exact = (await (await list(db, "?limit=6")).json()) as any;
      expect(exact.messages.map((x: any) => x.seq)).toEqual([1, 2, 3, 4, 5, 6]);
      expect(exact.has_older).toBe(false);
      const atEnd = (await (await list(db, "?cursor=6&direction=newer")).json()) as any;
      expect(atEnd).toMatchObject({ messages: [], has_newer: false, has_older: true, older_cursor: 7 });
      const back = (await (await list(db, `?cursor=${atEnd.older_cursor}&direction=older&limit=2`)).json()) as any;
      expect(back.messages.map((x: any) => x.seq)).toEqual([5, 6]);
      const atStart = (await (await list(db, "?cursor=1&direction=older")).json()) as any;
      // The client already holds seq 1; nothing above the page to continue from: has_newer false, cursor null.
      expect(atStart).toMatchObject({ messages: [], has_older: false, has_newer: false, older_cursor: null, newer_cursor: null });
      const mid = (await (await list(db, "?cursor=3&direction=older&limit=1")).json()) as any;
      expect(mid).toMatchObject({ has_older: true, has_newer: true, older_cursor: 2, newer_cursor: 2 });
      const fwd = (await (await list(db, `?cursor=${mid.newer_cursor}&direction=newer&limit=2`)).json()) as any;
      expect(fwd.messages.map((x: any) => x.seq)).toEqual([3, 4]);
    } finally {
      await mf.dispose();
    }
  });
});

describe("invariant: has_X === (X_cursor !== null) on every response", () => {
  const check = (p: any, label: string) => {
    expect(p.has_older, `${label} older`).toBe(p.older_cursor !== null);
    expect(p.has_newer, `${label} newer`).toBe(p.newer_cursor !== null);
  };
  const walk = async (db: D1Database, max: number, label: string) => {
    for (const limit of [1, 2, 3, 6, 30]) {
      const qs = [`?limit=${limit}`];
      for (let c = 1; c <= max + 1; c++) for (const d of ["older", "newer"]) qs.push(`?limit=${limit}&cursor=${c}&direction=${d}`);
      for (const q of qs) {
        const res = await list(db, q);
        expect(res.status, `${label} ${q}`).toBe(200);
        check(await res.json(), `${label} ${q}`);
      }
    }
  };

  it("empty conversation, exact-limit, every cursor edge, both directions, with and without left_at_seq", async () => {
    const { state } = rpc();
    const { mf, db } = await localD1();
    try {
      await walk(db, 2, "empty");
      await seed(db, 6);
      await walk(db, 7, "six");
      const atStart = (await (await list(db, "?cursor=1&direction=older")).json()) as any;
      expect(atStart).toMatchObject({ has_newer: false, newer_cursor: null });
      for (const cap of [0, 1, 3, 6]) {
        state.row = authRow({ allowed_action: "read", reason: "left", left_at_seq: cap });
        await walk(db, 7, `cap${cap}`);
      }
    } finally {
      await mf.dispose();
    }
  }, 60_000);
});
