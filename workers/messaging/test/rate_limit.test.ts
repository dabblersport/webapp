// KAN-548: per-user rate limits on send and report. LOCAL-EMULATOR TESTS: Miniflare in-memory D1 + mocked
// msg_authorize / msg_report_message. No network, nothing deployed. The clock is Date.now, pinned per test.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import {
  HOUR_SECONDS,
  MINUTE_SECONDS,
  REPORT_PER_USER_PER_HOUR,
  SEND_PER_USER_PER_CONVERSATION_PER_MINUTE,
  SEND_PER_USER_PER_HOUR,
  checkSend,
} from "../src/rate_limit";
import { CONV_A, RPC_URL, SUPABASE_URL, authRow, env, localD1 } from "./helpers";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const REPORT_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_report_message`;
const KEY = (n: number) => `9b2f7c1e-0000-4000-8000-${String(n).padStart(12, "0")}`;
const CONV = (n: number) => `33333333-3333-4333-8333-${String(n).padStart(12, "0")}`;
const MSG = (n: number) => `44444444-4444-4444-8444-${String(n).padStart(12, "0")}`;
// 2026-10-15 10:00:10 UTC: 10 s into a minute window and into an hour window.
const T0 = Date.UTC(2026, 9, 15, 10, 0, 10);
const pin = (ms: number) => vi.spyOn(Date, "now").mockReturnValue(ms);

/** The bearer token IS the verified user id for the mocked msg_authorize (what the real RPC derives from the JWT). */
function rpcs() {
  const reportBodies: unknown[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      const user = ((init.headers as Record<string, string>).Authorization ?? "").replace("Bearer ", "");
      if (url === RPC_URL) return new Response(JSON.stringify([authRow({ user_id: user })]), { status: 200 });
      if (url === REPORT_URL) {
        reportBodies.push(JSON.parse(init.body as string));
        return new Response(JSON.stringify([{ report_id: "r", created: true }]), { status: 200 });
      }
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { reportBodies };
}

const send = (db: D1Database, user: string, conv: string, n: number, extra: Record<string, string> = {}, body: Record<string, unknown> = {}) =>
  worker.fetch(
    new Request(`https://worker.local/v1/conversations/${conv}/messages`, {
      method: "POST",
      headers: { Authorization: `Bearer ${user}`, "content-type": "application/json", "Idempotency-Key": KEY(n), ...extra },
      body: JSON.stringify({ body: `m${n}`, ...body }),
    }),
    env(db),
  );
const report = (db: D1Database, user: string, id: string) =>
  worker.fetch(
    new Request(`https://worker.local/v1/messages/${id}/report`, {
      method: "POST",
      headers: { Authorization: `Bearer ${user}`, "content-type": "application/json" },
      body: JSON.stringify({ reason: "spam" }),
    }),
    env(db),
  );

const count = async (db: D1Database, sql: string, ...args: unknown[]) =>
  (await db.prepare(sql).bind(...args).first<{ c: number }>())!.c;
const messages = (db: D1Database) => count(db, "SELECT COUNT(*) AS c FROM messages");

async function refusal(res: Response) {
  expect(res.status).toBe(429);
  expect(((await res.json()) as any).error.reason).toBe("rate_limited");
  const retry = res.headers.get("Retry-After");
  expect(retry).toMatch(/^[1-9][0-9]*$/); // whole seconds
  return Number(retry);
}

/** The user's hour count and one conversation's minute count, read back from the single 'send' row. */
async function sendCounters(db: D1Database, user: string, conv: string) {
  return db
    .prepare("SELECT count AS hour, json_extract(sub_counts, ?2) AS minute FROM rate_limits WHERE subject = ?1 AND scope = 'send'")
    .bind(user, `$."${conv}"`)
    .first<{ hour: number; minute: number }>();
}

/** Wraps a D1 binding so every `INSERT INTO rate_limits` records the rows_written D1 reports for it. */
function rateLimitWrites(db: D1Database) {
  const rows: number[] = [];
  const handler = {
    get(target: any, prop: string | symbol) {
      if (prop !== "prepare") return Reflect.get(target, prop);
      return (sql: string) => {
        const stmt = target.prepare(sql);
        if (!sql.includes("INTO rate_limits")) return stmt;
        return {
          bind: (...args: unknown[]) => {
            const bound = stmt.bind(...args);
            return {
              all: async () => {
                const res = await bound.all();
                rows.push(res.meta.rows_written as number);
                return res;
              },
            };
          },
        };
      };
    },
  };
  return { db: new Proxy(db, handler) as D1Database, rows };
}

