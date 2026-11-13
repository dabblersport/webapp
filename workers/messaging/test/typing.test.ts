// KAN-579: ephemeral typing presence. The Worker authorises, then asks Supabase (public.msg_typing) to fan out.
// Local D1 emulator + stubbed fetch; nothing real is called. Typing must never touch D1.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CONV_A, RPC_URL, SUPABASE_URL, authRow, env, localD1, spyDb } from "./helpers";

const TYPING_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_typing`;
const TOKEN = "Bearer typing.test.token";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

function stub(row: Record<string, unknown> = authRow(), typing: Response | Error = new Response(null, { status: 204 })) {
  const typingCalls: { url: string; init: RequestInit }[] = [];
  const unmocked: string[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      if (url === RPC_URL) return new Response(JSON.stringify([row]), { status: 200 });
      if (url === TYPING_URL) {
        typingCalls.push({ url, init });
        if (typing instanceof Error) throw typing;
        return typing.clone();
      }
      unmocked.push(url);
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { typingCalls, unmocked };
}

function context() {
  const scheduled: Promise<unknown>[] = [];
  return { ctx: { waitUntil: vi.fn((p: Promise<unknown>) => void scheduled.push(p)) }, scheduled };
}

const post = (
  db: D1Database,
  body: unknown,
  ctx: { waitUntil(p: Promise<unknown>): void } | undefined,
  { id = CONV_A, token = TOKEN, extra = {} }: { id?: string; token?: string | null; extra?: Record<string, string> } = {},
) =>
  worker.fetch(
    new Request(`https://worker.local/v1/conversations/${id}/typing`, {
      method: "POST",
      headers: { ...(token === null ? {} : { Authorization: token }), "content-type": "application/json" },
      body: typeof body === "string" ? body : JSON.stringify(body),
    }),
    env(db, extra),
    ctx,
  );

describe("typing is forwarded to Supabase for a member who may send", () => {
  it("204, one msg_typing with the caller's token unchanged and only ids and a boolean", async () => {
    const { typingCalls, unmocked } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      const res = await post(db, { typing: true }, ctx);
      expect(res.status).toBe(204);
      await Promise.all(scheduled);
      expect(typingCalls).toHaveLength(1);
      const { init } = typingCalls[0];
      const h = init.headers as Record<string, string>;
      expect(h.Authorization).toBe(TOKEN);
      expect(JSON.parse(init.body as string)).toEqual({ p_conversation_id: CONV_A, p_typing: true, p_access_mode: "allowlist" });
      expect(unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });

  it("a stop is forwarded as typing:false and the env access mode is passed through", async () => {
    const { typingCalls } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      expect((await post(db, { typing: false }, ctx, { extra: { MESSAGING_ACCESS_MODE: "all" } })).status).toBe(204);
      await Promise.all(scheduled);
      expect(JSON.parse(typingCalls[0].init.body as string)).toEqual({ p_conversation_id: CONV_A, p_typing: false, p_access_mode: "all" });
    } finally {
      await mf.dispose();
    }
  });

  it("is scheduled after the response, and a failing fan-out never changes the answer", async () => {
    stub(authRow(), new Error("network down"));
    const { mf, db } = await localD1();
    try {
      const { ctx, scheduled } = context();
      expect((await post(db, { typing: true }, ctx)).status).toBe(204);
      expect(ctx.waitUntil).toHaveBeenCalledTimes(1);
      await expect(Promise.all(scheduled)).resolves.toEqual([null]); // swallowed: the status is null
    } finally {
      await mf.dispose();
    }
  });
});

describe("typing is ephemeral: no durable row, no database touch", () => {
  it("never touches the D1 binding", async () => {
    stub();
    const { mf, db } = await localD1();
    try {
      const spy = spyDb(db);
      const { ctx, scheduled } = context();
      expect((await post(spy.db, { typing: true }, ctx)).status).toBe(204);
      await Promise.all(scheduled);
      expect(spy.touched).toEqual([]);
      const rows = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
      expect(rows?.n).toBe(0);
    } finally {
      await mf.dispose();
    }
  });
});

describe("authorisation: only a current member who may send is heard", () => {
  it("a removed member (TC5) is refused and nothing is sent", async () => {
    const { typingCalls } = stub(authRow({ user_id: null, allowed_action: null, reason: "removed" }));
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      const res = await post(db, { typing: true }, ctx);
      expect(res.status).toBe(403);
      expect(((await res.json()) as { error: { reason: string } }).error.reason).toBe("removed");
      expect(typingCalls).toHaveLength(0);
      expect(ctx.waitUntil).not.toHaveBeenCalled();
    } finally {
      await mf.dispose();
    }
  });

  it("a non-member is refused", async () => {
    const { typingCalls } = stub(authRow({ user_id: null, allowed_action: null, reason: "not_member" }));
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      expect((await post(db, { typing: true }, ctx)).status).toBe(403);
      expect(typingCalls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a member who left, or whose game ended, is refused with its typed reason", async () => {
    const left = stub(authRow({ allowed_action: "read", reason: "left", left_at_seq: 3 }));
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      const res = await post(db, { typing: true }, ctx);
      expect(res.status).toBe(403);
      expect(((await res.json()) as { error: { reason: string } }).error.reason).toBe("left_read_only");
      expect(left.typingCalls).toHaveLength(0);
      const ended = stub(authRow({ allowed_action: "read", reason: "game_ended" }));
      expect((await post(db, { typing: false }, ctx)).status).toBe(409);
      expect(ended.typingCalls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a missing or malformed bearer is 401 and reaches nothing", async () => {
    const { typingCalls, unmocked } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      expect((await post(db, { typing: true }, ctx, { token: null })).status).toBe(401);
      expect((await post(db, { typing: true }, ctx, { token: "Basic abc" })).status).toBe(401);
      expect(typingCalls).toHaveLength(0);
      expect(unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });
});

describe("request validation happens before any outbound call", () => {
  it.each([
    ["not json", "{nope"],
    ["no typing field", {}],
    ["typing is a string", { typing: "true" }],
    ["typing is a number", { typing: 1 }],
  ])("%s -> 400", async (_n, body) => {
    const { typingCalls, unmocked } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      expect((await post(db, body, ctx)).status).toBe(400);
      expect(typingCalls).toHaveLength(0);
      expect(unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });

  it("a conversation id that is not a uuid -> 400", async () => {
    const { unmocked } = stub();
    const { mf, db } = await localD1();
    try {
      const { ctx } = context();
      expect((await post(db, { typing: true }, ctx, { id: "not-a-uuid" })).status).toBe(400);
      expect(unmocked).toEqual([]);
    } finally {
      await mf.dispose();
    }
  });
});
