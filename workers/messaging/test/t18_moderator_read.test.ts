// KAN-513 (T18) audited moderator read. LOCAL-EMULATOR TESTS: Miniflare in-memory D1 + mocked Supabase calls.
// No network, no real database, nothing deployed. The three Supabase calls (rpc/is_admin, rpc/admin_actor and the
// v_mod_queue_open view) are answered by a stub; their real behaviour is the existing admin tooling's and is NOT
// exercised here (AUTHORED, NOT RUN against a live project).
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { SUPABASE_URL, env, localD1, spyDb } from "./helpers";

afterEach(() => vi.unstubAllGlobals());

const REPORT = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const MESSAGE = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const CONV = "11111111-1111-4111-8111-111111111111";
const MODERATOR = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const SENDER = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const SECRET_TEXT = "SECRET-MESSAGE-TEXT-7f3a"; // a marker we can search for everywhere it must NOT appear
const BEARER = "Bearer some.opaque.token";
const H = { Authorization: BEARER };

interface Stub {
  isAdmin?: unknown;
  actor?: unknown;
  view?: unknown;
  isAdminStatus?: number;
}

/** Answers the three Supabase URLs the moderator read may call; any other URL is recorded and rejected. */
function supabaseStub(s: Stub = {}) {
  const calls: { url: string; method: string; headers: Record<string, string>; body: string | null }[] = [];
  const unmocked: string[] = [];
  const reply = (v: unknown, status = 200) => new Response(JSON.stringify(v), { status });
  const fn = vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    calls.push({
      url,
      method: init.method ?? "GET",
      headers: { ...(init.headers as Record<string, string>) },
      body: (init.body as string | undefined) ?? null,
    });
    if (url === `${SUPABASE_URL}/rest/v1/rpc/is_admin`) return reply("isAdmin" in s ? s.isAdmin : true, s.isAdminStatus ?? 200);
    if (url === `${SUPABASE_URL}/rest/v1/rpc/admin_actor`) return reply("actor" in s ? s.actor : MODERATOR);
    if (url.startsWith(`${SUPABASE_URL}/rest/v1/v_mod_queue_open?`)) {
      return reply("view" in s ? s.view : [{ report_id: REPORT, target_type: "message", target_id: MESSAGE }]);
    }
    unmocked.push(url);
    throw new Error(`unmocked host hit: ${url}`);
  });
  vi.stubGlobal("fetch", fn);
  return { calls, unmocked };
}

const readUrl = (id = REPORT) => `https://worker.local/v1/moderation/reports/${id}/message`;
const read = (db: D1Database, headers: Record<string, string> = H, id = REPORT) =>
  worker.fetch(new Request(readUrl(id), { headers }), env(db));

async function withMessage() {
  const d = await localD1();
  const migration = readFileSync(fileURLToPath(new URL("../migrations/0002_moderator_reads.sql", import.meta.url)), "utf8");
  const statements = migration
    .split("\n")
    .filter((l) => !l.trim().startsWith("--"))
    .join("\n")
    .split(";")
    .map((x) => x.trim())
    .filter(Boolean);
  await d.db.batch(statements.map((x) => d.db.prepare(x)));
  await d.db
    .prepare(
      "INSERT INTO messages (id, conversation_id, seq, sender_id, body, created_at, client_key, legal_hold) VALUES (?1, ?2, 1, ?3, ?4, ?5, ?6, 0)",
    )
    .bind(MESSAGE, CONV, SENDER, SECRET_TEXT, "2026-10-13T10:00:00.000Z", "k1")
    .run();
  return d;
}

const auditRows = async (db: D1Database) =>
  (await db.prepare("SELECT * FROM moderator_reads ORDER BY read_at").all<Record<string, unknown>>()).results;

