// KAN-580 AC4: a reproducible two-client run for a 1:1 chat and a group chat, through the REAL Worker code
// (send, acknowledgement, sender-only summary and recipients) on a local D1 emulator.
//
// What is real: src/index.ts routing, src/auth.ts, src/messages send/idempotency, src/receipts.ts, src/receipt_reads.ts,
// the D1 schema (workers/messaging/migrations). What is simulated: the Supabase side. `SimSupabase` below answers
// msg_authorize / msg_ack_receipt / msg_receipt_summary / msg_receipt_recipients the way
// supabase/migrations/20261020150000_kan580_msg_receipts.sql and 20261020160000_... document (monotonic watermarks,
// distinct current recipients minus the sender, leavers dropped, the caller's identity taken from the bearer only).
// The SQL itself is NOT executed here (no Postgres in this environment): supabase/tests/messaging/receipts_probes.sql
// still has to be run by operations. Each client below is a bearer token; two devices of one user are two tokens.
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";
import { SUPABASE_URL, env, localD1 } from "./helpers";

const CONV_DM = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const CONV_GROUP = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const SERVICE_KEY = "service-key-for-test";
const AUTHZ = `${SUPABASE_URL}/rest/v1/rpc/msg_authorize`;
const ACK = `${SUPABASE_URL}/rest/v1/rpc/msg_ack_receipt`;
const SUMMARY = `${SUPABASE_URL}/rest/v1/rpc/msg_receipt_summary`;
const RECIPIENTS = `${SUPABASE_URL}/rest/v1/rpc/msg_receipt_recipients`;

// Users and their devices (a device is a bearer token).
const TOKENS: Record<string, string> = {
  "Bearer tok-alice": "alice",
  "Bearer tok-bob-phone": "bob",
  "Bearer tok-bob-tablet": "bob",
  "Bearer tok-cara": "cara",
  "Bearer tok-dan": "dan",
  "Bearer tok-eve": "eve", // never a member of anything until she joins
};
const as = (user: string, device = "") =>
  Object.keys(TOKENS).find((t) => TOKENS[t] === user && (device === "" || t.endsWith(device))) as string;

class SimSupabase {
  members = new Map<string, Set<string>>();
  marks = new Map<string, { delivered: number; seen: number }>(); // watermark per (conversation, user)
  ackBodies: Record<string, unknown>[] = [];

  setMembers(conv: string, users: string[]) {
    this.members.set(conv, new Set(users));
  }
  private mark(conv: string, user: string) {
    const k = `${conv}|${user}`;
    if (!this.marks.has(k)) this.marks.set(k, { delivered: 0, seen: 0 });
    return this.marks.get(k)!;
  }
  private recipientsOf(conv: string, sender: string) {
    return [...(this.members.get(conv) ?? [])].filter((u) => u !== sender);
  }

  handle(url: string, init: RequestInit): Response {
    const auth = (init.headers as Record<string, string>).Authorization;
    const body = JSON.parse(init.body as string);
    const caller = TOKENS[auth] ?? null;
    const json = (v: unknown) => new Response(JSON.stringify(v), { status: 200 });
    if (url === AUTHZ) {
      const conv = body.p_conversation_id as string;
      const m = this.members.get(conv);
      if (caller === null) return json([{ user_id: "", allowed_action: null, reason: "not_authenticated", left_at_seq: null, member_user_ids: [], hidden_sender_ids: [] }]);
      const isMember = !!m && m.has(caller);
      return json([
        {
          user_id: caller,
          allowed_action: isMember ? "send" : null,
          reason: isMember ? null : "not_member",
          left_at_seq: null,
          member_user_ids: isMember ? [...m!] : [],
          hidden_sender_ids: [],
        },
      ]);
    }
    if (url === ACK) {
      this.ackBodies.push(body);
      const conv = body.p_conversation_id as string;
      // identity is the verified bearer only; the RPC has no user parameter
      if (caller === null || !this.members.get(conv)?.has(caller)) return json([]);
      const mk = this.mark(conv, caller);
      const before = { ...mk };
      const through = body.p_through_seq as number;
      if (body.p_state === "delivered") mk.delivered = Math.max(mk.delivered, through);
      else {
        mk.seen = Math.max(mk.seen, through);
        mk.delivered = Math.max(mk.delivered, mk.seen); // seen raises delivered with it
      }
      return json([{ delivered_seq: mk.delivered, seen_seq: mk.seen, advanced: mk.delivered !== before.delivered || mk.seen !== before.seen }]);
    }
    if (url === SUMMARY) {
      const conv = body.p_conversation_id as string;
      if (caller === null || !this.members.get(conv)?.has(caller)) return json([]);
      // the Worker only passes seqs the caller sent, so the caller is the sender of every seq asked
      const rec = this.recipientsOf(conv, caller);
      return json(
        (body.p_seqs as number[]).map((seq) => ({
          seq,
          recipients: rec.length,
          delivered_count: rec.filter((u) => this.mark(conv, u).delivered >= seq).length,
          seen_count: rec.filter((u) => this.mark(conv, u).seen >= seq).length,
        })),
      );
    }
    if (url === RECIPIENTS) {
      expect(auth).toBe(`Bearer ${SERVICE_KEY}`);
      const conv = body.p_conversation_id as string;
      const seq = body.p_seq as number;
      return json(
        this.recipientsOf(conv, body.p_caller_id as string)
          .filter((u) => (body.p_member_ids as string[]).includes(u))
          .map((u) => {
            const mk = this.mark(conv, u);
            return { user_id: u, state: mk.seen >= seq ? "seen" : mk.delivered >= seq ? "delivered" : "sent", updated_at: null };
          }),
      );
    }
    throw new Error(`unmocked host hit: ${url}`);
  }
}

