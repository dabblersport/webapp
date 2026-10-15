// (f) AC3: gap-free unique seq under concurrent inserts, and client_key idempotency. LOCAL EMULATOR ONLY.
import { describe, expect, it } from "vitest";
import { insertMessage } from "../src/db";
import { CONV_A, CONV_B, localD1 } from "./helpers";

describe("(f) conversation seq on the local D1 emulator", () => {
  it("50 concurrent inserts across two conversations give exactly 1..N per conversation", async () => {
    const { mf, db } = await localD1();
    try {
      const jobs = Array.from({ length: 50 }, (_, i) =>
        insertMessage(db, {
          conversationId: i % 2 === 0 ? CONV_A : CONV_B,
          senderId: `user-${i % 5}`,
          body: `m${i}`,
          clientKey: `ck-${i}`,
        }),
      );
      const out = await Promise.all(jobs);
      expect(out.every((o) => o.created)).toBe(true);
      for (const conv of [CONV_A, CONV_B]) {
        const r = await db
          .prepare("SELECT seq FROM messages WHERE conversation_id = ?1 ORDER BY seq")
          .bind(conv)
          .all<{ seq: number }>();
        expect(r.results.map((x) => x.seq)).toEqual(Array.from({ length: 25 }, (_, i) => i + 1));
        const c = await db.prepare("SELECT last_seq FROM conversation_seq WHERE conversation_id = ?1").bind(conv).first<{ last_seq: number }>();
        expect(c?.last_seq).toBe(25);
      }
    } finally {
      await mf.dispose();
    }
    // KAN-548: headroom only. With more test files running in parallel this one exceeded the 5 s default (it passes
    // alone); the assertions are unchanged.
  }, 60000);

  it("a repeated client_key by the same sender+conversation is idempotent and consumes no seq", async () => {
    const { mf, db } = await localD1();
    try {
      const m = { conversationId: CONV_A, senderId: "real-user", body: "hello", clientKey: "dup" };
      const results = await Promise.all([insertMessage(db, m), insertMessage(db, m), insertMessage(db, m)]);
      expect(results.filter((r) => r.created).length).toBe(1);
      expect(new Set(results.map((r) => r.row.id)).size).toBe(1);
      const next = await insertMessage(db, { ...m, clientKey: "other" });
      expect(next.row.seq).toBe(2); // no gap after the duplicates
      // same client_key from a DIFFERENT sender is a different message
      const other = await insertMessage(db, { ...m, senderId: "someone-else" });
      expect(other.created).toBe(true);
      expect(other.row.seq).toBe(3);
      const n = await db.prepare("SELECT COUNT(*) AS n FROM messages").first<{ n: number }>();
      expect(n?.n).toBe(3);
    } finally {
      await mf.dispose();
    }
  });
});
