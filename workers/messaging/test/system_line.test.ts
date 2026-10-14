// KAN-510 (T15): the signed internal endpoint. Local D1 emulator only; nothing real is called.
import { createHmac } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CONV_A, CONV_B, env, localD1, mockFetch, spyDb } from "./helpers";

// A throwaway test value, built at runtime: not a real key and not shared with any environment.
const TEST_KEY = ["unit", "test", "key", "only"].join("-");
const URL_ = "https://worker.example.invalid/internal/system-line";
const EVENT = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const USER = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";

const sign = (body: string, key = TEST_KEY) => "sha256=" + createHmac("sha256", key).update(body).digest("hex");
const payload = (over: Record<string, unknown> = {}) =>
  JSON.stringify({ event_id: EVENT, conversation_id: CONV_A, event: "joined", user_id: USER, ...over });

function post(body: string, sig: string | null) {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (sig !== null) headers["X-Msg-Signature"] = sig;
  return new Request(URL_, { method: "POST", headers, body });
}

async function count(db: D1Database) {
  const r = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
  return r?.n ?? 0;
}

afterEach(() => vi.unstubAllGlobals());

describe("POST /internal/system-line", () => {
  it("a valid signature stores one system line", async () => {
    const { mf, db } = await localD1();
    const net = mockFetch(new Response("{}"));
    const body = payload();
    const res = await worker.fetch(post(body, sign(body)), env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY }));
    expect(res.status).toBe(201);
    expect(await count(db)).toBe(1);
    const row = await db.prepare("SELECT * FROM messages").first<Record<string, unknown>>();
    expect(row?.sender_id).toBe("system");
    expect(row?.client_key).toBe(EVENT);
    expect(JSON.parse(row?.body as string)).toEqual({ event: "joined", user_id: USER });
    expect(net.calls).toEqual([]); // no outbound call at all
    await mf.dispose();
  });

  it("a missing signature stores none", async () => {
    const { mf, db } = await localD1();
    const res = await worker.fetch(post(payload(), null), env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY }));
    expect(res.status).toBe(401);
    expect(await count(db)).toBe(0);
    await mf.dispose();
  });

  it("a bad signature (wrong key) stores none", async () => {
    const { mf, db } = await localD1();
    const body = payload();
    const res = await worker.fetch(post(body, sign(body, "another-key")), env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY }));
    expect(res.status).toBe(401);
    expect(await count(db)).toBe(0);
    await mf.dispose();
  });

  it("a tampered body stores none", async () => {
    const { mf, db } = await localD1();
    const body = payload();
    const tampered = payload({ conversation_id: CONV_B });
    const res = await worker.fetch(post(tampered, sign(body)), env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY }));
    expect(res.status).toBe(401);
    expect(await count(db)).toBe(0);
    await mf.dispose();
  });

  it("a malformed signature header stores none", async () => {
    const { mf, db } = await localD1();
    const body = payload();
    for (const bad of ["", "sha256=", "sha256=zz", sign(body).toUpperCase(), sign(body).slice(7)]) {
      const res = await worker.fetch(post(body, bad), env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY }));
      expect(res.status).toBe(401);
    }
    expect(await count(db)).toBe(0);
    await mf.dispose();
  });

  it("an unset secret binding fails closed with no write and no DB touch", async () => {
    const { db, touched } = spyDb();
    const body = payload();
    const res = await worker.fetch(post(body, sign(body)), env(db));
    expect(res.status).toBe(503);
    expect(touched).toEqual([]);
  });

  it("a bad signature never touches the database", async () => {
    const { db, touched } = spyDb();
    const res = await worker.fetch(post(payload(), "sha256=" + "0".repeat(64)), env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY }));
    expect(res.status).toBe(401);
    expect(touched).toEqual([]);
  });

  it("the same event delivered twice stores one line", async () => {
    const { mf, db } = await localD1();
    const body = payload();
    const e = env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY });
    const first = await worker.fetch(post(body, sign(body)), e);
    const second = await worker.fetch(post(body, sign(body)), e);
    expect(first.status).toBe(201);
    expect(second.status).toBe(200);
    expect((await second.json()) as { created: boolean }).toMatchObject({ created: false });
    expect(await count(db)).toBe(1);
    await mf.dispose();
  });

  it("different events get gap-free seqs and a different conversation is independent", async () => {
    const { mf, db } = await localD1();
    const e = env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY });
    const send = async (over: Record<string, unknown>) => {
      const b = payload(over);
      return (await (await worker.fetch(post(b, sign(b)), e)).json()) as { seq: number };
    };
    expect((await send({})).seq).toBe(1);
    expect((await send({ event_id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc", event: "left" })).seq).toBe(2);
    expect((await send({ conversation_id: CONV_B })).seq).toBe(1);
    await mf.dispose();
  });

  it("a cancelled event has no user; a roster event requires one; unknown events are refused", async () => {
    const { mf, db } = await localD1();
    const e = env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY });
    const run = async (body: string) => (await worker.fetch(post(body, sign(body)), e)).status;
    expect(await run(JSON.stringify({ event_id: EVENT, conversation_id: CONV_A, event: "cancelled" }))).toBe(201);
    expect(await run(payload({ event_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", event: "cancelled" }))).toBe(400); // carries a user
    expect(await run(payload({ event_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", user_id: undefined }))).toBe(400); // joined without user
    expect(await run(payload({ event_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd", event: "finished" }))).toBe(400);
    expect(await run("not json")).toBe(400);
    expect(await count(db)).toBe(1);
    await mf.dispose();
  });

  it("the list endpoint shows the stored line as kind system with no sender", async () => {
    const { mf, db } = await localD1();
    const body = payload();
    await worker.fetch(post(body, sign(body)), env(db, { MSG_SYSTEM_HMAC_SECRET: TEST_KEY }));
    mockFetch(
      new Response(
        JSON.stringify([{ user_id: USER, allowed_action: "send", reason: null, left_at_seq: null, member_user_ids: [], hidden_sender_ids: [] }]),
        { headers: { "content-type": "application/json" } },
      ),
    );
    const res = await worker.fetch(
      new Request(`https://worker.example.invalid/v1/conversations/${CONV_A}/messages`, { headers: { Authorization: "Bearer t" } }),
      env(db),
    );
    const page = (await res.json()) as { messages: { kind: string; sender_user_id: unknown; client_key: unknown; body: string }[] };
    expect(page.messages).toHaveLength(1);
    expect(page.messages[0]).toMatchObject({ kind: "system", sender_user_id: null, client_key: null });
    expect(JSON.parse(page.messages[0].body)).toEqual({ event: "joined", user_id: USER });
    await mf.dispose();
  });
});

describe("source hygiene", () => {
  const SRC = fileURLToPath(new URL("../src", import.meta.url));
  const text = readdirSync(SRC).map((f) => readFileSync(`${SRC}/${f}`, "utf8")).join("\n");
  it("names the secret binding but never a value, and emits no 'finished' line", () => {
    expect(text).toContain("MSG_SYSTEM_HMAC_SECRET");
    expect(text).not.toMatch(/MSG_SYSTEM_HMAC_SECRET\s*[:=]\s*["'`][^"'`]/);
    const sys = readFileSync(`${SRC}/system_line.ts`, "utf8");
    expect(sys).not.toMatch(/"finished"/);
    expect(sys).not.toMatch(/setTimeout|setInterval|scheduled\s*\(/);
  });
});