let sim: SimSupabase;
function install() {
  sim = new SimSupabase();
  vi.stubGlobal(
    "fetch",
    vi.fn(async (input: RequestInfo | URL, init: RequestInit = {}) => {
      const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
      return sim.handle(url, init);
    }),
  );
}
afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const KEY = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

/** One client: a token talking to the Worker. */
function client(db: D1Database, token: string) {
  const e = { ...env(db), SUPABASE_SERVICE_KEY: SERVICE_KEY };
  const call = (conv: string, path: string, init: RequestInit = {}) =>
    worker.fetch(
      new Request(`https://worker.local/v1/conversations/${conv}${path}`, {
        ...init,
        headers: { Authorization: token, "content-type": "application/json", ...((init.headers as Record<string, string>) ?? {}) },
      }),
      e,
      undefined,
    );
  return {
    send: (conv: string, key: string, body: string) =>
      call(conv, "/messages", { method: "POST", headers: { "Idempotency-Key": key }, body: JSON.stringify({ body }) }),
    ack: (conv: string, state: "delivered" | "seen", through: number, extra: Record<string, unknown> = {}) =>
      call(conv, "/receipts", { method: "POST", body: JSON.stringify({ state, through_seq: through, ...extra }) }),
    summary: (conv: string, seqs: number[]) => call(conv, `/receipts?seqs=${seqs.join(",")}`),
    recipients: (conv: string, seq: number) => call(conv, `/receipts/${seq}`),
  };
}
const body = async (r: Response) => (await r.json()) as any;

