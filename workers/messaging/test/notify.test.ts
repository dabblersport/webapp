// KAN-543 (Realtime R3): the Worker asks Supabase to wake the members (public.msg_notify) after a NEW message is stored.
// Fire-and-forget through ctx.waitUntil. Local D1 emulator + stubbed fetch; nothing real is called.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { createHmac } from "node:crypto";
import { SNIPPET_MAC_HEADER, SNIPPET_MAX_CHARS, snippetMac, snippetOf } from "../src/notify";
import { CONV_A, RPC_URL, SUPABASE_URL, authRow, env, localD1 } from "./helpers";

const NOTIFY_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_notify`;
const TOKEN = "Bearer notify.test.token";
const KEY = (n: number) => `9b2f7c1e-0000-4000-8000-${String(n).padStart(12, "0")}`;

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

type NotifyReply = Response | Error | "hang";

/** Answers msg_authorize with `row`; msg_notify per `notify`. Any other URL is an unmocked hit. */
function stub(notify: NotifyReply = new Response(null, { status: 204 }), row: Record<string, unknown> = authRow()) {
  const notifyCalls: { url: string; init: RequestInit }[] = [];
  const unmocked: string[] = [];
  let release: (r: Response) => void = () => {};
  const gate = new Promise<Response>((res) => (release = res));
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      if (url === RPC_URL) return new Response(JSON.stringify([row]), { status: 200 });
      if (url === NOTIFY_URL) {
        notifyCalls.push({ url, init });
        if (notify === "hang") return gate;
        if (notify instanceof Error) throw notify;
        return notify.clone();
      }
      unmocked.push(url);
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { notifyCalls, unmocked, release };
}

/** A context that records what was scheduled. */
function context() {
  const scheduled: Promise<unknown>[] = [];
  return { ctx: { waitUntil: vi.fn((p: Promise<unknown>) => void scheduled.push(p)) }, scheduled };
}

const send = (db: D1Database, key: string, ctx: { waitUntil(p: Promise<unknown>): void } | undefined, extra: Record<string, string> = {}, body = "secret words") =>
  worker.fetch(
    new Request(`https://worker.local/v1/conversations/${CONV_A}/messages`, {
      method: "POST",
      headers: { Authorization: TOKEN, "content-type": "application/json", "Idempotency-Key": key },
      body: JSON.stringify({ body }),
    }),
    env(db, extra),
    ctx,
  );

describe("a new stored message wakes the members", () => {
  it("201 triggers exactly one msg_notify with the caller's token forwarded unchanged and the right body", async () => {
    const { notifyCalls, unmocked } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      const res = await send(db, KEY(1), ctx);
      expect(res.status).toBe(201);
      const msg = (await res.json()) as { seq: number };
      await Promise.all(scheduled);
      expect(notifyCalls).toHaveLength(1);
      const { init } = notifyCalls[0];
      expect(init.method).toBe("POST");
      const h = init.headers as Record<string, string>;
      expect(h.Authorization).toBe(TOKEN); // the caller's own header, byte for byte
      expect(h.apikey).toBe(env(db).SUPABASE_ANON_KEY);
      expect(JSON.parse(init.body as string)).toEqual({
        p_conversation_id: CONV_A,
        p_seq: msg.seq,
        p_access_mode: "allowlist",
        // KAN-984c: no MSG_SNIPPET_HMAC_KEY binding in this env, so no snippet and no MAC leave the Worker
      });
      expect(h[SNIPPET_MAC_HEADER]).toBeUndefined();
      expect(unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });

  it("the access mode is the same value msg_authorize gets (env override passed through)", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      await send(db, KEY(1), ctx, { MESSAGING_ACCESS_MODE: "all" });
      await Promise.all(scheduled);
      expect(JSON.parse(notifyCalls[0].init.body as string).p_access_mode).toBe("all");
    } finally {
      await mf.dispose();
    }
  });

  it("each new message wakes once, with its own seq", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      await send(db, KEY(1), ctx);
      await send(db, KEY(2), ctx);
      await Promise.all(scheduled);
      expect(notifyCalls.map((c) => JSON.parse(c.init.body as string).p_seq)).toEqual([1, 2]);
    } finally {
      await mf.dispose();
    }
  });
});

