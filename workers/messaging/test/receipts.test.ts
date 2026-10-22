// KAN-580 (backend half): the receipt acknowledgement route. Local D1 emulator + stubbed fetch; nothing real is called.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { CONV_A, RPC_URL, SUPABASE_URL, authRow, env, localD1 } from "./helpers";

const ACK_URL = `${SUPABASE_URL}/rest/v1/rpc/msg_ack_receipt`;
const TOKEN = "Bearer receipts.test.token";

afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

function stub(row: Record<string, unknown> = authRow(), ack: Response | Error = new Response(JSON.stringify([{ delivered_seq: 3, seen_seq: 2, advanced: true }]), { status: 200 })) {
  const ackCalls: { init: RequestInit }[] = [];
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      if (url === RPC_URL) return new Response(JSON.stringify([row]), { status: 200 });
      if (url === ACK_URL) {
        ackCalls.push({ init });
        if (ack instanceof Error) throw ack;
        return ack.clone();
      }
      throw new Error(`unmocked host hit: ${url}`);
    }),
  );
  return { ackCalls };
}

async function seeded(lastSeq: number) {
  const l = await localD1();
  await l.db.prepare("INSERT INTO conversation_seq (conversation_id, last_seq) VALUES (?1, ?2)").bind(CONV_A, lastSeq).run();
  return l;
}

const post = (db: D1Database, body: unknown, token: string | null = TOKEN) =>
  worker.fetch(
    new Request(`https://worker.local/v1/conversations/${CONV_A}/receipts`, {
      method: "POST",
      headers: { ...(token === null ? {} : { Authorization: token }), "content-type": "application/json" },
      body: typeof body === "string" ? body : JSON.stringify(body),
    }),
    env(db),
    undefined,
  );

describe("receipt acknowledgement", () => {
  it("forwards the caller's own token and returns the watermarks", async () => {
    const { ackCalls } = stub();
    const { mf, db } = await seeded(5);
    try {
      const res = await post(db, { state: "seen", through_seq: 3 });
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ delivered_seq: 3, seen_seq: 2, advanced: true });
      expect(ackCalls).toHaveLength(1);
      expect((ackCalls[0].init.headers as Record<string, string>).Authorization).toBe(TOKEN);
      expect(JSON.parse(ackCalls[0].init.body as string)).toEqual({
        p_conversation_id: CONV_A,
        p_state: "seen",
        p_through_seq: 3,
        p_access_mode: "allowlist",
      });
    } finally {
      await mf.dispose();
    }
  });

  it("a replay reports advanced:false and writes nothing to D1", async () => {
    stub(authRow(), new Response(JSON.stringify([{ delivered_seq: 3, seen_seq: 3, advanced: false }]), { status: 200 }));
    const { mf, db } = await seeded(5);
    try {
      const res = await post(db, { state: "seen", through_seq: 3 });
      expect(((await res.json()) as { advanced: boolean }).advanced).toBe(false);
      const n = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
      expect(n?.n).toBe(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a read-only member (finished game) may still acknowledge", async () => {
    const { ackCalls } = stub(authRow({ allowed_action: "read", reason: "game_ended" }));
    const { mf, db } = await seeded(5);
    try {
      expect((await post(db, { state: "delivered", through_seq: 5 })).status).toBe(200);
      expect(ackCalls).toHaveLength(1);
    } finally {
      await mf.dispose();
    }
  });
});

describe("receipt refusals", () => {
  it.each([
    ["not json", "{"],
    ["no state", { through_seq: 1 }],
    ["unknown state", { state: "read", through_seq: 1 }],
    ["seq zero", { state: "seen", through_seq: 0 }],
    ["seq negative", { state: "seen", through_seq: -1 }],
    ["seq fractional", { state: "seen", through_seq: 1.5 }],
    ["seq a string", { state: "seen", through_seq: "2" }],
  ])("%s -> 400 and nothing is called", async (_n, body) => {
    const { ackCalls } = stub();
    const { mf, db } = await seeded(5);
    try {
      expect((await post(db, body)).status).toBe(400);
      expect(ackCalls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a seq beyond the conversation's highest assigned seq is refused (no pre-acknowledging)", async () => {
    const { ackCalls } = stub();
    const { mf, db } = await seeded(5);
    try {
      expect((await post(db, { state: "seen", through_seq: 6 })).status).toBe(400);
      expect(ackCalls).toHaveLength(0);
    } finally {
      await mf.dispose();
    }
  });

  it("a conversation with no messages yet refuses any seq", async () => {
    stub();
    const { mf, db } = await localD1();
    try {
      expect((await post(db, { state: "seen", through_seq: 1 })).status).toBe(400);
    } finally {
      await mf.dispose();
    }
  });

  it("a removed member and a non-member are refused with their typed reason; nothing is called", async () => {
    for (const reason of ["removed", "not_member"]) {
      const { ackCalls } = stub(authRow({ user_id: null, allowed_action: null, reason }));
      const { mf, db } = await seeded(5);
      try {
        const res = await post(db, { state: "seen", through_seq: 2 });
        expect(res.status).toBe(403);
        expect(ackCalls).toHaveLength(0);
      } finally {
        await mf.dispose();
      }
    }
  });

  it("no token -> 401", async () => {
    stub();
    const { mf, db } = await seeded(5);
    try {
      expect((await post(db, { state: "seen", through_seq: 2 }, null)).status).toBe(401);
    } finally {
      await mf.dispose();
    }
  });

  it("an upstream failure is a 502 with no reason; an empty RPC answer is not_a_member", async () => {
    stub(authRow(), new Error("network down"));
    const a = await seeded(5);
    try {
      expect((await post(a.db, { state: "seen", through_seq: 2 })).status).toBe(502);
    } finally {
      await a.mf.dispose();
    }
    vi.unstubAllGlobals();
    stub(authRow(), new Response("[]", { status: 200 }));
    const b = await seeded(5);
    try {
      const res = await post(b.db, { state: "seen", through_seq: 2 });
      expect(res.status).toBe(403);
      expect(((await res.json()) as { error: { reason: string } }).error.reason).toBe("not_a_member");
    } finally {
      await b.mf.dispose();
    }
  });
});