describe("KAN-580 two-client run: 1:1 chat (alice and bob)", () => {
  it("TC1-TC3: Sent, then Delivered on bob's acknowledgement, then Seen; the state never goes backwards", async () => {
    install();
    sim.setMembers(CONV_DM, ["alice", "bob"]);
    const { mf, db } = await localD1();
    try {
      const alice = client(db, as("alice"));
      const bob = client(db, as("bob"));

      // TC1: alice sends while bob's app is closed (bob has acknowledged nothing)
      const sent = await alice.send(CONV_DM, KEY(1), "hi");
      expect(sent.status).toBe(201); // Sent = durable acceptance by D1
      expect((await body(sent)).seq).toBe(1);
      expect((await body(await alice.summary(CONV_DM, [1]))).summaries).toEqual([{ seq: 1, recipients: 1, delivered_count: 0, seen_count: 0 }]);

      // TC2: bob opens the app but not the chat: the app acknowledges "delivered"
      expect(await body(await bob.ack(CONV_DM, "delivered", 1))).toEqual({ delivered_seq: 1, seen_seq: 0, advanced: true });
      expect((await body(await alice.summary(CONV_DM, [1]))).summaries).toEqual([{ seq: 1, recipients: 1, delivered_count: 1, seen_count: 0 }]);

      // TC3: bob opens the chat: "seen"
      expect(await body(await bob.ack(CONV_DM, "seen", 1))).toEqual({ delivered_seq: 1, seen_seq: 1, advanced: true });
      expect((await body(await alice.summary(CONV_DM, [1]))).summaries).toEqual([{ seq: 1, recipients: 1, delivered_count: 1, seen_count: 1 }]);

      // never backwards: a late "delivered" for the same seq, and a stale lower ack, change nothing
      expect(await body(await bob.ack(CONV_DM, "delivered", 1))).toEqual({ delivered_seq: 1, seen_seq: 1, advanced: false });
      await alice.send(CONV_DM, KEY(2), "again");
      expect(await body(await bob.ack(CONV_DM, "delivered", 2))).toEqual({ delivered_seq: 2, seen_seq: 1, advanced: true });
      expect(await body(await bob.ack(CONV_DM, "seen", 1))).toEqual({ delivered_seq: 2, seen_seq: 1, advanced: false });
      expect((await body(await alice.summary(CONV_DM, [1, 2]))).summaries).toEqual([
        { seq: 1, recipients: 1, delivered_count: 1, seen_count: 1 },
        { seq: 2, recipients: 1, delivered_count: 1, seen_count: 0 },
      ]);
    } finally {
      await mf.dispose();
    }
  });

  it("TC4: a send retried under the same Idempotency-Key creates exactly one message", async () => {
    install();
    sim.setMembers(CONV_DM, ["alice", "bob"]);
    const { mf, db } = await localD1();
    try {
      const alice = client(db, as("alice"));
      const first = await alice.send(CONV_DM, KEY(7), "offline then retry");
      const retry = await alice.send(CONV_DM, KEY(7), "offline then retry");
      expect([first.status, retry.status]).toEqual([201, 200]); // the retry is answered with the stored message
      expect((await body(first)).id).toBe((await body(retry)).id);
      const n = await db.prepare("SELECT COUNT(*) AS n FROM messages WHERE conversation_id = ?1").bind(CONV_DM).first<{ n: number }>();
      expect(n?.n).toBe(1);
      const bob = client(db, as("bob"));
      expect((await body(await bob.ack(CONV_DM, "seen", 1))).advanced).toBe(true);
      expect((await body(await alice.summary(CONV_DM, [1]))).summaries[0]).toMatchObject({ recipients: 1, seen_count: 1 });
    } finally {
      await mf.dispose();
    }
  });

  it("TC6: bob on two devices: the first to reach a seq advances the state once, the other is a no-op, counted once", async () => {
    install();
    sim.setMembers(CONV_DM, ["alice", "bob"]);
    const { mf, db } = await localD1();
    try {
      const alice = client(db, as("alice"));
      const phone = client(db, as("bob", "phone"));
      const tablet = client(db, as("bob", "tablet"));
      await alice.send(CONV_DM, KEY(1), "hi");
      expect((await body(await phone.ack(CONV_DM, "seen", 1))).advanced).toBe(true);
      expect(await body(await tablet.ack(CONV_DM, "delivered", 1))).toEqual({ delivered_seq: 1, seen_seq: 1, advanced: false });
      expect(await body(await tablet.ack(CONV_DM, "seen", 1))).toEqual({ delivered_seq: 1, seen_seq: 1, advanced: false });
      expect((await body(await alice.summary(CONV_DM, [1]))).summaries).toEqual([{ seq: 1, recipients: 1, delivered_count: 1, seen_count: 1 }]);
    } finally {
      await mf.dispose();
    }
  });

  it("permissions: a stranger cannot acknowledge or read, a recipient cannot read the sender's receipts, no pre-acknowledging, no forged identity", async () => {
    install();
    sim.setMembers(CONV_DM, ["alice", "bob"]);
    const { mf, db } = await localD1();
    try {
      const alice = client(db, as("alice"));
      const bob = client(db, as("bob"));
      const eve = client(db, as("eve"));
      await alice.send(CONV_DM, KEY(1), "hi");

      const forged = await eve.ack(CONV_DM, "seen", 1);
      expect(forged.status).toBe(403);
      expect((await body(forged)).error.reason).toBe("not_a_member");
      expect(sim.ackBodies).toHaveLength(0);
      expect((await eve.summary(CONV_DM, [1])).status).toBe(404);
      expect((await eve.recipients(CONV_DM, 1)).status).toBe(404);
      expect((await bob.summary(CONV_DM, [1])).status).toBe(404); // member, but not the author: 404, never 403
      expect((await bob.recipients(CONV_DM, 1)).status).toBe(404);
      expect((await bob.ack(CONV_DM, "seen", 99)).status).toBe(400); // a seq that does not exist yet
      expect(sim.ackBodies).toHaveLength(0);
      // identity is the bearer: a user id smuggled into the body never reaches the RPC
      await bob.ack(CONV_DM, "delivered", 1, { user_id: "alice", p_user_id: "alice" });
      expect(Object.keys(sim.ackBodies[0]).sort()).toEqual(["p_access_mode", "p_conversation_id", "p_state", "p_through_seq"]);
      expect(sim.marks.get(`${CONV_DM}|alice`)).toBeUndefined();
      const anon = await worker.fetch(
        new Request(`https://worker.local/v1/conversations/${CONV_DM}/receipts`, { method: "POST", body: JSON.stringify({ state: "seen", through_seq: 1 }) }),
        env(db),
        undefined,
      );
      expect(anon.status).toBe(401);
    } finally {
      await mf.dispose();
    }
  });
});