describe("no wake-up when nothing new was stored or sent", () => {
  it("an idempotent repeat (200) triggers none", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      expect((await send(db, KEY(1), ctx)).status).toBe(201);
      expect((await send(db, KEY(1), ctx, {}, "retry body differs")).status).toBe(200);
      await Promise.all(scheduled);
      expect(notifyCalls).toHaveLength(1);
      expect(ctx.waitUntil).toHaveBeenCalledTimes(1);
    } finally {
      await mf.dispose();
    }
  });

  it("a refused send (read-only game) triggers none", async () => {
    const { notifyCalls } = stub(undefined, authRow({ allowed_action: "read", reason: "game_ended" }));
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      expect((await send(db, KEY(1), ctx)).status).toBe(409);
      expect(notifyCalls).toHaveLength(0);
      expect(ctx.waitUntil).not.toHaveBeenCalled();
    } finally {
      await mf.dispose();
    }
  });

  it("a denied caller triggers none", async () => {
    const { notifyCalls } = stub(undefined, authRow({ user_id: null, allowed_action: null, reason: "not_member" }));
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      expect((await send(db, KEY(1), ctx)).status).toBe(403);
      expect(notifyCalls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("no execution context (a plain unit call) schedules nothing and still sends", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      expect((await send(db, KEY(1), undefined)).status).toBe(201);
      expect(notifyCalls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("the system-line route never calls msg_notify", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      const res = await worker.fetch(
        new Request("https://worker.local/internal/system-line", { method: "POST", body: "{}" }),
        env(db),
        ctx,
      );
      expect([401, 503]).toContain(res.status);
      expect(notifyCalls).toHaveLength(0);
      expect(ctx.waitUntil).not.toHaveBeenCalled();
    } finally {
      await mf.dispose();
    }
  });
});

describe("fire-and-forget: the send response never depends on msg_notify", () => {
  it("the call is scheduled with waitUntil, not awaited before the response", async () => {
    const { notifyCalls, release } = stub("hang");
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      const res = await send(db, KEY(1), ctx); // would never return if the hanging call were awaited
      expect(res.status).toBe(201);
      expect(ctx.waitUntil).toHaveBeenCalledTimes(1);
      const pending = Symbol("pending");
      expect(await Promise.race([scheduled[0], Promise.resolve(pending)])).toBe(pending); // still in flight
      release(new Response(null, { status: 204 }));
      await scheduled[0];
      expect(notifyCalls).toHaveLength(1);
    } finally {
      await mf.dispose();
    }
  });

  for (const [name, reply] of [
    ["a 500", new Response("boom", { status: 500 })],
    ["a 401", new Response("no", { status: 401 })],
    ["a network error", new Error("connection reset")],
  ] as const) {
    it(`${name} from msg_notify leaves the send response unchanged and is swallowed`, async () => {
      const { notifyCalls } = stub(reply);
      const { mf, db } = await localD1();
      try {
        const { ctx, scheduled } = context();
        const res = await send(db, KEY(1), ctx);
        expect(res.status).toBe(201);
        expect(((await res.json()) as { body: string }).body).toBe("secret words");
        await expect(Promise.all(scheduled)).resolves.toBeDefined(); // never rejects
        expect(notifyCalls).toHaveLength(1);
      } finally {
        await mf.dispose();
      }
    });
  }
});

describe("nothing sensitive is logged or leaked", () => {
  it("failures write nothing to any console and resolve to a bare status code or null", async () => {
    const logged: string[] = [];
    for (const m of ["log", "info", "warn", "error", "debug"] as const) {
      vi.spyOn(console, m).mockImplementation((...a: unknown[]) => void logged.push(a.map(String).join(" ")));
    }
    const outcomes: unknown[] = [];
    for (const reply of [new Response("secret words in an error body", { status: 500 }), new Error("token notify.test.token leaked in message")]) {
      stub(reply);
      const { mf, db } = await localD1();
      try {
        const { ctx, scheduled } = context();
        await send(db, KEY(1), ctx);
        outcomes.push(...(await Promise.all(scheduled)));
      } finally {
        await mf.dispose();
      }
    }
    expect(outcomes).toEqual([500, null]); // only a status code, or null: no text, no error object
    expect(logged).toEqual([]);
  });

  it("src has no logging call and no elevated key or token decoding", () => {
    const dir = fileURLToPath(new URL("../src", import.meta.url));
    const text = readdirSync(dir).map((f) => readFileSync(join(dir, f), "utf8")).join("\n");
    expect(/\bconsole\s*\./.test(text)).toBe(false);
    for (const re of [/SERVICE_ROLE/i, /jwt-decode/i, /JWT_SECRET/i]) expect(re.test(text)).toBe(false);
  });
});