describe("a moderator reads the reported message", () => {
  it("returns the text and writes exactly one audit row", async () => {
    const { calls } = supabaseStub();
    const { mf, db } = await withMessage();
    try {
      const res = await read(db);
      expect(res.status).toBe(200);
      expect(res.headers.get("cache-control")).toBe("no-store");
      expect(await res.json()).toEqual({
        report_id: REPORT,
        message: {
          id: MESSAGE,
          conversation_id: CONV,
          seq: 1,
          sender_user_id: SENDER,
          kind: "text",
          body: SECRET_TEXT,
          created_at: "2026-10-13T10:00:00.000Z",
        },
      });
      const rows = await auditRows(db);
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ moderator_id: MODERATOR, report_id: REPORT, message_id: MESSAGE });
      expect(typeof rows[0].read_at).toBe("string");
      expect(calls.map((c) => c.url.replace(SUPABASE_URL, "").split("?")[0])).toEqual([
        "/rest/v1/rpc/is_admin",
        "/rest/v1/rpc/admin_actor",
        "/rest/v1/v_mod_queue_open",
      ]);
    } finally {
      await mf.dispose();
    }
  });

  it("the audit row holds ids and a timestamp, never the text", async () => {
    supabaseStub();
    const { mf, db } = await withMessage();
    try {
      await read(db);
      const rows = await auditRows(db);
      expect(Object.keys(rows[0]).sort()).toEqual(["id", "message_id", "moderator_id", "read_at", "report_id"]);
      expect(JSON.stringify(rows)).not.toContain(SECRET_TEXT);
      const cols = (await db.prepare("PRAGMA table_info(moderator_reads)").all<{ name: string }>()).results.map((c) => c.name);
      expect(cols).not.toContain("body");
    } finally {
      await mf.dispose();
    }
  });

  it("writes one audit row per read: two reads, two rows", async () => {
    supabaseStub();
    const { mf, db } = await withMessage();
    try {
      expect((await read(db)).status).toBe(200);
      expect((await read(db)).status).toBe(200);
      expect(await auditRows(db)).toHaveLength(2);
    } finally {
      await mf.dispose();
    }
  });

  it("forwards the caller's bearer unchanged to every call and asks the view for ids only", async () => {
    const { calls } = supabaseStub();
    const { mf, db } = await withMessage();
    try {
      await read(db);
      expect(calls).toHaveLength(3);
      for (const c of calls) expect(c.headers.Authorization).toBe(BEARER);
      const view = new URL(calls[2].url);
      expect(view.searchParams.get("report_id")).toBe(`eq.${REPORT}`);
      expect(view.searchParams.get("select")).toBe("report_id,target_type,target_id"); // never `details`
    } finally {
      await mf.dispose();
    }
  });
});

describe("a non-moderator gets a typed refusal and no text", () => {
  it("is_admin false: 403 not_a_moderator, no text, no audit row, one call, no D1 access", async () => {
    const { calls } = supabaseStub({ isAdmin: false });
    const { mf, db } = await withMessage();
    try {
      const res = await read(db);
      expect(res.status).toBe(403);
      const text = await res.text();
      expect(JSON.parse(text).error.reason).toBe("not_a_moderator");
      expect(text).not.toContain(SECRET_TEXT);
      expect(await auditRows(db)).toHaveLength(0);
      expect(calls).toHaveLength(1); // stopped at the admin check: the id and the report are never looked up
    } finally {
      await mf.dispose();
    }
  });

  it("is_admin false never touches the DB binding", async () => {
    supabaseStub({ isAdmin: false });
    const { db, touched } = spyDb();
    expect((await read(db)).status).toBe(403);
    expect(touched).toEqual([]);
  });

  it("no Authorization header: 401, no Supabase call, no DB", async () => {
    const { calls } = supabaseStub();
    const { db, touched } = spyDb();
    const res = await read(db, {});
    expect(res.status).toBe(401);
    expect(calls).toHaveLength(0);
    expect(touched).toEqual([]);
  });

  it("a rejected token (401 from the admin check): 401, no text, no DB", async () => {
    supabaseStub({ isAdmin: { message: "JWT expired" }, isAdminStatus: 401 });
    const { db, touched } = spyDb();
    const res = await read(db);
    expect(res.status).toBe(401);
    expect(touched).toEqual([]);
  });

  it("a non-boolean admin answer is refused as malformed (502), never treated as yes", async () => {
    supabaseStub({ isAdmin: "true" });
    const { db, touched } = spyDb();
    expect((await read(db)).status).toBe(502);
    expect(touched).toEqual([]);
  });
});