describe("KAN-580 two-client run: group chat (alice sends; bob, cara, dan receive)", () => {
  it("TC5: counts show delivered/seen; the recipient list names who is in which state", async () => {
    install();
    sim.setMembers(CONV_GROUP, ["alice", "bob", "cara", "dan"]);
    const { mf, db } = await localD1();
    try {
      const alice = client(db, as("alice"));
      const bob = client(db, as("bob", "phone"));
      const bobTablet = client(db, as("bob", "tablet"));
      const cara = client(db, as("cara"));
      await alice.send(CONV_GROUP, KEY(1), "who is in for friday?");
      const count = async () => (await body(await alice.summary(CONV_GROUP, [1]))).summaries[0];
      expect(await count()).toEqual({ seq: 1, recipients: 3, delivered_count: 0, seen_count: 0 });

      await bob.ack(CONV_GROUP, "seen", 1);
      await cara.ack(CONV_GROUP, "delivered", 1);
      await bobTablet.ack(CONV_GROUP, "seen", 1); // second device of bob: counted once
      expect(await count()).toEqual({ seq: 1, recipients: 3, delivered_count: 2, seen_count: 1 });

      const list = (await body(await alice.recipients(CONV_GROUP, 1))).recipients; // tap the count: the drawer's list
      expect(Object.fromEntries(list.map((r: any) => [r.user_id, r.state]))).toEqual({ bob: "seen", cara: "delivered", dan: "sent" });

      await cara.ack(CONV_GROUP, "seen", 1); // two of three have now read it
      expect(await count()).toEqual({ seq: 1, recipients: 3, delivered_count: 2, seen_count: 2 });
      expect((await bob.recipients(CONV_GROUP, 1)).status).toBe(404); // a recipient cannot open the sender's drawer
    } finally {
      await mf.dispose();
    }
  });

  it("membership changes: a leaver drops out of the denominator and the numerators, a joiner counts for readable history", async () => {
    install();
    sim.setMembers(CONV_GROUP, ["alice", "bob", "cara", "dan"]);
    const { mf, db } = await localD1();
    try {
      const alice = client(db, as("alice"));
      const bob = client(db, as("bob"));
      const dan = client(db, as("dan"));
      await alice.send(CONV_GROUP, KEY(1), "hello all");
      await bob.ack(CONV_GROUP, "seen", 1);
      await dan.ack(CONV_GROUP, "seen", 1);
      const count = async () => (await body(await alice.summary(CONV_GROUP, [1]))).summaries[0];
      expect(await count()).toEqual({ seq: 1, recipients: 3, delivered_count: 2, seen_count: 2 });

      sim.setMembers(CONV_GROUP, ["alice", "bob", "cara"]); // dan leaves
      expect(await count()).toEqual({ seq: 1, recipients: 2, delivered_count: 1, seen_count: 1 });
      expect((await dan.ack(CONV_GROUP, "seen", 1)).status).toBe(403);

      sim.setMembers(CONV_GROUP, ["alice", "bob", "cara", "eve"]); // eve joins
      expect(await count()).toEqual({ seq: 1, recipients: 3, delivered_count: 1, seen_count: 1 });
      const eve = client(db, as("eve"));
      expect((await body(await eve.ack(CONV_GROUP, "seen", 1))).advanced).toBe(true);
      expect(await count()).toEqual({ seq: 1, recipients: 3, delivered_count: 2, seen_count: 2 });
    } finally {
      await mf.dispose();
    }
  });
});