// KAN-984 (W1-B6): the push snippet. Supabase applies the recipient's message_preview; the Worker offers it only with
// a MAC (KAN-984c, option A): HMAC-SHA256(MSG_SNIPPET_HMAC_KEY, "<conversation>:<seq>:<snippet>") in x-msg-snippet-mac.
// TEST_KEY is a throwaway test value, not the real key (which exists only in the two secret stores).
const TEST_KEY = "kan984c-test-key-not-the-real-one";
const WITH_KEY = { MSG_SNIPPET_HMAC_KEY: TEST_KEY };
/** The MAC computed independently with node:crypto, the way msg_notify recomputes it with pgcrypto. */
const expectedMac = (conv: string, seq: number, snippet: string) =>
  createHmac("sha256", TEST_KEY).update(`${conv}:${seq}:${snippet}`, "utf8").digest("hex");

describe("KAN-984 the message text goes along as the push snippet, with its MAC", () => {
  it("no key binding: no snippet and no MAC header (the 3-argument msg_notify, sender only)", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      await send(db, KEY(1), ctx, {}, "see you at 8");
      await Promise.all(scheduled);
      const h = notifyCalls[0].init.headers as Record<string, string>;
      expect(JSON.parse(notifyCalls[0].init.body as string).p_snippet).toBeUndefined();
      expect(h[SNIPPET_MAC_HEADER]).toBeUndefined();
    } finally {
      await mf.dispose();
    }
  });

  it("with the key: p_snippet = the trimmed text and a good MAC over conversation:seq:snippet; the token is unchanged", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      const res = await send(db, KEY(1), ctx, WITH_KEY, "  see you at 8  ");
      const msg = (await res.json()) as { seq: number };
      await Promise.all(scheduled);
      const h = notifyCalls[0].init.headers as Record<string, string>;
      const sent = JSON.parse(notifyCalls[0].init.body as string);
      expect(sent.p_snippet).toBe("see you at 8");
      expect(h[SNIPPET_MAC_HEADER]).toBe(expectedMac(CONV_A, msg.seq, "see you at 8"));
      expect(h.Authorization).toBe(TOKEN);
      // the key itself never travels
      expect(JSON.stringify(notifyCalls[0].init)).not.toContain(TEST_KEY);
    } finally {
      await mf.dispose();
    }
  });

  it("a MAC is bound to its seq and its text: another seq or another text gives another MAC", async () => {
    const good = await snippetMac(TEST_KEY, CONV_A, 7, "see you at 8");
    expect(good).toBe(expectedMac(CONV_A, 7, "see you at 8"));
    expect(await snippetMac(TEST_KEY, CONV_A, 8, "see you at 8")).not.toBe(good); // wrong seq
    expect(await snippetMac(TEST_KEY, CONV_A, 7, "see you at 9")).not.toBe(good); // wrong text
    expect(await snippetMac(TEST_KEY, "22222222-2222-4222-8222-222222222222", 7, "see you at 8")).not.toBe(good);
    expect(await snippetMac("another-key", CONV_A, 7, "see you at 8")).not.toBe(good); // wrong key
    // the conversation id is lowercased, as Postgres prints a uuid
    expect(await snippetMac(TEST_KEY, CONV_A.toUpperCase(), 7, "see you at 8")).toBe(good);
  });

  it("the MAC covers the exact text sent: Arabic, emoji, cut to SNIPPET_MAX_CHARS characters (not bytes)", async () => {
    const { notifyCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      const res = await send(db, KEY(1), ctx, WITH_KEY, "ب".repeat(300) + "⚽");
      const msg = (await res.json()) as { seq: number };
      await Promise.all(scheduled);
      const sent = JSON.parse(notifyCalls[0].init.body as string).p_snippet as string;
      expect(Array.from(sent)).toHaveLength(SNIPPET_MAX_CHARS);
      const h = notifyCalls[0].init.headers as Record<string, string>;
      expect(h[SNIPPET_MAC_HEADER]).toBe(expectedMac(CONV_A, msg.seq, sent));
    } finally {
      await mf.dispose();
    }
  });

  it("snippetOf: empty or whitespace text gives no snippet; controls and lone surrogates are made safe", () => {
    expect(snippetOf("")).toBeNull();
    expect(snippetOf("   ")).toBeNull();
    expect(snippetOf(null)).toBeNull();
    expect(snippetOf(undefined)).toBeNull();
    expect(snippetOf("hi")).toBe("hi");
    expect(snippetOf("a\u0000b\nc")).toBe("a b c");
    expect(snippetOf("x\ud800y")).toBe("x�y");
    expect(snippetOf("goal ⚽")).toBe("goal ⚽"); // a real surrogate pair is kept
  });
});