describe("not found and bad input return no text and no audit row", () => {
  it("a missing report id (no row in the moderator view) is 404 not_found", async () => {
    supabaseStub({ view: [] });
    const { mf, db } = await withMessage();
    try {
      const res = await read(db);
      expect(res.status).toBe(404);
      const text = await res.text();
      expect(JSON.parse(text).error.reason).toBe("not_found");
      expect(text).not.toContain(SECRET_TEXT);
      expect(await auditRows(db)).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a report whose message is not in the store is 404 not_found with no audit row", async () => {
    supabaseStub({ view: [{ report_id: REPORT, target_type: "message", target_id: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee" }] });
    const { mf, db } = await withMessage();
    try {
      const res = await read(db);
      expect(res.status).toBe(404);
      expect(((await res.json()) as any).error.reason).toBe("not_found");
      expect(await auditRows(db)).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a report about something other than a message is refused (400), not read", async () => {
    supabaseStub({ view: [{ report_id: REPORT, target_type: "post", target_id: MESSAGE }] });
    const { mf, db } = await withMessage();
    try {
      const res = await read(db);
      expect(res.status).toBe(400);
      expect(await res.text()).not.toContain(SECRET_TEXT);
      expect(await auditRows(db)).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a malformed report id is 400 before any call", async () => {
    const { calls } = supabaseStub();
    const { db, touched } = spyDb();
    const res = await read(db, H, "not-a-uuid");
    expect(res.status).toBe(400);
    expect(calls).toHaveLength(0);
    expect(touched).toEqual([]);
  });
});

describe("no agent-facing or batch read path exists", () => {
  const paths: [string, string][] = [
    ["GET", "/v1/moderation/reports"],
    ["GET", "/v1/moderation/reports/"],
    ["GET", `/v1/moderation/reports/${REPORT}`],
    ["GET", `/v1/moderation/reports/${REPORT}/messages`],
    ["GET", "/v1/moderation/messages"],
    ["GET", `/v1/moderation/reports/${REPORT}/message/extra`],
    ["POST", `/v1/moderation/reports/${REPORT}/message`],
    ["PUT", `/v1/moderation/reports/${REPORT}/message`],
  ];
  for (const [method, path] of paths) {
    it(`${method} ${path.replace(REPORT, "{id}")} is not found, no call, no DB`, async () => {
      const { calls } = supabaseStub();
      const { db, touched } = spyDb();
      const res = await worker.fetch(new Request(`https://worker.local${path}`, { method, headers: H }), env(db));
      expect(res.status).toBe(404);
      expect(calls).toHaveLength(0);
      expect(touched).toEqual([]);
    });
  }

  it("the route table has exactly one moderation route (source scan)", () => {
    const src = readFileSync(fileURLToPath(new URL("../src/index.ts", import.meta.url)), "utf8");
    const code = src.split("\n").filter((l) => !l.trim().startsWith("//")).join("\n");
    expect(code.match(/\/v1\/moderation/g)).toBeNull(); // the path lives in moderation.ts only
    const mod = readFileSync(fileURLToPath(new URL("../src/moderation.ts", import.meta.url)), "utf8");
    expect(mod.match(/MODERATION_PATH\s*=/g)).toHaveLength(1);
  });
});

describe("static guard over src/ for T18", () => {
  const SRC = fileURLToPath(new URL("../src", import.meta.url));
  const files = readdirSync(SRC, { recursive: true })
    .map(String)
    .filter((f) => f.endsWith(".ts"))
    .map((f) => ({ f, text: readFileSync(join(SRC, f), "utf8") }));

  it("no logging statement anywhere in src (message text can never be logged)", () => {
    const hits = files.filter(({ text }) => /\bconsole\s*\./.test(text)).map(({ f }) => f);
    expect(hits).toEqual([]);
  });

  it("no response-time wording anywhere in src or the migration", () => {
    const sql = readFileSync(fileURLToPath(new URL("../migrations/0002_moderator_reads.sql", import.meta.url)), "utf8");
    const all = [...files, { f: "0002_moderator_reads.sql", text: sql }];
    const hits = all.filter(({ text }) => /24[\s-]*(hours?|hrs?|h)\b|within\s+\d+\s*(hours?|days?|minutes?)|\bSLA\b/i.test(text));
    expect(hits.map((h) => h.f)).toEqual([]);
  });

  it("the moderator module has no scheduled or background entry point", () => {
    const mod = files.find(({ f }) => f === "moderation.ts")!.text;
    expect(/\bscheduled\b|\bqueue\b|setInterval|setTimeout|waitUntil/.test(mod)).toBe(false);
  });
});
