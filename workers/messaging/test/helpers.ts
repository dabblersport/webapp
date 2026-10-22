import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { Miniflare } from "miniflare";
import { vi } from "vitest";

export const SUPABASE_URL = "https://example.invalid"; // mock host; nothing real is ever called
export const RPC_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_authorize`;
export const CONV_A = "11111111-1111-4111-8111-111111111111";
export const CONV_B = "22222222-2222-4222-8222-222222222222";

/** Local D1 emulator (Miniflare, in-memory). No Cloudflare account, no network. */
export async function localD1() {
  const mf = new Miniflare({
    modules: true,
    script: "export default { fetch() { return new Response('') } }",
    d1Databases: ["DB"],
    r2Buckets: ["MEDIA"], // KAN-581: an in-memory private bucket; only attachments.test.ts uses it
  });
  const db = (await mf.getD1Database("DB")) as unknown as D1Database;
  // Every local migration in name order (0001, 0002, ...). A statement ends at a line ending in ";" unless that line
  // is inside a trigger body (BEGIN ... END;).
  const dir = fileURLToPath(new URL("../migrations/", import.meta.url));
  const statements: string[] = [];
  for (const f of readdirSync(dir).filter((n) => n.endsWith(".sql")).sort()) {
    let cur: string[] = [];
    let inBody = false;
    for (const line of readFileSync(dir + f, "utf8").split("\n")) {
      const t = line.trim();
      if (t.startsWith("--") || t === "") continue;
      cur.push(line);
      if (t === "BEGIN") inBody = true;
      if (t.endsWith(";") && (!inBody || t === "END;")) {
        statements.push(cur.join("\n").trim().replace(/;$/, ""));
        cur = [];
        inBody = false;
      }
    }
  }
  await db.batch(statements.map((s) => db.prepare(s)));
  return { mf, db, statements };
}

/** Records every property touched on the DB binding; any touch is a DB access. */
export function spyDb(inner?: D1Database) {
  const touched: string[] = [];
  const proxy = new Proxy(inner ?? ({} as D1Database), {
    get(target, prop, recv) {
      touched.push(String(prop));
      return Reflect.get(target, prop, recv);
    },
  });
  return { db: proxy as D1Database, touched };
}

export type RpcReply = Response | (() => Response) | Error;

/**
 * Stub global fetch. ONLY RPC_URL is answered; any other URL is recorded as an unmocked hit and rejected.
 */
export function mockFetch(reply: RpcReply) {
  const calls: { url: string; init: RequestInit }[] = [];
  const unmocked: string[] = [];
  const fn = vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    if (url !== RPC_URL) {
      unmocked.push(url);
      throw new Error(`unmocked host hit: ${url}`);
    }
    calls.push({ url, init });
    if (reply instanceof Error) throw reply;
    return typeof reply === "function" ? reply() : reply.clone();
  });
  vi.stubGlobal("fetch", fn);
  return { calls, unmocked };
}

export function rpcJson(body: unknown, status = 200) {
  return () => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

export function env(db: D1Database, extra: Record<string, string> = {}) {
  return { DB: db, SUPABASE_URL, SUPABASE_ANON_KEY: "test-placeholder-not-a-key", MESSAGING_ACCESS_MODE: "allowlist", ...extra };
}

/** One msg_authorize row in the real function's shape (KAN-505). */
export function authRow(over: Record<string, unknown> = {}) {
  return {
    user_id: "real-user",
    allowed_action: "send",
    reason: null,
    left_at_seq: null,
    member_user_ids: [],
    hidden_sender_ids: [],
    ...over,
  };
}