describe("send: 20 a minute per user per conversation", () => {
  it("the 21st send in a minute is refused: 429, rate_limited, numeric Retry-After, and nothing is written", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      for (let n = 1; n <= SEND_PER_USER_PER_CONVERSATION_PER_MINUTE; n++) {
        expect((await send(db, "u1", CONV_A, n)).status).toBe(201);
      }
      const before = await messages(db);
      const retry = await refusal(await send(db, "u1", CONV_A, 21));
      expect(retry).toBe(MINUTE_SECONDS - 10); // the window started 10 s ago: whole seconds until it ends
      expect(await messages(db)).toBe(before); // no message
      expect(await count(db, "SELECT COUNT(*) AS c FROM messages WHERE client_key = ?1", KEY(21).toLowerCase())).toBe(0);
      // the refused request did not advance the counter either (a false WHERE writes nothing)
      expect(await sendCounters(db, "u1", CONV_A)).toEqual({ hour: 20, minute: 20 });
    } finally {
      await mf.dispose();
    }
  });

  it("another user in the same conversation is unaffected", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      for (let n = 1; n <= 21; n++) await send(db, "u1", CONV_A, n);
      expect((await send(db, "u2", CONV_A, 100)).status).toBe(201);
      expect((await send(db, "u1", CONV(2), 101)).status).toBe(201); // same user, another conversation: its own minute
    } finally {
      await mf.dispose();
    }
  });

  it("the window resets after it ends", async () => {
    const clock = pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      for (let n = 1; n <= 20; n++) await send(db, "u1", CONV_A, n);
      await refusal(await send(db, "u1", CONV_A, 21));
      clock.mockReturnValue(T0 + (MINUTE_SECONDS - 10) * 1000); // the next minute window begins
      expect((await send(db, "u1", CONV_A, 22)).status).toBe(201);
      expect(await sendCounters(db, "u1", CONV_A)).toEqual({ hour: 21, minute: 1 }); // refused attempts never counted
    } finally {
      await mf.dispose();
    }
  });

  it("two simultaneous sends at the limit cannot both pass", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      for (let n = 1; n <= 19; n++) await send(db, "u1", CONV_A, n);
      const [a, b] = await Promise.all([send(db, "u1", CONV_A, 50), send(db, "u1", CONV_A, 51)]);
      expect([a.status, b.status].sort()).toEqual([201, 429]);
      expect(await messages(db)).toBe(20);
    } finally {
      await mf.dispose();
    }
  });

  it("a flood of parallel requests admits exactly the limit", async () => {
    pin(T0);
    const { mf, db } = await localD1();
    try {
      const outcomes = await Promise.all(Array.from({ length: 30 }, () => checkSend(db, "u1", CONV_A)));
      expect(outcomes.filter((o) => o.ok)).toHaveLength(SEND_PER_USER_PER_CONVERSATION_PER_MINUTE);
      expect(await sendCounters(db, "u1", CONV_A)).toEqual({ hour: 20, minute: 20 });
    } finally {
      await mf.dispose();
    }
  });

  it("an admitted send writes exactly ONE counter row, a refused one none, whatever the conversation", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      const written = rateLimitWrites(db);
      for (let c = 1; c <= 3; c++) expect((await send(written.db, "u1", CONV(c), c)).status).toBe(201);
      expect(written.rows).toEqual([1, 1, 1]); // one written row per admitted send (rows_written)
      expect(await count(db, "SELECT COUNT(*) AS c FROM rate_limits")).toBe(1); // both limits share the user's one row
      for (let n = 4; n <= 22; n++) await send(written.db, "u1", CONV(1), n); // conversation 1 reaches its 20
      written.rows.length = 0;
      await refusal(await send(written.db, "u1", CONV(1), 99));
      expect(written.rows).toEqual([0]); // refused: the conditional upsert performed no write
    } finally {
      await mf.dispose();
    }
  });

  it("the minute limit refuses with the minute wait while the hour still has room", async () => {
    pin(T0);
    const { mf, db } = await localD1();
    try {
      for (let n = 0; n < SEND_PER_USER_PER_CONVERSATION_PER_MINUTE; n++) await checkSend(db, "u1", CONV_A);
      expect(await checkSend(db, "u1", CONV_A)).toEqual({ ok: false, retryAfterSeconds: MINUTE_SECONDS - 10 });
      expect(await checkSend(db, "u1", CONV(2))).toEqual({ ok: true }); // another conversation: its own minute
    } finally {
      await mf.dispose();
    }
  });
});

describe("send: 120 an hour per user across conversations", () => {
  it("the 121st send in an hour is refused", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      // 6 conversations x 20 = 120 sends, each within its own per-minute limit.
      let n = 0;
      for (let c = 1; c <= 6; c++) for (let i = 0; i < SEND_PER_USER_PER_CONVERSATION_PER_MINUTE; i++) {
        expect((await send(db, "u1", CONV(c), ++n)).status).toBe(201);
      }
      expect(n).toBe(SEND_PER_USER_PER_HOUR);
      const retry = await refusal(await send(db, "u1", CONV(7), ++n)); // a fresh conversation: only the hour limit binds
      expect(retry).toBe(HOUR_SECONDS - 10);
      expect(await messages(db)).toBe(SEND_PER_USER_PER_HOUR);
      expect((await send(db, "u2", CONV(7), ++n)).status).toBe(201); // another user is unaffected
    } finally {
      await mf.dispose();
    }
  }, 120000);
});

describe("report: 10 an hour per user", () => {
  it("the 11th report in an hour is refused and nothing is relayed or held", async () => {
    pin(T0);
    const { reportBodies } = rpcs();
    const { mf, db } = await localD1();
    try {
      for (let i = 1; i <= REPORT_PER_USER_PER_HOUR + 1; i++) {
        await db
          .prepare("INSERT INTO messages (id, conversation_id, seq, sender_id, body, created_at, client_key, legal_hold) VALUES (?1, ?2, ?3, 's', 'x', '2026-10-15T10:00:00.000Z', ?4, 0)")
          .bind(MSG(i), CONV_A, i, `k${i}`)
          .run();
      }
      for (let i = 1; i <= REPORT_PER_USER_PER_HOUR; i++) expect((await report(db, "u1", MSG(i))).status).toBe(202);
      const retry = await refusal(await report(db, "u1", MSG(11)));
      expect(retry).toBe(HOUR_SECONDS - 10);
      expect(reportBodies).toHaveLength(REPORT_PER_USER_PER_HOUR); // the 11th never reached msg_report_message
      expect(await count(db, "SELECT legal_hold AS c FROM messages WHERE id = ?1", MSG(11))).toBe(0); // and set no hold
      expect((await report(db, "u2", MSG(11))).status).toBe(202); // another user is unaffected
    } finally {
      await mf.dispose();
    }
  });
});

describe("the key is the verified user, never a client-supplied value", () => {
  it("spoofed headers and body fields do not move or reset a user's counter", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      for (let n = 1; n <= 20; n++) {
        await send(db, "u1", CONV_A, n, { "X-User-Id": `spoof-${n}`, "X-Forwarded-For": `10.0.0.${n}`, "CF-Connecting-IP": `10.1.0.${n}` }, { user_id: `spoof-${n}`, sender_id: `spoof-${n}` });
      }
      await refusal(await send(db, "u1", CONV_A, 21, { "X-User-Id": "someone-else", "X-Forwarded-For": "1.2.3.4" }, { user_id: "someone-else" }));
      expect(await count(db, "SELECT COUNT(*) AS c FROM rate_limits WHERE subject <> 'u1'")).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("reads are not limited", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      for (let n = 1; n <= 21; n++) await send(db, "u1", CONV_A, n);
      for (let i = 0; i < 5; i++) {
        const res = await worker.fetch(
          new Request(`https://worker.local/v1/conversations/${CONV_A}/messages`, { headers: { Authorization: "Bearer u1" } }),
          env(db),
        );
        expect(res.status).toBe(200);
      }
    } finally {
      await mf.dispose();
    }
  });

  it("a refusal carries Retry-After through CORS for the web app", async () => {
    pin(T0);
    rpcs();
    const { mf, db } = await localD1();
    try {
      for (let n = 1; n <= 20; n++) await send(db, "u1", CONV_A, n);
      const res = await send(db, "u1", CONV_A, 21, { Origin: "https://alpha.dabbler.pro" });
      expect(res.status).toBe(429);
      expect(res.headers.get("Access-Control-Expose-Headers")).toBe("Retry-After");
    } finally {
      await mf.dispose();
    }
  });
});

describe("module and migration shape", () => {
  const SRC = fileURLToPath(new URL("../src/rate_limit.ts", import.meta.url));
  const text = readFileSync(SRC, "utf8");

  it("the named constants carry the stated defaults", () => {
    expect(SEND_PER_USER_PER_CONVERSATION_PER_MINUTE).toBe(20);
    expect(SEND_PER_USER_PER_HOUR).toBe(120);
    expect(REPORT_PER_USER_PER_HOUR).toBe(10);
    expect(text).toMatch(/export const SEND_PER_USER_PER_CONVERSATION_PER_MINUTE = 20;/);
    expect(text).toMatch(/export const SEND_PER_USER_PER_HOUR = 120;/);
    expect(text).toMatch(/export const REPORT_PER_USER_PER_HOUR = 10;/);
  });

  it("no logging and no forbidden resource in the module", () => {
    expect(/\bconsole\s*\./.test(text)).toBe(false);
    expect(/\b(KVNamespace|DurableObject|R2Bucket|setInterval|setTimeout|waitUntil|scheduled)\b/.test(text)).toBe(false);
  });

  it("migration 0004 is additive: CREATE TABLE IF NOT EXISTS, no DROP, no DELETE", () => {
    const dir = fileURLToPath(new URL("../migrations/", import.meta.url));
    const file = readdirSync(dir).find((f) => f.startsWith("0004_"))!;
    const sql = readFileSync(join(dir, file), "utf8")
      .split("\n")
      .filter((l) => !l.trim().startsWith("--"))
      .join("\n");
    expect(file).toBe("0004_rate_limits.sql");
    expect(sql).toMatch(/CREATE TABLE IF NOT EXISTS rate_limits/);
    expect(/\b(DROP|DELETE|ALTER|UPDATE)\b/i.test(sql)).toBe(false);
  });
});
